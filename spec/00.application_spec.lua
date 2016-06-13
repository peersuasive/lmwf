describe("HTMLd unit tests", function()
    local dbg
    setup(function()
        --_G.__DEBUG=true
        dbg = require'core.debug_utils'
        dbg.reset()
    end)
    teardown(function()
        __UNDEBUG()
    end)

    before_each(function()
    end)

    after_each(function()
    end)

    it("should extend Application class", function()
        local app = require'core.Application'
        assert.is_table(app)
        assert.is_table(app())
    end)

    it("should set an application name", function()
        local app = require'core.Application'("test_name")
        assert.is_table(app)
        assert.same("test_name", app.name)
    end)

    it("should export GET, POST, ROUTE, and url_for", function()
        local app = require'core.Application'("methods")
        local GET, POST, ROUTE, url_for = app:export()
        assert.is_function(GET)
        assert.is_function(POST)
        assert.is_function(ROUTE)
        assert.is_function(url_for)
    end)

    it("should export GET, POST, ROUTE and url_for at init", function()
        local app,
              GET,
              POST,
              ROUTE,
              url_for = require'core.Application'("methods_init", 'export')
        assert.is_function(GET)
        assert.is_function(POST)
        assert.is_function(ROUTE)
        assert.is_function(url_for)
    end)

    it("should export wanted methods", function()
        local app,
              GET,
              POST,
              ROUTE,
              url_for = require'core.Application'("methods_init", {'GET'})
        assert.is_function(GET)
        assert.is_nil(POST)
        assert.is_nil(ROUTE)
        assert.is_nil(url_for)
    end)

    it("should define a GET path", function()
        local app = require'core.Application'("get_path")
        app:GET('/get',"GET")
        assert.truthy(app.pathes.get.pathes['/get'])
    end)

    it("should define a POST path", function()
        local app = require'core.Application'("post_path")
        app:POST('/post',"POST")
        assert.truthy(app.pathes.post.pathes['/post'])
    end)

    it("should define a path with ROUTE for GET", function()
        local app = require'core.Application'("route_get")
        app:ROUTE('/routeget',{
            GET = "ROUTEGET"
        })
        assert.truthy(app.pathes.get.pathes['/routeget'])
    end)

    it("should define a path with ROUTE for POST", function()
        local app = require'core.Application'("route_post")
        app:ROUTE('/routepost',{
            POST = "ROUTEPOST"
        })
        assert.truthy(app.pathes.post.pathes['/routepost'])
    end)

    it("should define both the same path for GET and POST without complaining", function()
        local app = require'core.Application'("get_post_path")
        local path = '/getpost'
        app:GET( path ,"GET")
        app:POST( path ,"POST")
        assert.truthy(app.pathes.get.pathes[ path ])
        assert.truthy(app.pathes.post.pathes[ path ])
    end)

    it("should define a path with ROUTE for both POST and GET", function()
        local app = require'core.Application'("route_get_post")
        app:ROUTE('/routegetpost',{
            GET = "ROUTEGETPOSTGET",
            POST = "ROUTEGETPOSTPOST"
        })
        assert.truthy(app.pathes.get.pathes['/routegetpost'])
        assert.truthy(app.pathes.post.pathes['/routegetpost'])
    end)

    it("should set a route name for a path with GET", function()
        local app = require'core.Application'("get_name")

        app:GET({get='/getname'}, "GETNAME")
        local name, path = 'get', '/getname'

        assert.truthy(app.pathes.get.pathes[ path ])
        assert.same( name , app.pathes.get.names[ path ])
        assert.is_table(app.names.get[ name ])
        assert.same( path , app.names.get[ name ][1])
    end)

    it("should set a case insensitive name", function()
        local app = require'core.Application'("get_insensitive_name")

        app:GET({InSenSiTIve='/getname'}, "GETNAME")
        local name, path = 'insensitive', '/getname'

        assert.truthy(app.pathes.get.pathes[ path ])
        assert.same( name , app.pathes.get.names[ path ])
        assert.is_table(app.names.get[ name ])
        assert.same( path , app.names.get[ name ][1])
    end)


    it("should set a route name for a path with POST", function()
        local app = require'core.Application'("get_name")

        app:POST({post='/postname'}, "POSTNAME")
        local name, path = 'post', '/postname'

        assert.truthy(app.pathes.post.pathes[ path ])
        assert.same( name , app.pathes.post.names[ path ])
        assert.is_table(app.names.post[ name ])
        assert.same( path , app.names.post[ name ][1])
    end)

    it("should set a route name for a path with GET and POST without complaining", function()
        local app = require'core.Application'("get_post_name")

        app:GET({aname='/getname'}, "GETNAME")
        app:POST({aname='/postname'}, "POSTNAME")
        local name, getpath, postpath = 'aname', '/getname', '/postname'

        -- GET
        assert.truthy(app.pathes.get.pathes[ getpath ])
        assert.same( name , app.pathes.get.names[ getpath ])
        assert.is_table(app.names.get[ name ])
        assert.same( getpath , app.names.get[ name ][1])

        -- POST
        assert.truthy(app.pathes.post.pathes[ postpath ])
        assert.same( name , app.pathes.post.names[ postpath ])
        assert.is_table(app.names.post[ name ])
        assert.same( postpath , app.names.post[ name ][1])

    end)

    it("should set a route name for a path with both GET and POST from ROUTE", function()
        local app = require'core.Application'("route_get_post_name")
        app:ROUTE({routename='/routename'},{
            GET = "GETROUTENAME",
            POST = "POSTROUTENAME"
        })
        local name, path = 'routename', '/routename'

        -- GET
        assert.truthy(app.pathes.get.pathes[ path ])
        assert.same( name , app.pathes.get.names[ path ])
        assert.is_table(app.names.get[ name ])
        assert.same( path , app.names.get[ name ][1])

        -- POST
        assert.truthy(app.pathes.post.pathes[ path ])
        assert.same( name , app.pathes.post.names[ path ])
        assert.is_table(app.names.post[ name ])
        assert.same( path , app.names.post[ name ][1])
    end)

    it("should accept a path with named parameters", function()
        local app = require'core.Application'("get_with_params")
        local e_path = '/get/:with/params'
        app:GET(e_path, "WITHPARAMS")
        local rx, values = next(app.pathes.get.rx)
        assert.is_table(values)
        assert.same('WITH', string.match('/get/WITH/params', rx))
        assert.is_nil( string.match('/get/WITH/params/EXTRA', rx))
        assert.is_nil( string.match('/get/WITH/EXTRA/params', rx))
        assert.same( 'with', values[2][1] )
    end)

    it("should accept a path with variable unmamed parameters", function()
        local app = require'core.Application'("get_with_wildcard")
        app:GET('/get/with/*', 'GETWILDCARD')
        local rx, values = next(app.pathes.get.rx)
        assert.same('EXTRA/VALUES', string.match('/get/with/EXTRA/VALUES', rx))
        assert.is_true( values[2].splat )
    end)

    it("should accept a path with both named and variable unmamed parameters", function()
        local app = require'core.Application'("get_named_and_wildcard")
        app:GET('/get/with/:named/and/*', 'GETNAMEDANDWILDCARD')
        local rx, values = next(app.pathes.get.rx)
        assert.same('NAMED', string.match('/get/with/NAMED/and', rx))
        assert.same( {'NAMED', 'EXTRA/PARAMS'}, {string.match('/get/with/NAMED/and/EXTRA/PARAMS', rx)} )
        assert.is_true( values[2].splat )
    end)

    it("should return url_for a named route", function()
        local app = require'core.Application'("url_for")
        app:GET({name='/named/route'}, "URL_FOR")
        assert.same( '/named/route',  app:url_for('name') )
    end)

    it("should return url_for a case insensitive named route", function()
        local app = require'core.Application'("url_for")
        app:GET({name='/named/route'}, "URL_FOR")
        assert.same( '/named/route',  app:url_for('NamE') )
    end)

    it("should return url_for a name with defined parameters", function()
        local app = require'core.Application'("url_for_named_params")
        app:GET({name='/some/:named/:params'}, "URL_FOR_NAMED_PARAMS")
        assert.same( '/some/NAMED/PARAMS', app:url_for('name', { named="NAMED", params="PARAMS" }) )
        assert.same( '/some/NAMED', app:url_for('name', { named="NAMED" }) )
        assert.same( '/some//PARAMS', app:url_for('name', { params="PARAMS" }) )
    end)

    it("should return parameters at their correct position when some of them are missing", function()
        local app = require'core.Application'("url_for_named_params")
        app:GET({name='/some/:named/:params/missing'}, "URL_FOR_MISSING_NAMED_PARAMS")
        assert.same( '/some/NAMED/PARAMS/missing', app:url_for('name', { named="NAMED", params="PARAMS" }) )
        assert.same( '/some/NAMED//missing', app:url_for('name', { named="NAMED" }) )
    end)


    it("should return url_for a name with variable parameters", function()
        local app = require'core.Application'("url_for_unnamed_params")
        app:GET({wildcard='/url/with/*'}, 'URLWITHWILDCARD')
        assert.same( '/url/with', app:url_for('wildcard') )
        assert.same( '/url/with/EXTRA/PARAMS', app:url_for('wildcard', {'EXTRA','PARAMS'}) )
    end)
    
    it("should provide env and req objects", function()
        local app = require'core.Application'("env_and_req")
        local f = function(env, req)
            assert.is_table(env)
            assert.is_table(req)
        end
        app:GET('/envreq', f)

    end)

    it("should include another application", function()
        local app = require'core.Application'("first")
        local second = app:include('spec.apps.second')
        assert.same('first', app.name)
        assert.same('second', second.name)
        assert.same(app.pathes, second.pathes)
        assert.same(app.names, second.names)

        assert.is_true(second.included)

        assert.truthy(app.pathes.get.pathes[ '/second/path' ])

    end)

    it("should include an instanciated application", function()
        local app = require'core.Application'("first")
        app:GET("/first", "FIRST")
        local second = require'core.Application'("second")
        second:GET("/second", "SECOND")

        local res = app:include(second)

        assert.is_table(res)
        assert.same('first', app.name)
        assert.same('second', second.name)
        assert.same('second', res.name)

        assert.same( app.pathes, second.pathes )
        assert.same( app.pathes, res.pathes )

        assert.same( app.names, second.names )
        assert.same( app.names, res.names )
    end)

end)
