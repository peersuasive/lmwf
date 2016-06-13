--[==[
httpd application
--]==]

local dbg = dbg
local escape_pattern = require'helpers.utils'.escape_pattern
local format = string.format
local concat = table.concat

local function url_for(self, name, params, method)
    if not name then return nil, "Missing route name" end
    --dbg("LOOKING FOR %s -> %s", name, ('table'==type(self.names[name])and self.names[name][1] or self.names[name]))
    local method = (method or'get'):lower()
    local name = name:lower()

    local v = self.names[method][name]
    if not v then
        dbg("url_for: ROUTE NOT FOUND for '%s' (%s)", name, method)
        return nil
    end

    local url, matches = unpack(v)
    if not matches then return url
    else
        local wc = {}
        for k,v in pairs(params or {}) do
            if 'number'==type(k) then
                wc[#wc+1] = v
            else
                local found
                url, found = url:gsub(':'..k, v)
                if found==0 then
                    dbg("WARNING: unknown parameter: %s in '%s'", k, name)
                end
            end
        end
        wc = concat(wc, '/')

        --return url:gsub('/?:[^/]+',''):gsub('/%*$','')
        return url:gsub('/(:[^/]+)','/')
                  :gsub('%*$',wc)
                  :gsub('/$','')

        -- missing named parameters could throw an error...
        --local missing = {url:match('/:([^/]+)')}
        --if #missing>0 then
        --    return nil, "Missing parameters: " .. concat(missing, ', ') end
        --return url:gsub('%*$',wc)
    end

    --local v = self.names[name]
    --if not v then
    --    dbg("url_for: ROUTE NOT FOUND for '%s'", name)
    --    return nil
    --end
    --if 'string'==type(v) then
    --    return v
    --else
    --    local url, matches = unpack(v)
    --    for k,v in pairs(params or {}) do
    --        local found
    --        url, found = url:gsub(':'..k, v)
    --        if found==0 then
    --            dbg("WARNING: unknown parameter: %s in '%s'", k, name)
    --        end
    --    end
    --    return url:gsub('/?:[^/]+',''):gsub('/%*$','')
    --end
end

local function add_route(self, method, route, cb)
    local method = method:lower()
    local path, name = route
    if 'table'==type(route) then
        name, path = next(route)
    end
    local name = name and name:lower() or nil
    if not path then
        error(string.format("No path provided%s", name and ' (for name '..name..')'or''), 3) end

    path = path:gsub('.(/)$','')

    if path:match(':[^/]+') or path:match('%*$') then
        local matches = {}
        local e_path = escape_pattern(path)

        local gm = string.gmatch
        for w in gm(path, ":([^/]+)") do
            matches[#matches+1] = w
        end
        e_path = '^'..e_path:gsub(':[^/]+','%(%[%^/%]%+%)'):gsub('/%%%*$','/%?%(%.%*%)')..'$'
        if path:match('%*$')then
            matches.splat = true
        end
        
        local pathes = self.pathes[method]

        __DEBUG_EX(function()
        local def = pathes.rx[e_path]
        if def then
            dbg("WARNING: path '%s' is redefined in '%s' (previously defined in '%s')",
                path, self.name, def.name) end
        end)

        pathes.rx[e_path] = {cb, matches, name, name=self.name}
        --if name then pathes.names[name] = {path} end
        if name then

            __DEBUG_EX(function()
            local def = self.names[method][name]
            if def then
                dbg("WARNING: route '%s' is redefined in '%s' (previously defined in '%s')",
                    name, self.name, def.name) end
            end)

            self.names[name] = {path, matches}
            self.names[method][name] = {path, matches}
        end
    else
        local pathes = self.pathes[method]

        __DEBUG_EX(function()
        local def = pathes.pathes[path]
        if def then
            dbg("WARNING: path '%s' is redefined in '%s' (previously defined in '%s')",
                path, self.name, def.name) end
        end)

        pathes.pathes[path] = {cb, name=self.name}
        --if name then pathes.names[name] = path end
        if name then

            __DEBUG_EX(function()
            local def = self.names[method][name]
            if def then
                dbg("WARNING: route '%s' is redefined in '%s' (previously defined in '%s')",
                    name, self.name, def.name) end
            end)

            pathes.names[path] = name
            --self.names[name] = path
            self.names[method][name] = {path, name=self.name}
        end
    end
end

local mt = {}
function mt:GET(route, cb)
    add_route(self,'GET', route, cb)
end
function mt:POST(route, cb)
    add_route(self,'POST', route, cb)
end
function mt:ROUTE(route, cb)
    local cb = cb
    if 'table'==type(cb) then
        local get, post = cb.GET, cb.POST
        if get then add_route(self, 'GET', route, get) end
        if post then add_route(self, 'POST', route, post) end
    else
        add_route(self, 'GET', route, cb)
    end
end

mt.url_for = url_for

local exportable = {'GET','POST','ROUTE','url_for'}
function mt:export(...)
    local e = ... and {...} or exportable
    local m = {}
    for _,v in pairs(e) do
        if not self[v] then error(format("Unknown method: %s", v)) end
        m[#m+1] = function(...) return self[v](self,...)end
    end
    return unpack(m)
end

function mt:include(m)
    if 'table'==type(m) then -- inject instanciated app
        if m.included then
            return m
        else
            for _,meth in next,{'get','post'} do
                for _,s in next,{'pathes','rx','names'} do
                    local spathes = self.pathes[meth][s]
                    for k, v in next, m.pathes[meth][s] do
                        __DEBUG_EX(function()
                        local def = spathes[k]
                        if def then
                            dbg("WARNING: '%s' (%s) is redefined in '%s' (previously defined in '%s')",
                                k, meth, def.name, v.name) end
                        end)
                        spathes[k] = v
                    end
                end
                local snames = self.names[meth]
                for k, v in next, m.names[meth] do
                    __DEBUG_EX(function()
                    local def = self.names[method][name]
                    if def then
                        dbg("WARNING: route '%s' is redefined in '%s' (previously defined in '%s')",
                            name, def.name, v.name) end
                    end)
                    snames[k] = v
                end
            end
            setmetatable(m, {__index=self})
            return m
        end
    end
    _G.__APP_INCLUDING_MODULE__ = getmetatable(self)
    local m = require(m)
    _G.__APP_INCLUDING_MODULE__ = nil
    return m
end

local static = {
    new = new,
    url_for = url_for
}

local function new(self, name, export)
    local __inc = __APP_INCLUDING_MODULE__ 
    local priv = __inc or {
        pathes = {
            get  = {
                pathes = {},
                rx = {},
                names = {}
            },
            post = {
                pathes = {},
                rx = {},
                names = {}
            }
        },
        names = {
            get = {},
            post = {}
        }
    }

    local self = { name = name or 'UNK', included = __APP_INCLUDING_MODULE__ and true }
    setmetatable(self, priv)
    priv.__index = priv
    priv.__newindex = function()end

    setmetatable(priv, mt)
    mt.__index = mt
    mt.__newindex = function()end

    local exports = export and {self:export( unpack('table'==type(export) and export or {}) )} or {}
    return self, unpack(exports)
end

return setmetatable(static, {
    --__call = function(_,...) return new(...) end,
    __call = new,
    __newindex = function()end
})
