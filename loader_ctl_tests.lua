#!/usr/bin/env luajit
local posix = require'posix'
local signal = require'posix.signal'
local format = string.format
local socket = require'wrappers.lua-httpd'

local mt = {}
function mt:stop_server(pid)
    local pid = self.pid~=0 and self.pid or pid
    self.__HTTPD_RUNNING__ = false
    socket.close( self.listener )
    if pid and tonumber(pid) and pid ~= 0 then
        --print("KILL", pid)
        signal.kill( pid )
        posix.wait(pid)
    end
    self.listener = nil
    __unload()
end

function mt:get_httpd()
    return self.httpd
end
function mt:start_server(app)
    local config = self.config
    local listener = assert( socket.bind( config.port ) )
    self.listener = listener
    local httpd = require'core.httpd'(config, socket, self.listener, app)
    if not httpd  then
        error("Can't load httpd class") end
    self.httpd = httpd

    local pid = posix.fork()
    if pid == 0 then
        local err_msg
        local app = app or self.main_app
        if not self.listener then
            error("Listener not started") end

        local r, res, err = pcall( httpd.serve, httpd )

        local s, serr, sc = socket.close( listener )
        if not r then
            error(res, 2)
            posix._exit(1)
        else
            posix._exit(0)
        end

        --[==[
        __HTTPD_RUNNING__ = true
        while __HTTPD_RUNNING__ do
            -- this is here because we want to reload it when debugging
            local httpd = require'httpd'(config, socket, self.listener, app)
            if not httpd then break end
            local r, res, err = pcall( httpd.serve, httpd )
            if not r and __TEST then
                self.errors = res
                err_msg = res
                break
                --return false, res
            else 
                -- TODO: error if not debugging
                if not r then
                    print(format("ERROR (loader): %s", res))
                    break
                elseif not res then
                    print(format("INTERNAL ERROR (loader): %s", err))
                    break
                end
            end
            --__unload()
        end
        socket.close( self.listener )
        if err_msg then
            if 'table'==type(err_msg) then
                posix.write(pipew, err_msg.message or 'NONE')
            end
            posix.close(pipew)
            --posix._exit(1)
            error(err_msg, 3)
        else
            posix.close(pipew)
            posix._exit(0)
        end
        --]==]
    else
        --print("parent pid:", posix.getpid('pid'), "child pid", pid)
        local s, serr, sc = socket.close( listener )
        rawset(self, 'pid', pid)
        return pid, httpd
    end
end

local function new(_, config, dbg)
    local config = config or {}
    config.port = config.port or 1444
    
    __DEBUG = dbg
    require'core.debug_utils'
    local self = {
        config = config,
        pid = 0
    }
    return setmetatable(mt, {__index = self})
end

return setmetatable({new=new}, {
    __call = new
})
