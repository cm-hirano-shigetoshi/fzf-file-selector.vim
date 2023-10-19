local M = {}
local utils = require("utils")
local fzf = require("fzf")
local posix = require("posix")

require("fzf").default_options = {
    window_on_create = function()
        vim.cmd("set winhl=Normal:Normal")
    end
}

SERVER_PID = -1
PYTHON = "python"
PLUGIN_DIR = "."
CURL = "curl"
FD = "fd"

search_origins = {}
path_notation_ = "relative"
entity_type_ = "f"
file_filter_ = "default"


local function print_table(t, file)
    for k, v in pairs(t) do
        file:write(k .. " = '" .. tostring(v) .. "'")
    end
end

local function spawn(process, args)
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

local function get_path_notation_option(path_notation)
    if path_notation == "relative" then
        return ""
    elseif path_notation == "absolute" then
        return "--absolute-path"
    else
        assert(false, "Unsupported path notation: " .. path_notation)
    end
end

local function get_entity_type_option(entity_type)
    if entity_type == "A" then
        return ""
    else
        return "--type " .. entity_type
    end
end


local function get_file_filter_option(file_filter)
    if file_filter == "default" then
        return ""
    else
        return "--" .. file_filter
    end
end


local function get_fd_command(d, path_notation, entity_type, file_filter)
    path_notation = path_notation or path_notation_
    entity_type = entity_type or entity_type_
    file_filter = file_filter or file_filter_

    local commands = {}
    table.insert(commands, FD)
    table.insert(commands, get_path_notation_option(path_notation))
    table.insert(commands, get_entity_type_option(entity_type))
    table.insert(commands, get_file_filter_option(file_filter))
    table.insert(commands, "--color always")
    table.insert(commands, "^")
    table.insert(commands, d)

    local result = {}
    for _, v in ipairs(commands) do
        if #v > 0 then
            table.insert(result, v)
        end
    end

    return table.concat(result, " ")
end

local function option_to_shell_string(key, value)
    if value == true then
        return "--" .. key
    elseif utils.is_array(value) then
        local strs = {}
        for _, v in ipairs(value) do
            --assert "'" not in str(v), f"Invalid option was specified: {v}"
            table.insert(strs, "--" .. key .. " '" .. v .. "'")
        end
        return table.concat(strs, " ")
    else
        --assert "'" not in str(value), f"Invalid option was specified: {value}"
        return "--" .. key .. " '" .. value .. "'"
    end
end


local function options_to_shell_string(options)
    local arr = {}
    for k, v in pairs(options) do
        table.insert(arr, option_to_shell_string(k, v))
    end
    return arr
end

local function get_fzf_options_core(d, query, server_port)
    local options = {
        multi = true,
        ansi = true,
        query = query,
        bind = {
            'alt-u:execute-silent(curl "http://localhost:' .. server_port .. '?origin_move=up")',
            'alt-p:execute-silent(curl "http://localhost:' .. server_port .. '?origin_move=back")',
            'alt-a:execute-silent(curl "http://localhost:' .. server_port .. '?path_notation=absolute")',
            'alt-r:execute-silent(curl "http://localhost:' .. server_port .. '?path_notation=relative")',
            'alt-d:execute-silent(curl "http://localhost:' .. server_port .. '?entity_type=d")',
            'alt-f:execute-silent(curl "http://localhost:' .. server_port .. '?entity_type=f")',
            'alt-s:execute-silent(curl "http://localhost:' .. server_port .. '?entity_type=A")',
            'alt-n:execute-silent(curl "http://localhost:' .. server_port .. '?file_filter=default")',
            'alt-i:execute-silent(curl "http://localhost:' .. server_port .. '?file_filter=no-ignore")',
            'alt-h:execute-silent(curl "http://localhost:' .. server_port .. '?file_filter=hidden")',
            'alt-l:execute-silent(curl "http://localhost:' .. server_port .. '?file_filter=unrestricted")',
        },
    }
    return table.concat(options_to_shell_string(options), " ")
end

local function get_fzf_options_view(abs_dir)
    return ("--reverse --header '%s' --preview 'bat --color always {}' --preview-window down"):format(abs_dir)
end

local function get_fzf_options(d, query, server_port)
    local abs_dir = utils.get_absdir_view(d)
    return table.concat({ get_fzf_options_core(d, query, server_port), get_fzf_options_view(abs_dir), }, " ")
end


local function get_fzf_dict(d, query, server_port)
    return { options = get_fzf_options(d, query, server_port) }
end

local function get_command_json(origin, a_query, server_port)
    local fd_command = get_fd_command(origin)
    local fzf_dict = get_fzf_dict(origin, a_query, server_port)
    local fzf_port = utils.get_available_port()
    return { fd_command = fd_command, fzf_dict = fzf_dict, fzf_port = fzf_port }
    --[[
    local cmd_list = { PYTHON, PLUGIN_DIR .. "/python/create_fzf_command.py", origin, a_query, server_port }
    local cmd = table.concat(cmd_list, " ")
    local handle = assert(io.popen(cmd))
    local command_str = handle:read("*a")
    handle:close()
    return dkjson.decode(command_str)
    ]]
end

local function execute_fzf(fd_command, fzf_dict, fzf_port)
    local options = "--listen " .. fzf_port .. " " .. fzf_dict["options"]
    coroutine.wrap(function(fd_command, options)
        local result = fzf.fzf(fd_command, options)
        os.execute("kill " .. SERVER_PID)
        vim.api.nvim_command("next " .. table.concat(result, " "))
    end)(fd_command, options)
end

M.run = function(a_query)
    if false then
        vim.api.nvim_feedkeys("gf", "n", {})
    else
        vim.api.nvim_set_var("fzf_layout", { window = 'enew' })

        local server_port = start_server()
        local command_json = get_command_json(".", a_query, server_port)

        local fd_command = command_json["fd_command"]
        local fzf_dict = command_json["fzf_dict"]
        local fzf_port = command_json["fzf_port"]
        os.execute(table.concat({ CURL,
                "localhost:" .. server_port .. "?set_fzf_port=" .. fzf_port,
                ">/dev/null 2>&1" },
            " "))
        execute_fzf(fd_command, fzf_dict, fzf_port)
    end
end

return M
