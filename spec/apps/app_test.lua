local app = require'core.Application'("second")

app:GET('/stopme', function()
    __RUNNING = false
end)

return app
