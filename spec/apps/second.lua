local app = require'lmwf.Application'("second")

app:GET('/second/path', 'SECONDPATH')

return app
