local app = require'lmwf.Application'("second")

app:GET('/stopme', function()
    __RUNNING = false
end)

return app
