local M = {}

function M.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function M.join(list, sep)
    local res = ""
    for i, v in ipairs(list) do
        arg = tostring(v)
        res = res .. (i > 1 and sep or "") .. (#arg > 0 and arg or '""')
    end
    return res
end

function M.get_available_port()
    local socket = require('socket')
    local server = assert(socket.bind('*', 0))
    local _, port = server:getsockname()
    server:close()
    return port
end

return M
