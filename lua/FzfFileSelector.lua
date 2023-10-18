local M = {}
local utils = require("utils")
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

local function spawn(process, args)
    local posix = require("posix")
    local pid, err = posix.fork()  -- プロセスを分岐させる
    if pid == nil then             -- もしエラーがある場合
        print("エラー", err)
        os.exit(1)                 -- exit
    elseif pid == 0 then           -- 子プロセスの場合
        posix.getpid('pid')        -- 子プロセスのPIDを取得
        posix.execp(process, args) -- 命令を実行
        os.exit(1)                 -- 終了
    end
    return pid                     -- 親プロセスは子プロセスのPIDを返す
end

local function start_server()
    if SERVER_PID >= 0 then
        os.execute("kill " .. SERVER_PID)
    end
    local server_port = utils.get_available_port()
    local pid = spawn(PYTHON, { PLUGIN_DIR .. "/python/internal_server.py", ".", server_port })
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
    local options = "--listen " .. fzf_port .. " " .. fzf_dict["options"]
    coroutine.wrap(function(fd_command, options)
        local result = fzf.fzf(fd_command, options)
        os.execute("kill " .. SERVER_PID)
        vim.api.nvim_command("next " .. utils.join(result, " "))
    end)(fd_command, options)
end

M.run = function(a_query)
    if false then
        vim.api.nvim_feedkeys("gf", "n", {})
    else
        vim.api.nvim_set_var("fzf_layout", { window = 'enew' })

        --local debug = io.open("/tmp/aaa", "a"); debug:write("=== B01 ===" .. "\n"); debug:close();

        local server_port = start_server()
        local cmd_list = { PYTHON, PLUGIN_DIR .. "/python/create_fzf_command.py", ".", a_query, server_port }
        local cmd = utils.join(cmd_list, " ")
        local handle = assert(io.popen(cmd))
        local command_str = handle:read("*a")
        handle:close()
        local command_json = dkjson.decode(command_str)

        local fd_command = command_json["fd_command"]
        local fzf_dict = command_json["fzf_dict"]
        local fzf_port = command_json["fzf_port"]
        os.execute(utils.join({ CURL, "localhost:" .. server_port .. "?set_fzf_port=" .. fzf_port, ">/dev/null 2>&1" },
            " "))
        execute_fzf(fd_command, fzf_dict, fzf_port)
    end
end

return M
