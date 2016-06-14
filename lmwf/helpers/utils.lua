local function escape_pattern(str)
    local punct = "[%^$()%.%[%]*+%-?%%]"
    return (str:gsub(punct, function(p) return "%"..p end))
end


return {
    escape_pattern = escape_pattern
}
