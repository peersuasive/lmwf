-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
 
local string = require "string"
local table = require "table"
local format, gsub, byte = string.format, string.gsub, string.byte

local hex = require'hex'.encode
local escaped = function(c)
    return '%%'..byte(c)
end

local function encode(str)
    if str then
        str = gsub(str, "\r?\n", "\r\n")
        str = gsub(str, "([^%w%-%.%_%~%:%/%#%[%]%@%$%'%(%)%*%+%,%;%=%! ])",
            function (c)
                return '%%'..byte(c)
            end)

        str = gsub (str, ' ', '+')
    end
    return str
end


-- for some yet to debug reasons, format causes a segfault with lwan !
--URL encode a string.
local function xencode(str)
    if str then
        local format, gsub, byte = format, gsub, byte
        --Ensure all newlines are in CRLF form
        str = gsub(str, "\r?\n", "\r\n")
        --Percent-encode all non-unreserved characters
        --as per RFC 3986, Section 2.3
        --(except for space, which gets plus-encoded)
        str = gsub(str, "([^%w%-%.%_%~ ])",
            function (c) return format ("%%%02X", byte(c)) end)

        --Convert spaces to plus signs
        str = gsub (str, ' ', '+')
    end
    return str
end

return encode
