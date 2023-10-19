local M = {}
local posix = require("posix")
local socket = require('socket')

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

function M.get_available_port()
    local server = assert(socket.bind('*', 0))
    local _, port = server:getsockname()
    server:close()
    return port
end

function M.get_absdir_view(p, home_dir)
    home_dir = home_dir or os.getenv("HOME")
    local abs_dir = posix.realpath(p)
    if string.sub(abs_dir, 1, #home_dir) == home_dir then
        abs_dir = "~" .. string.sub(abs_dir, #home_dir + 1)
    end
    if abs_dir ~= "/" then
        abs_dir = abs_dir .. "/"
    end
    return abs_dir
end

function M.is_array(x)
    if type(x) ~= 'table' then return false end
    local i = 0
    for _ in pairs(x) do
        i = i + 1
        if x[i] == nil then return false end
    end
    return true
end

return M
