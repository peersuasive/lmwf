local function set()
    if __DEBUG then
        local debug = debug
        local format = string.format
        local p = pcall(require,'moon') and require'moon'.p or function(t) for k,v in next,t do print(k,v) end end

        local require_ = require_ or require
        local pkg_loaded = {}
        for k,v in next,package.loaded do pkg_loaded[k] = v end

        _G.require = function(mod)
            local r, res = pcall(require_, mod)
            if r then return res
            else
                local info = debug.getinfo(2, "Sl") or {}
                print(format("[%s:%d]:", info.short_src, info.currentline))
                print(res)
                return nil
            end
        end
        _G.__unload = function()
            for k,v in next,package.loaded do
                if pkg_loaded[k]==nil then
                    package.loaded[k] = nil
                end
            end
        end


        _G.__DEBUG_EX = function(f)
            f()
        end

        --local _DEBUG = true
        local function dbg_(lvl, msg,...)
            --if not _DEBUG then return end
            local info = debug.getinfo(lvl, "Sl") or {}
            print(format("[%s:%d]:", info.short_src, info.currentline))
            if('table'==type(msg))then
                p(msg)
            elseif 'table'==type(...) then
                p{ [msg] = ... }
            else
                print(format(msg,...))
            end
        end
        _G.dbg = function(msg, ...)
            return dbg_(2, msg, ...)
        end


    else
        _G.dbg = function()end
        _G.__DEBUG_EX = function()end
        _G.__unload = function()end
    end
    _G.__UNDEBUG = function() _G.dbg = nil _G.__DEBUG_EX = nil _G.__unload = nil _G.__UNDEBUG = nil end
end

set()
return {reset=set}
