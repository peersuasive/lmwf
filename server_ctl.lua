#!/usr/bin/env luajit

local VERSION = 'Lua Minimalist Web Framework 0.1 - (c) 2016 Peersuasive Technologies'

local format = string.format
local function err(msg, ...)
    local msg='ERROR: '..msg..'\n'
    if ... then
        io.stderr:write( format(msg, ...) )
    else
        io.stderr:write( msg )
    end
    os.exit(1)
end

local function usage()
    print(
format([[Usage: %s [OPTIONS] [main app]

Options:
    -h,--help                   this message
    -D,--debug                  enable live reloading and show debug traces
    -H,--host <hostname|IP>     listen on hostname
    -p,--port <port number>     listen on port number
    -v,--version                print version number
]], arg[0])
)
end

local args = {...}
local params = {}
local config_file, config_default = 'lmwf.conf', {
    host = 'localhost',
    port = 8080,
    app = 'app',
    views = 'views',
    loaders = 'loaders',
}
local i,max=1,#args+1
while true do
    if i==max then break end
    local o = args[i]
    if o=='-h' or o=='--help' then
        usage()
        os.exit(1)
    elseif o=='-D' or o=='--debug' then
        _G.__DEBUG = true
    elseif o=='-H' or o=='--host' then
        i=i+1
        local val = args[i]
        if not(val) or val:match('^%-') then err("Missing paramater for option %s", o) end
        params.host = val
    elseif o=='-p' or o=='--port' then
        i=i+1
        local port = args[i]
        args[i+1] = nil
        if not(port) or not(port:match('^[0-9]+$')) then err("Wrong parameter for option %s: %s", o, port) end
        params.port = tonumber(port)
    elseif o=='-v' or o=='--views' then
        i=i+1
        local val = args[i]
        if not(val) or val:match('^%-') then err("Missing paramater for option %s", o) end
        params.views = val
    elseif o=='-l' or o=='--loaders' then
        i=i+1
        local val = args[i]
        if not(val) or val:match('^%-') then err("Missing paramater for option %s", o) end
        params.loaders = val
    elseif o=='-c' or o=='--config' then
        i=i+1
        local val = args[i]
        if not(val) or val:match('^%-') then err("Missing paramater for option %s", o) end
        config_file = val
    elseif o=='-v' or v=='--version' then
        print(VERSION)
        os.exit(0)
    elseif o:match('^%-') then
        err("Unknown option: %s", o)
    else
        params.app = o:gsub('%.[^.]+$','')
    end
    i=i+1
end

local config = io.open(config_file)
if config then
    local c = config:read('*a')
    config:close()
    config = assert( loadstring('return '..c) )()
else
    config = config_default
end
for k,v in next,config_default do
    config[k] = params[k] or config[k] or v
end

package.cpath = './wrappers/?.so;./wrappers/?.dylib;'..package.cpath
local socket = require'core.socket'
require'core.debug_utils'

local listener = assert( socket.bind( config.port ) )

if not __DEBUG then
    print(format("Starting server on %s:%s", config.host, config.port))
    local httpd = require'core.httpd'(_, socket, listener, config.app)
    while true do
        httpd:serve()
    end
else
    dbg("Starting server on port %s", config.port)
    while true do
        local httpd = require'core.httpd'(_, socket, listener, config.app)
        local r, res, err = pcall( httpd.serve, httpd )
        if not r then
            print(format("ERROR (loader): %s", res))
        elseif not res then
            print(format("INTERNAL ERROR (loader): %s", err))
        end
        __unload()
    end
end
