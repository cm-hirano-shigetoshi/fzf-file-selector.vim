local M = {}
local fzf = require("fzf")
local dkjson = require "dkjson"

require("fzf").default_options = {
    window_on_create = function()
        vim.cmd("set winhl=Normal:Normal")
    end
}

SERVER_PID = -1
PYTHON = "python"
PLUGIN_DIR = "."
CURL = "curl"

local function print_table(t, file)
    for k, v in pairs(t) do
        file:write(k .. " = '" .. tostring(v) .. "'")
    end
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function join(list, sep)
    local res = ""
    for i, v in ipairs(list) do
        arg = tostring(v)
        res = res .. (i > 1 and sep or "") .. (#arg > 0 and arg or '""')
    end
    return res
end

local function start_server()
    if SERVER_PID >= 0 then
        os.execute("kill " .. SERVER_PID)
    end
    local cmd = join({ PYTHON, PLUGIN_DIR .. "/python/find_available_port.py" }, " ")
    local handle = assert(io.popen(cmd))
    local server_port = tonumber(handle:read("*a"))
    handle:close()
    local _, pid = vim.loop.spawn(PYTHON, {
        args = { PLUGIN_DIR .. "/python/internal_server.py", ".", server_port },
        stdio = { stdout, stderr } -- stdout, stderrといったオプション設定
    }, function()
    end)
    SERVER_PID = pid
    return server_port
end

local function get_buf_name(buf)
    local fullpath = vim.api.nvim_buf_get_name(buf)
    if string.len(fullpath) > 0 then
        return vim.fn.fnamemodify(fullpath, ":~:.")
    else
        return nil
    end
end

local function dump_buffers(dirname)
    os.execute("rm -fr " .. dirname)
    for buf = 1, vim.fn.bufnr("$") do
        local buf_name = get_buf_name(buf)
        if buf_name then
            local filepath = dirname .. "/" .. buf .. ":" .. buf_name
            os.execute("mkdir -p " .. filepath:match("(.*/)"))
            if vim.api.nvim_buf_is_loaded(buf) then
                local file = assert(io.open(filepath, "w"))
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                for _, line in ipairs(lines) do
                    file:write(line .. "\n")
                end
                file:close()
            else
                os.execute("ln -s " .. vim.api.nvim_buf_get_name(buf) .. " " .. filepath)
            end
        end
    end
end

local function execute_fzf(fd_command, fzf_dict, fzf_port)
    fzf_dict["options"] = "--listen " .. fzf_port .. " " .. fzf_dict["options"]
    coroutine.wrap(function(fd_command, options)
        local result = fzf.fzf(fd_command, options)
        vim.api.nvim_command("next " .. join(result, " "))
    end)(fd_command, fzf_dict["options"])
end

M.run = function(a_query)
    if false then
        vim.api.nvim_feedkeys("gf", "n", {})
    else
        vim.api.nvim_set_var("fzf_layout", { window = 'enew' })

        local server_port = start_server()
        local cmd_list = { PYTHON, PLUGIN_DIR .. "/python/create_fzf_command.py", ".", a_query, server_port }
        local cmd = join(cmd_list, " ")
        local handle = assert(io.popen(cmd))
        local command_str = handle:read("*a")
        handle:close()
        local command_json = dkjson.decode(command_str)

        local fd_command = command_json["fd_command"]
        local fzf_dict = command_json["fzf_dict"]
        local fzf_port = command_json["fzf_port"]
        os.execute(join({ CURL, "localhost:" .. server_port .. "?set_fzf_port=" .. fzf_port, ">/dev/null 2>&1" }, " "))
        execute_fzf(fd_command, fzf_dict, fzf_port)
    end
end

return M
