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
    -q,--quiet                  be quiet
    -H,--host <IP>              listen on IP only (default: all available IPs)
    -p,--port <port number>     listen on port number
    -v,--version                print version number
]], arg[0])
)
end

local args = {...}
local params = {}
local default_socket = 'lmwf.wrappers.lua-httpd'
local config_file, config_default = 'lmwf.conf', {
    host = 'localhost',
    port = 8080,
    dev = {
        port = 8081,
        host = 'localhost'
    },
    app = 'app',
    views = 'views',
    loaders = 'loaders',
}
local quiet = false

local i,max=1,#args+1
while true do
    if i==max then break end
    local o = args[i]
    if o=='-h' or o=='--help' then
        usage()
        os.exit(1)
    elseif o=='-D' or o=='--debug' then
        _G.__DEBUG = true
    elseif o=='-q' or o=='--quiet' then
        quiet = true
    elseif o=='-H' or o=='--host' then
        i=i+1
        local val = args[i]
        if not(val) or val:match('^%-') then err("Missing paramater for option %s", o) end
        params.host = val
    elseif o=='-p' or o=='--port' then
        i=i+1
        local port = args[i]
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

if __DEBUG then
    config.dev = config.dev or {}
    if params.port then config.dev.port = params.port end
    if params.host then config.dev.host = params.host end
end

local socket = require( config.socket or default_socket )
require'lmwf.debug_utils'

if not __DEBUG then
    local listener = assert( socket.bind( config.port, config.host ) )
    if not quiet then
        print(format("Starting server on %s:%s", config.host or'*', config.port))
    end
    local httpd = require'lmwf.httpd'(_, socket, listener, config.app)
    while true do
        httpd:serve()
    end
else
    local host, port = config.dev.host or config.host, config.dev.port or config.port
    local listener = assert( socket.bind( port, host) )
    dbg("Starting server on port %s:%s", host or'*', port)
    while true do
        local httpd = require'lmwf.httpd'(_, socket, listener, config.app)
        local r, res, err = pcall( httpd.serve, httpd )
        if not r then
            print(format("ERROR (loader): %s", res))
        elseif not res then
            print(format("INTERNAL ERROR (loader): %s", err))
        end
        __unload()
    end
end
