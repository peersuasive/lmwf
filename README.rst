Lua Minimalist Web Framework is a minimalist web framework to serve web pages and RESTfull microservices.

It is greatly inspired by Lapis, without dependency to any web server.

By default, it runs on a slightly modified version of `lua-httpd <https://git.steve.org.uk/git/skx/lua-httpd.git>`_.

``core.httpd`` is a modified version of lua-httpd's.

Requirements
============

    lua 5.1 / luajit

Optional
========

    - moonscript
    - etlua
    - lustache

Tests
=====

    - busted 2.X
    - luaposix
    - luasocket


Usage
=====

    Demo server can be started with ``./start_server``.
    By default, it'll be accessible at http://localhost:8080.

    
Building a web application
==========================

Application class methods
*************************

app:GET
_______

    ``GET( path|{name=path} , STRING|function )``

    Answers to a `GET` request.

    ``path`` must start with a ``/``.
    
    Routes aliased with a ``name`` can be retrieved by `app:url_for`_.

    If a STRING is provided as a callback, it'll be rendered as is.

    ``function`` callback receives two objects: `env`_ and `req`_.

    It can return:

        STRING
            rendered as is

        nil or true
            if the route has an alias, the renderer will look for a ``views/alias`` to render

        a table containing:

              render = nil|true|'VIEW_NAME'
                  if an alias is provided, will render ``views/alias`` if nil or true
                  otherwise, will render ``views/VIEW_NAME``
                 
              headers = {field=value...}
                  set HTTP headers

              content_type = MIMETYPE
                  optional, shorthand for headers={['Content-type']="MIMETYPE"}

              DATA
                  if data is provided, it'll be used instead of rendering the default view

    examples::

        app:GET( '/', "Hello from LMWF!")

        app:GET( {index='/:name'}, function(env, req)
            env.name = req.params.name
            return { render=true }
        end)


app:POST
________

    see `app:GET`_

app:ROUTE
_________

    Allows declaring GET and POST in a single block::

        app:ROUTE({ index = '/post' }, {
            GET = function(env, req)
                return {status=req.STATUS.HTTP_NOT_FOUND, "This view doesn't handle GET requests"}
            end,

            POST = function(env, req)
                env.name = req.params.name
                return {render='index_json', content_type='application/json'}
            end
        })

app:include
___________

    ``app:include'apps.some_other_routes'``

    Allows logic to be splitted in different files.


app:url_for
___________

    ``app:url_for(alias [, params])``

    Returns a formatted url with parameters.

    example::

        url_for( index, {name = "My name"})
        
    would return::

        /My%20name


app:export
__________

    ``app:export([{ORDER...})``

    Exports GET, POST and ROUTE in the local environment, with an optional order

    example::

        local GET, POST, ROUTE = app:export()

        local POST, ROUTE, GET = app:export{'POST', 'ROUTE', 'GET'}
    

    Exportable methods can also be retrieved when instantiating app::

        local app, GET, POST, ROUTE = app:export('myapp', 'export')

        local app, GET, POST = app:export('myapp', {'GET', 'POST'}

env
---

    This table is shared with the view, only useful when rendering a template like lustache
    or a view containing code (lua or moonscript).

req
---

    This object contains all the required HTTP status, the provided parameters and the current request headers::

        {
            STATUS = {...},
            headers = {...},
            params = {...}
        }


Routes
======

    Routes can have required and optional parameters::

        /path/:param
    
    will only respond to ``/path/PARAM``,

    ::

        /path/:param/final

    will only respond to ``/path/PARAM/final``

    but splat path::

        /path/*

    will respond to ``/path``, ``/path/some/thing``, etc.

    Provided parameters can be retrieved from the table ``req.params``, using the original param as a key::

        req.params.param == "PARAM"

    Splat parameters are to be retrieved from the table ``req.params.splat``.


TODO
====
    
    - implement hostname in socket or replace lua-httpd with luasocket

    - ReSTfull API (missing PUT, PATCH and DELETE)

    - docker-ify
    
    - traefik


LICENSE
=======

    `LGPL v3 <https://www.gnu.org/licenses/lgpl-3.0.en.html>`_

