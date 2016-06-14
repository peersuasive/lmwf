describe("HTTPd server unit tests", function()
    local hostname, port = 'localhost', 1444
    local host = 'http://' .. hostname .. ':' .. port
    local httpd = require'spec.loader_ctl_tests'
    local server, pid = nil, nil
    local dbg
    local px = require'posix'
    local ppid = px.getpid('pid')
    local is_child = false
    local pr, pw = px.pipe()

    local config = {
        port = port,
        views = 'spec/views',
        loaders = 'spec/loaders'
    }

    local function start_server(app, path, post)
        local r, httpd
        r, res, httpd = pcall(server.start_server, server, app)
        assert.are_not_same(0, res)
        local cpid = px.getpid('pid')
        if cpid~=ppid then
            pid = cpid
            is_child = true
        else
            pid = res
        end

        if not r and cpid==ppid then
            error(pid, 2)
        end
        if not r and cpid~=ppid then
            px.close(pr)
            local s = 1
            --if not should_fail then
                px.write(pw, res and res.message or res or 'NO MESSAGE')
            --end
            px.close(pw)
            px._exit(s)
        elseif cpid~=ppid then
            print"OUT"
            px._exit(0)
        end
        --if not r and should_fail and cpid~=ppid then -- error from child
        --    return function() return nil, 'closed' end
        --end
        local http_f
        if path then
            local http = require'socket.http'
            local path = path:match('^/') and path or '/'..path
            http_f = function(path,...) return http.request(host .. path,...) end
        end
        return http_f, httpd
    end
    local function check_status(should_not_fail)
        local r,err,status = px.wait(pid)
        if status == 0 then
            return true end
        px.close(pw)
        local b, msg = px.read(pr,1), ''
        while b and #b==1 do
            msg = msg..b
            b = px.read(pr,1)
        end
        px.close(pr)
        error(msg, should_not_fail and 2 or 3)
    end

    setup(function()
        _G.__TEST = true
        --_G.__DEBUG=true
        dbg = require'core.debug_utils'
        dbg.reset()
    end)
    teardown(function()
        _G.__TEST = nil
        __UNDEBUG()
    end)

    before_each(function()
        server = assert(httpd:new(config))
        pr, pw = px.pipe()
    end)

    after_each(function()
        if server then server:stop_server(pid) end
        server = nil
        pid = nil
        px.close(pw) px.close(pr)
    end)

    it("should respond to a GET set with a ROUTE", function()
        local path = '/testget'
        local cb = function(env, req)
            return path
        end
        local app = require'core.Application'("http test GET")
        app:GET( path , cb )

        local http = start_server( app, path )
        local r, status = http( path )
        assert(r, "No content returned at all")
        assert.same(200, status)
    end)


    it("should provides env and req to route controllers", function()
        local path = '/testenv'
        local cb = function(env, req)
            assert.is_table(env)
            assert.is_table(req)
            --assert(false)
            return path
        end
        local app = require'core.Application'("http test GET")
        app:GET( path , cb )

        local http = start_server( app, path )

        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
    end)

    it("should provides url_for in req object", function()
        local path, second_name, second_path = '/request', 'urlfor', '/urlfor'
        local cb = function(env, req)
            assert.is_table(env)
            assert.is_table(req)
            assert.same('function', type(req.url_for))

            local o = assert(req:url_for(second_name))
            return o
        end
        local app = require'core.Application'("http test GET")
        app:GET( path , cb )
        app:GET( {[second_name] = second_path} , "SECONDPATH")

        local http = start_server( app, path )

        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( second_path, r)
    end)

    it("should render an inline view", function()
        local path, content = '/inline', 'INLINE'
        local app = require'core.Application'("inline view")
        app:GET( path , content )

        local http = start_server(app, path)
        local r, status = http( path )
        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should render an inline view from a callback", function()
        local path, content = '/inlinef', 'INLINEF'
        local app = require'core.Application'("inline view")
        app:GET( path , function() return content end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should render an inline view returned from a callback with options", function()
        local path, content = '/inlinea', 'INLINEA'
        local app = require'core.Application'("inline view")
        app:GET( path , function() return {content} end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should render an inline view returned from a callback with options even if render is provided", function()
        local path, content = '/inlinea', 'INLINEA'
        local app = require'core.Application'("inline view")
        app:GET( path , function() return {render=true, content} end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)
    it("should render an inline view returned from a callback with options even if render is false", function()
        local path, content = '/inlinea', 'INLINEA'
        local app = require'core.Application'("inline view")
        app:GET( path , function() return {render=false, content} end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should render a specified view", function()
        local path, content = '/specifiedview', 'SPECIFIED VIEW'
        local app = require'core.Application'("inline view")
        app:GET( path , function()
            return {render='specified'}
        end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should fail to render an unavailable specified view", function()
        local path, content = '/specifiedview', 'SPECIFIED VIEW'
        local app = require'core.Application'("inline view")
        app:GET( path , function()
            return {render='unavailable'}
        end )

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has_error( check_status, "No loader found or no file found for view: unavailable" )

        assert(r==nil)
        assert.same('closed', status)
    end)


    it("should find and render a default html view by name", function()
        -- TODO: provide config with views path set to specs/views
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )

    end)

    it("should find and render a default html view by name when callbacks returned with options", function()
        -- TODO: provide config with views path set to specs/views
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
            return {}
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should find and render a default html view by name when callbacks returns true", function()
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
            return true
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should try to guess view name from path", function()
        local path, content = '/unnamedview', 'UNNAMED VIEW'
        local app = require'core.Application'("unnamed view")
        app:GET(path, function()
            return true
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should fail rendering unavailable view", function()
        local name, path = 'fakenamedview', '/getfakenamedview'
        local app = require'core.Application'("fake named view")
        app:GET({[name]=path}, function()
            return true
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has_error( check_status, "No loader found or no file found for view: fakenamedview" )

        assert(r==nil)
        assert.same('closed', status)
    end)

    it("should fail guessing view name from path from unavailable view", function()
        local path = '/unavailableview'
        local app = require'core.Application'("unavailable unnamed view")
        app:GET(path, function()
            return true
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has_error( check_status, "No loader found or no file found for view: unavailableview" )

        assert(r==nil)
        assert.same('closed', status)
    end)

    it("should fail rendering view if callback returns false", function()
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
            return false
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has.errors( check_status )
        
        assert(r==nil)
        assert.same('closed', status)
    end)

    it("should fail rendering view when returning render=false", function()
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
            return {render=false}
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has.errors( check_status )

        assert(r==nil)
        assert.same('closed', status)
    end)

    it("should fail rendering view when returning an unsupported value type", function()
        local name, path, content = 'namedview', '/getnamedview', 'NAMEDVIEW'
        local app = require'core.Application'("named view")
        app:GET({[name]=path}, function()
            return function()end
        end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert.has_error( check_status, "Unsupported returned type: function" )

        assert(r==nil)
        assert.same('closed', status)
    end)

    it("should accept view loaders at runtime", function()
        local path = '/loader'
        local app = require'core.Application'("view with loader")
        app:GET( path , "LOADER")
 
        local _, httpd = start_server(app, path)
 
        local loader = {
            exts = {'raw'},
            handle = function(content)return content end
        }
        assert( httpd:add_loader(loader) )
        assert.same('function', type(httpd.page_loaders[loader.exts[1]]))
    end)

    it("should load static view loaders", function()
        local path = '/plaitext'
        local app = require'core.Application'("view with loader")
        app:GET( path , "PLAINTEXTLOADER")
 
        local _, httpd = start_server(app, path)
 
        assert.same('function', type(httpd.page_loaders['txt']))
    end)

    it("should find and render a view with a loader", function()
        local name, path = 'plainloader', '/plainloader'
        local app = require'core.Application'("view with loader")
        app:GET({[name]=path}, function()end)

        local http = start_server(app, path)
        local r, status = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( "PLAIN TEXT LOADER", r )
    end)

    it("should set content-type", function()
        local path, content = '/json', [==[{"some":"data","total":1}]]==]
        local app = require'core.Application'("json")
        app:GET(path, function()
            return {content_type='application/json', content}
        end)

        local http = start_server(app, path)
        local r, status, headers = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content , r )

        assert.same( 'application/json', headers['content-type'] )
    end)

    it("should set headers", function()
        local path, content = '/headers', [==[{"some":"data","total":1}]]==]
        local app = require'core.Application'("json")
        app:GET(path, function()
            return {headers={['Content-type']='application/json',['extra-field']='SOME EXTRA VALUES'}, content}
        end)

        local http = start_server(app, path)
        local r, status, headers = http( path )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content , r )

        assert.same( 'application/json', headers['content-type'] )
        assert.same( 'SOME EXTRA VALUES', headers['extra-field'] )
    end)

    it("should respond to pathes from another application", function()
        local app = require'core.Application'("first")
        local second = app:include('spec.apps.second')
    end)

    it("should respond to POST data", function()
        local path, content, post_content = '/postdata', 'POST DATA', "SOME DATA"
        local app = require'core.Application'("post data")
        app:POST(path, function(env, req)
            assert.same( post_content, req.data )
            return content
        end)

        local http = start_server(app, path)
        local r, status = http( path, post_content )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( content, r )
    end)

    it("should parse POST data", function()
        local path, content, post_content, post_data = '/postdata', 'POST DATA', "param1=one&param2=two", {
            param1 = "one",
            param2 = "two"
        }
        local app = require'core.Application'("post data")
        app:POST(path, function(env, req)
            assert.is_table(req.data)
            assert.same( post_data, req.data )
            return "OK"
        end)

        local http = start_server(app, path)
        local r, status = http( path, post_content )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( "OK", r )
    end)

    -- http://hg.prosody.im/trunk/file/0ed617f58404/net/http.lua#l31
    local function _formencodepart(s)
        return s and (s:gsub("%W", function (c)
            if c ~= " " then
                return string.format("%%%02x", c:byte());
            else
                return "+";
            end
        end));
    end
    local function formencode(form)
        local result = {};
        if form[1] then -- Array of ordered { name, value }
            for _, field in ipairs(form) do
                table.insert(result, _formencodepart(field.name).."=".._formencodepart(field.value));
            end
        else -- Unordered map of name -> value
            for name, value in pairs(form) do
                table.insert(result, _formencodepart(name).."=".._formencodepart(value));
            end
        end
        return table.concat(result, "&");
    end

    it("should handle POST forms", function()
        local path, content, post_content, post_data = '/postform', 'POST DATA', {
            {"param1", "one"}, {"param2", "two"}
        }, {
            param1 = "one",
            param2 = "two"
        }
        local app = require'core.Application'("post data")
        app:POST(path, function(env, req)
            assert.is_table(req.data)
            assert.same( post_data, req.data )
            return "OK"
        end)

        local http = start_server(app, path)
        local r, status = http( path, formencode(post_data) )
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( "OK", r )
    end)

    it("should handle POST multipart", function()
        local path, content, post_data = '/postmulti', 'POST DATA', {
            myfile = {
                content = 'SOME SAMPLE TEXT',
                ['content-type'] = 'application/octet-stream',
                filename = 'sample.txt',
                name = 'myfile' 
            }
        }
        local app = require'core.Application'("post data")
        app:POST(path, function(env, req)
            assert.is_table(req.data)
            assert.same( post_data, req.data )
            return 1
        end)

        local http = start_server(app, path)

        local mp = require'multipart-post'.gen_request
        local http = require'socket.http'.request
        local rq = mp({ myfile = {name='sample.txt', data = 'SOME SAMPLE TEXT'}}, resp)
        rq.url = host .. path
        local r, status = http(rq)
        assert( check_status("should not fail") )

        assert(r, "No content returned at all")
        assert.same(200, status)
        assert.same( 1, r )
    end)

end)
