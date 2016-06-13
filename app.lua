local app = require'core.Application'('main')

app:GET('/version', "OPDS CS Version 0.1")

app:GET('/', "Welcome to Lua Minimalist Web Framework")

return app
