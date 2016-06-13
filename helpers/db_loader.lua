local function load_db(env)
    local env = env or 'development'
    local pp = package.path
    package.path = '../backend/?.lua;'..package.path
    local config = require'classes.config'()
    local db_cfg = env:match('^prod') and config.db or config.db_dev
    local db = db_cfg and require'classes.storage'(db_cfg)
    package.path = pp
    return db
end

return load_db
