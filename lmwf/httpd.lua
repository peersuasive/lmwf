--[==[
HTTP generic socket wrapper
--]==]


local dbg = dbg
local sfind = string.find
local gsub = string.gsub
local format = string.format
local split = require'lmwf.helpers.split'
local concat = table.concat

local app_utils = require'lmwf.Application'
local url_for = app_utils.url_for

if pcall(require, 'moonscript') then require'moonscript' end

local HTTP_STATUS = {
    HTTP_OK = 200,
    HTTP_PARTIAL_CONTENT = 206,
    HTTP_MOVED_PERMANENTLY = 301,
    HTTP_NOT_MODIFIED = 304,
    HTTP_BAD_REQUEST = 400,
    HTTP_NOT_AUTHORIZED = 401,
    HTTP_FORBIDDEN = 403,
    HTTP_NOT_FOUND = 404,
    HTTP_NOT_ALLOWED = 405,
    HTTP_TIMEOUT = 408,
    HTTP_TOO_LARGE = 413,
    HTTP_RANGE_UNSATISFIABLE = 416,
    HTTP_I_AM_A_TEAPOT = 418,
    HTTP_INTERNAL_ERROR = 500,
    HTTP_NOT_IMPLEMENTED = 501,
    HTTP_UNAVAILABLE = 503,
}

local function return_error(socket, client, err, cb, code)
    if socket and socket.close then
        if socket.send_error then
            socket.send_error(client, code or 500) end
        socket.close(client)
    end
    if __TEST then
        error(err, 3)
    end
    local info = 'function'==type(cb) and debug.getinfo(cb) or {}
    error(format("[%s:%s]: %s", 
            info.short_src, info.linedefined,
            err or "UNKNOWN ERROR"), 3)
end

-- URL utils
local function url_decode(str)
    str = gsub (str, "+", " ") 
    str = gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end) 
    str = gsub (str, "\r\n", "\n") 
    return str 
end

-- provided template loaders
local function load_page(content)
    return content
end
local function load_etlua(content, env)
    local etlua = require'etlua'.compile
    local c, err = etlua(content)
    if not c then return v, err
    else return c(env) end
end
local function load_mustache(content, env)
    local lustache = require'lustache'
    return lustache:render( content, env )
end

local function load_lua(self, name, env)
    local name = self.config.views..'.'..name
    local cb = require(name)
    return cb(self, env)
end

-- 
local render
render = function(self, env, name, this, no_error)
    local vp = self.config.views
    --local vp = no_error and '.' or self.config.views
    local pname = vp..'/'..( name:gsub('%.','/') )

    dbg( self.page_loaders )
    for ext, cb in pairs(self.page_loaders) do
        dbg("current loader: %s", ext)
        local fname = pname..'.'..ext
        local f = io.open(fname, 'r')
        if f then
            f:close()

            env.url_for = function(...) return url_for(self.app, ...) end

            if 'table'==type(cb)then -- code: lua or moonscript
                local cb = cb[1]
                local r, res, err = pcall(cb, self, name, env)

                if not r then
                    local err = format("Error while loading handler for '%s' format:\n  %s", ext, res or "UNKNOWN ERROR")
                    return_error(self.socket, env.client, err, cb) end

                return res, err
            else
                local name = name:gsub('%.','/')
                local f = io.open(fname, 'r')
                local data = f:read('*a'):gsub('\r?\n$','')
                f:close()
                env.render = function(view) return render(self, env, view, this, 'no_error') end
                --env.url_for = function(...) return url_for(self.app, ...) end
                env.this = this

                local r, v, err = pcall(cb, data, env)
                if not(no_error) and not(r) then
                    local err = format("Error while loading handler for '%s' format:\n  %s", ext, v or "UNKNOWN ERROR")
                    return_error(self.socket, env.client, err, cb) end

                if not(no_error) and not(v) then
                    local err = err or format("Handler for type '%s' returned no data and no error message", ext)
                    return nil, format("Couldn't load view %s: %s", name, err) end
                return v
            end
        end
    end
    if no_error then return ''
    else return nil, format("No loader found or no file found for view: %s", name) end
    --error(format("No loader found or no file found for view: %s", name), 2)
end

local mt = {}
function mt:serve()
    local socket = self.socket
    local client, ip = socket.accept( self.listener )
    assert(client, format("Can't create connection client: %s", ip))
    local found, chunk, size, code, request = 0, 0, 0, 0, ""

    while ( ( found == 0 ) and ( chunk < 10 ) ) do
    	local length, data = socket.read(client)
        if ( length < 1 ) then found = 1 end

	    size = size + length
    	request = request .. data

    	local position, len = sfind( request, '\r\n\r\n' )
	    if position then found = 1 break end
        chunk = chunk + 1
    end

    -- Find the requested path.
    local _, _, method, path, major, minor = sfind(request, "([A-Z]+) (.+) HTTP/(%d).(%d)")

    --[==[
    -- We only handle GET requests.
    if ( method ~= "GET" ) then
        local err = "Method not implemented";
        if not method then err = err .. "."
        else err = err .. ": " .. method end

        socket.send_error( client, 501, err );
        socket.close( client );
        return
    end
    --]==]

    -- parse headers
    local split = require'lmwf.helpers.split'
    local prepared = split(request, '\r\n\r\n')
    local pre_headers = prepared[1]
    local bdata = {}
    for i=2,#prepared do
        bdata[#bdata+1] = prepared[i]
    end
    bdata = concat(bdata, '\r\n\r\n')
    pre_headers = split(pre_headers, '\r\n')

    local headers = { pre_headers[1] }
    for i=2, #pre_headers do
        local k, v = unpack(split(pre_headers[i], ': '))
        headers[k:lower()] = v:match('^[0-9]+$') and tonumber(v) or v
    end
    
    -- *naive* POST request implementation
    if ( method == "POST" ) then
        local ctype = headers['content-type']:gsub(';.*$','')
        local remaining = headers['content-length'] - (bdata and #bdata or 0)
        local data = {}
        -- really naive...
        if headers['expect'] == '100-continue' or ctype=='multipart/form-data' then
            data = {bdata}
            local split = split
            if headers['expect'] == '100-continue' then
                socket.write(client, 'HTTP/1.1 100 Continue\r\n\r\n') end
            while remaining>0 do
                local length, d = socket.read(client)
                if length <= 0 or not(d) then break end
                data[#data+1] = d
                remaining = remaining - length
            end
            data = concat(data)
            local boundary = headers['content-type']:match('boundary=(.+)$')
            if boundary then
                local sboundary = '%-%-'..boundary:gsub('%-','%%%-')
                local form = data:match(sboundary..'\r\n(.+)'..sboundary..'%-%-'):gsub('\r?\n$','')
                local fields = split( form, '\r\n--'..boundary..'\r\n' )
                data = {}
                for _,field in next,fields do
                    local fpre_headers, fdata = unpack(split(field,"\r\n\r\n"))
                    fpre_headers = split(fpre_headers, '\r\n')
                    local fheaders = {}
                    for _,v in next, fpre_headers do
                        local k, v = unpack(split(v,': '))
                        fheaders[k:lower()] = v
                    end
                    local ftype = fheaders['content-type']
                    ftype = ftype and ftype:gsub(';.*$','')
                    local fname, filename = fheaders['content-disposition']
                        :match([=[name="([^"]+)";?[^=]*=?"?([^"]*)"?$]=])
                    if not ftype then
                        data[fname] = fdata
                    else
                        data[fname] = {
                            name=fname,
                            filename = filename~='' and filename or nil,
                            content = fdata,
                            ['content-type'] = ftype
                        }
                    end
                end
            end
        elseif ctype=='application/x-www-form-urlencoded' then
            data = {}
            local has_fields = false
            local fdata = split( bdata, '&' )
            for _,d in next,fdata do
                local k, v = unpack(split(d, '='))
                if v then
                    has_fields = has_fields or true
                    data[k] = url_decode(v)
                else
                    data[#data+1] = k
                end
            end
            if #data==1 and not(has_fields) then data = data[1] end
        else
            data = bdata
        end
        rawset( self, 'data', data )
    end
    rawset( self, 'headers', headers )

    -- Decode the requested path.
    path = url_decode( path )

    if __DEBUG then
        local r, res, err = pcall( self.dispatch, self, client, method, path )
        if not r then return_error( socket, client, res, self.dispatch, 500 )
        else return res, err end
    else
        return self:dispatch(client, method, path) end
end

local req_ = {
    STATUS = HTTP_STATUS,
    send_response = function(self, ...)
        send_response(self.client, ...)
    end,
    set_headers = function(self, ...)
        set_headers(self.client, ...)
    end,
    --url_for = url_for,

    -- expose socket low level methods, for advanced users
    write = function(self, ...)
        return self.socket.write(self.client, ...)
    end,
    close = function(self, ...)
        return self.socket.close(self.client)
    end
}

local function set_params(t)
    local nt = {} -- copy params table
    for k,v in next,t do
        nt[k] = v
    end
    local t = nt
    if not 'table'==type(t) then return t end
    for i=#t,1,-1 do -- flags (for splat)
        local v = t[i]
        t[v] = true
    end
    for k,v in pairs(t) do
        if 'string'==type(v) then
            if v:match('^%s*$')then t[k]=true
            elseif v:match('^[0-9]+$') then t[k] = tonumber(v)
            elseif v:match('^true') then t[k] = true
            elseif v:match('^false') then t[k] = false
            end
        end
    end
    return t
end
function mt:dispatch(client, method, path)
    dbg("original path: %s", path)
    local params = {}
    for a in path:gsub('^[^?]+%??',''):gmatch('[^&]+') do
        local k,v = a:match('^([^=]+)=?(.*)$')
        params[k] = not(v=='') and v or true
    end
    path = path:gsub('%?.*$',''):gsub('(.)/$','%1')

    local method = method:lower()
    local socket = self.socket
    --dbg("Looking for a (%s) matcher for %s", method, path)

    local app = self.app

    local pathes = app.pathes[method]
    local m, view_name = unpack(pathes.pathes[path]or{})

    if not m then
        local rx = pathes.rx
        for k,v in pairs(rx) do
            local r = { path:match(k) }
            if #r>0 then
                local fn, matches, vn = unpack(v)
                view_name = vn
                for i=1,#r do
                    local match = matches[i]
                    if match then
                        params[match] = r[i]
                    end
                end
                if matches.splat then
                    params.splat = set_params( split(r[#r], '/') )
                end
                m = fn
                break
            end
        end
    end
    if not m then -- return 404
        dbg("WARNING: no matcher found for (%s) %s", method, path)
        if self.custom_error then
            -- TODO: render view then throw error
            return socket.send_error(client, 404)
        else
            return socket.send_error(client, 404)
        end
    end

    local this = view_name

    --dbg("Found matcher (%s)", m)

    set_params(params)

    local view, err, headers, status, send_file
    if 'string'==type(m)then
        view = m
    else
        local _self = {client=client}
        local env = setmetatable({},{__index=_self})
        --local priv = setmetatable({
        --    url = path,
        --    client = client,
        --},{__index = app, __newindex=function()end})
        --local req = setmetatable( req_, {__index = priv,__newindex=function()end} )

        local priv = {
            client = client,
            headers = self.headers,
            data = self.data,
            this = this,
        }
        local req = setmetatable({
            url = path,
            params = params,
        }, {__index = function(s,k)
            local v = req_[k]
            if v~=nil then return v
            else v = priv[k] end
            if v~=nil then return v
            else return app[k] end
        end})

        local r, res = pcall(m, env, req)
        if not r then
            return_error(self, client, res) end

        if 'boolean'==type(res) then
            res = { render = res }
        end
        if 'string'==type(res) or 'number'==type(res)then
            view = tostring(res)
        elseif res==nil or 'table'==type(res) then
            res = res or { render = res }
        --if 'table'==type(res) then
            status = res.status
            if res.headers or res.content_type then
                headers = res.headers or {}
                if res.content_type then headers['Content-type'] = res.content_type end
            end
            if res.send_file then -- file to send
                send_file = res.send_file
            elseif res[1] then -- data to send provided
                view = res[1]
            else
                if res.render==true or res.render==nil then -- select default view
                    -- WARNING: trying to guess view from path is most certainly error-prone
                    --view_name = view_name or app.pathes.get.names[path] or path:gsub('^/',''):gsub('/','_')
                    view_name = view_name 
                        --or app.pathes[method].names[path] -- shouldn't be necessary anymore as name now goes in path's table
                        or path:gsub('^/',''):gsub('/','_')

                    if not view_name then
                        dbg("WARNING: controller hasn't declared a view name for %s", path)
                        err = format("No named view found for path: %s", path)
                    end
                else -- view name provided
                    view_name = res.render
                end
                if view_name then
                    view, err = render(self, env, view_name, this) end
            end
        else
            err = format("Unsupported returned type: %s", type(res))
        end
    end
    if send_file then
        return socket.send_file(client, send_file, headers, status)
    elseif not view then
        local err = err or format("Couldn't load or render view for path: %s", path)
        return_error(self, client, err, m, HTTP_STATUS.HTTP_INTERNAL_ERROR)
    else
        dbg("STATUS: %s", status or 200)
        return socket.send_response(client, view, headers, status)
    end
end

local function add_loader(t, handler)
    assert('table'==type(handler) 
        and 'function'==type(handler.handle) 
        and 'table'==type(handler.exts))
    local exts, handle, code = handler.exts, handler.handle, handler.code
    for _,ext in next,exts do
        assert('string'==type(ext))
    end
    for _,ext in next,exts do
        t[ext] = code and {handle} or handle
    end
    return true
end

function mt:add_loader(handler)
    return add_loader(self.page_loaders, handler)
end

local default_config = {
    views = 'views',
    static = 'static',
    loaders = 'loaders'
}

local function new(config_, socket, listener, app)
    local config_ = config_ or {}
    assert('table'==type(config_), format("Wrong config format: expected 'table', got '%s' (%s)", type(config_), config_))
    local app = app or 'app'
    local loaded_app
    if 'table'==type(app) then loaded_app = app
    else
        local r, a = pcall(require, app or 'app')
        if not r then
            error(string.format("Can't load app '%s': %s", app, a)) end
        loaded_app = a
    end

    local config = {}
    for k,v in pairs(default_config) do
        if not config_[k] then config[k] = v
        else config[k] = config_[k] end
    end
    local has_etlua = pcall(require, 'etlua')
    local has_lustache = pcall(require,'lustache')
    local has_moonscript = pcall(require, 'moonscript')
    local page_loaders = {
        html = load_page,
        etlua = has_etlua and load_etlua or nil,
        mustache = has_lustache and load_mustache or nil,
        lua = {load_lua},
        moon = has_moonscript and {load_lua} or nil,
    }
    loaders = config.loaders and io.open(config.loaders,'r')
    if loaders then
        local lfs = require'lfs'
        loaders:close()
        loaders = config.loaders
        for loader in lfs.dir(config.loaders) do
            if loader:match('%.lua$') then
                local handler = require(loaders..'.'..loader:gsub('%.lua$',''))
                add_loader( page_loaders, handler )
            end
        end
    end
    
    local priv = {
        config = config,
        page_loaders = page_loaders,
        socket = socket,
        listener = listener,
        app = loaded_app,

        url_for = function(_,...) return url_for(loaded_app, ...) end,

        req_ = req_
    }

    return setmetatable(mt,{
        __index = priv,
        __newindex = function()end
    })
end

return setmetatable({new=new},{
    __call = function(_,...) return new(...) end,
    __newindex = function()end
})
