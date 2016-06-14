local app = require'lmwf.Application'('app')

app:GET('/hello', "Missing username: Usage: /hello/YOURNAME")

app:GET('/hello/:name', function(env, req)
    return "Hello, "..req.params.name
end)
