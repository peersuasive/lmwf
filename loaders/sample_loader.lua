local function sample_loader(content, env)
    return content
end

return {
    exts = {'plain'},
    handle = sample_loader,
    code = false
}
