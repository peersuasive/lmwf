local socket = require'lmwf.libhttpd'
local concat = table.concat
local mt
mt = {
    set_headers = function(client, headers, status, status_msg)
        local content_type, status, status_msg = 'text/html', status or 200, status_msg or "OK"
        local h = {}
        if 'table'==type(headers) and next(headers) then
            for header, v in pairs(headers) do
                --if header:match('[Cc][Oo][Nn][Tt][Ee][Nn][Tt]%-[Tt][Yy][Pp][Ee]') then content_type = v
                local hdr=header:lower()
                if hdr=='content-type' then content_type = v
                else
                    h[#h+1] = header..': '..v end
            end
        end
        local message = { 
            "HTTP/1.1 "..status.." "..status_msg,
            "Server: lua-httpd " .. socket.version,
            "Content-type: " .. content_type,
        }
        if #h>0 then message[#message+1] = concat(h, '\r\n') end
        message[#message+1] = "Connection: close\r\n\r\n"
        message = concat(message, '\r\n')

        socket.write(client, message)
    end,

    send_response = function(client, content, headers, status, status_msg, content_type)
        mt.set_headers(client, headers, status, status_msg, content_type)
        local s = socket.write(client, content)
        socket.close(client)
        return s
    end,
    send_file = function(client, filename, headers, status)
        local f = io.open(filename, 'rb')
        if not f then return mt.send_error(client, 404, 'File not found') end

        local size = f:seek('end')
        f:seek('set')
        local max_size = 2^20 -- 1M

        headers = headers or {}
        headers['Content-length'] = size
        mt.set_headers(client, headers, status)

        if size < max_size then
            print("Sending small file", size)
            local data = f:read('*a')
            f:close()
            local s = socket.write(data)
            return #data==size and s==size, s, #data, size
        end

        local readsize, sent = 0, 0
        --local bufsize = 2^14 -- 16K
        local bufsize = 2^20 -- 1M
        while true do
            local d = f:read(bufsize)
            if not d then break end
            readsize = readsize + #d
            local s, err = socket.write(client, d)
            if not s then
                f:close()
                socket.close(client)
                return s, err
            end
            sent = sent + s
        end
        f:close()
        socket.close(client)
        return size==readsize and sent==size, sent, readsize, size
    end,
    send_error = function(client, status, msg, status_msg, content_type)
        local msg = "<html><head><title>Error</title></head><body><center><h1>Error</h1><p>"
                ..(msg or status).."</p></center></body></html>"

        return mt.send_response(client, msg, _, status or 500, status_msg, content_type)
    end,
    send_custom_error = function(client, status, msg, status_msg, content_type)
        return mt.send_response(client, msg, _, status or 500, status_msg, content_type)
    end,
}

local priv = {
    close = function(client)
        return socket.close(client)
    end,
    accept = function(listener)
        return socket.accept(listener)
    end,
    bind = function(port, ip)
        -- TODO: add ip to libhttpd
        return socket.bind(port, ip)
    end,
    read = function(client)
        return socket.read(client)
    end,
    write = function(client, msg)
        return socket.write(client, msg)
    end,
}

return setmetatable(mt, {
    __index = priv,
    __newindex = function()end
})
