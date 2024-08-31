local M = {}
local utils = require("utils")
local fzf = require("fzf")

require("fzf").default_options = {
    window_on_create = function()
        vim.cmd("set winhl=Normal:Normal")
    end
}

SERVER_PID = -1
PYTHON = "python"
PLUGIN_DIR = debug.getinfo(1).source:sub(2):match('^(.*)/lua/[^/]+$')
CURL = "curl"
FD = "fd"


local function start_server()
    if SERVER_PID > 0 then
        os.execute("kill " .. SERVER_PID)
    end
    local s_server = utils.create_server()
    local f_server = utils.create_server()
    local _, server_port = s_server:getsockname(); s_server:close()
    local _, fzf_port = f_server:getsockname(); f_server:close()
    local pid = utils.spawn(PYTHON, { PLUGIN_DIR .. "/python/internal_server.py", ".", server_port, fzf_port })
    SERVER_PID = pid
    return server_port, fzf_port
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
    path_notation = path_notation or "relative"
    entity_type = entity_type or "f"
    file_filter = file_filter or "default"

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

local function get_fzf_options_core(query, server_port)
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
    return ("--reverse --header '%s' --preview 'bat --plain --number --color always {}' --preview-window down"):format(
        abs_dir)
end

local function get_fzf_options(d, query, server_port)
    local abs_dir = utils.get_absdir_view(d)
    return table.concat({ get_fzf_options_core(query, server_port), get_fzf_options_view(abs_dir), }, " ")
end


local function get_fzf_dict(d, query, server_port)
    return { options = get_fzf_options(d, query, server_port) }
end

local function get_command_json(origin, a_query, server_port)
    local fd_command = get_fd_command(origin)
    local fzf_dict = get_fzf_dict(origin, a_query, server_port)
    return { fd_command = fd_command, fzf_dict = fzf_dict }
end

local function execute_fzf(fd_command_, fzf_dict, fzf_port)
    local options_ = "--listen " .. fzf_port .. " " .. fzf_dict["options"]
    coroutine.wrap(function(fd_command, options)
        local result = fzf.fzf(fd_command, options)
        os.execute("kill " .. SERVER_PID)
        vim.api.nvim_command("next " .. table.concat(result, " "))
    end)(fd_command_, options_)
end

local function call(a_query)
    vim.api.nvim_set_var("fzf_layout", { window = 'enew' })

    local server_port, fzf_port = start_server()
    local command_json = get_command_json(".", a_query, server_port)

    local fd_command = command_json["fd_command"]
    local fzf_dict = command_json["fzf_dict"]
    os.execute(table.concat({ CURL,
            "localhost:" .. server_port .. "?set_fzf_port=" .. fzf_port,
            ">/dev/null 2>&1" },
        " "))
    execute_fzf(fd_command, fzf_dict, fzf_port)
end

M.run = function()
    call("")
end

M.run_cfile = function()
    local cfile = vim.fn.expand('<cfile>'):gsub("^%./", "")
    call(cfile)
end

local function is_gf_accessible(filename)
    local path_dirs = vim.opt.path:get()
    if filename:sub(1, 1) == "/" then
        path_dirs = { "" }
    end
    for _, dir in ipairs(path_dirs) do
        if #vim.fn.glob(dir .. '/' .. filename) > 0 then
            return true
        end
    end
    return false
end

M.gf = function(a_query)
    if is_gf_accessible(a_query) then
        vim.api.nvim_feedkeys("gf", "n", {})
    else
        call(a_query .. " ")
    end
end

return M
