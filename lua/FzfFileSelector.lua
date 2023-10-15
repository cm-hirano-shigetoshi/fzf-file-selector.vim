local M = {}
local fzf = require("fzf")
local dkjson = require "dkjson"

require("fzf").default_options = {
    window_on_create = function()
        vim.cmd("set winhl=Normal:Normal")
    end
}

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
                local file = io.open(filepath, "w")
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

local function execute_fzf(dirname)
    coroutine.wrap(function(dirname)
        local result = fzf.fzf("(cd " .. dirname .. " && rg --color always -L -n ^)",
            "--ansi --reverse --delimiter : --with-nth 2..")
        if result then
            local sp = split(result[1], ":")
            vim.api.nvim_set_current_buf(tonumber(sp[1]))
            vim.api.nvim_win_set_cursor(0, { tonumber(sp[3]), 0 })
        end
        os.execute("rm -fr " .. dirname)
    end)(dirname)
end

local function join(list, sep)
    local res = ""
    for i, v in ipairs(list) do
        arg = tostring(v)
        res = res .. (i > 1 and sep or "") .. (#arg > 0 and arg or '""')
    end
    return res
end

local function execute_fzf(fd_command)
    coroutine.wrap(function(fd_command)
        local result = fzf.fzf(fd_command, "--ansi --multi --reverse")
        vim.api.nvim_command("next " .. join(result, " "))
    end)(fd_command)
end

M.run = function(a_query)
    --[[
        if FzfFileSelector#is_gf_accessible(a:query)
            call feedkeys("gf", "n")
        else
            let g:fzf_layout = { 'window': 'enew' }

            let server_port = FzfFileSelector#start_server()

            let command_str = system([s:PYTHON, s:PLUGIN_DIR . "/python/create_fzf_command.py", ".", a:query, server_port])
            let command_json = json_decode(command_str)

            let fd_command = command_json["fd_command"]
            let fzf_dict = command_json["fzf_dict"]
            let fzf_port = command_json["fzf_port"]
            call system([s:CURL, "localhost:" . server_port . "?set_fzf_port=" . fzf_port])
            call FzfFileSelector#get_selected_items(fd_command, fzf_dict, fzf_port)
        endif
    ]]
    --if FzfFileSelector.is_gf_accessible(a_query) then
    if false then
        vim.api.nvim_feedkeys("gf", "n", {})
    else
        vim.api.nvim_set_var("fzf_layout", { window = 'enew' })

        --local server_port = FzfFileSelector.start_server()
        local server_port = 12345
        local s_PYTHON = "python" -- ここに適切な値を設定
        local s_PLUGIN_DIR = "."  -- ここに適切な値を設定
        local cmd_list = { s_PYTHON, s_PLUGIN_DIR .. "/python/create_fzf_command.py", ".", a_query, server_port }
        local cmd = join(cmd_list, " ")
        local handle = io.popen(cmd)
        --local handle = io.popen("echo '{\"aaa\": \"bbb\"}'")
        local command_str = handle:read("*a")
        handle:close()
        local command_json = dkjson.decode(command_str)
        print(command_json)

        local fd_command = command_json["fd_command"]
        --local fzf_dict = command_json["fzf_dict"]
        --local fzf_port = command_json["fzf_port"]
        --local s_CURL = "curl" -- ここに適切な値を設定
        --vim.fn.system({ s_CURL, "localhost:" .. server_port .. "?set_fzf_port=" .. fzf_port })
        --FzfFileSelector.get_selected_items(fd_command, fzf_dict, fzf_port)
        execute_fzf(fd_command)
    end
    --local tmpdir = os.tmpname()
    --dump_buffers(tmpdir)
    --execute_fzf(tmpdir)
end

return M
