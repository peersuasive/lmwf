local app = require'core.Application'('main')

app:include'apps.version'

app:GET('/', "Welcome to Lua Minimalist Web Framework")

app:include'apps.hello'

return app
