local app = require'core.Application'('version')

app:GET('/version', "Lua Minimalist Web Framework v0.1")

return app
