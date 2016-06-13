local function plain_text(content, env)
    return content
end

return {
    exts = {'txt'},
    handle = plain_text,
    code = false
}
