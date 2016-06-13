local app = require'core.Application'("second")

app:GET('/second/path', 'SECONDPATH')

return app
