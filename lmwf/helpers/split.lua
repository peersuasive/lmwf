local lpeg      = require "lpeg"
local lpegmatch = lpeg.match
local P, C      = lpeg.P, lpeg.C
local mk_splitter = function(pat)
  if not pat then return end
  pat            = P (pat)
  local nopat    = 1 - pat
  local splitter = (pat + C(nopat^1))^0
  return function(str)
    return lpegmatch(splitter, str)
  end
end

local split = function(str, pat)
    if not(str) or str:match('^%s*$') then return {} end
    return { mk_splitter(pat)(str) }
end

return setmetatable({
    split = split,
    splitter = mk_splitter
}, {
    __call = function(_,...) return split(...) end
})
