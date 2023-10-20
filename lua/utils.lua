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

function M.create_server()
    return assert(socket.bind('*', 0))
end

function M.get_absdir_view(path, home_dir)
    home_dir = home_dir or os.getenv("HOME")
    local abs_dir = posix.realpath(path)
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

function M.print_table(t, file)
    for k, v in pairs(t) do
        file:write(k .. " = '" .. tostring(v) .. "'")
    end
end

function M.spawn(process, args)
    local pid, err = posix.fork()
    if pid == nil then
        print("エラー", err)
        os.exit(1)
    elseif pid == 0 then
        posix.getpid('pid')
        posix.execp(process, args)
        os.exit(1)
    end
    return pid
end

return M
