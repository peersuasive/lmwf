local app = require'lmwf.Application'('main')

app:include'apps.version'

app:GET('/', "Welcome to Lua Minimalist Web Framework")

app:include'apps.hello'

return app
