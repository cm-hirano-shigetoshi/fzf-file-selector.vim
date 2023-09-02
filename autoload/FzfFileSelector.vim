scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:PLUGIN_DIR = expand('<sfile>:p:h:h')
let s:PYTHON = get(environ(), "FZF_FILE_SELECTOR_PYTHON", "python")
let s:CURL = get(environ(), "FZF_FILE_SELECTOR_CURL", "curl")

let s:server_pid = -1

function! FzfFileSelector#start_server()
    if s:server_pid >= 0
        call jobstop(s:server_pid)
    endif
    let server_port = system([s:PYTHON, s:PLUGIN_DIR . "/python/find_available_port.py"])
    let s:server_pid = jobstart([s:PYTHON, s:PLUGIN_DIR . "/python/internal_server.py", ".", server_port])
    return server_port
endfunction

function! FzfFileSelector#open_files(lines)
    call jobstop(s:server_pid)
    execute 'next ' join(a:lines, ' ')
endfunction

function! FzfFileSelector#get_selected_items(fd_command, fzf_dict, fzf_port)
    let a:fzf_dict["options"] = "--listen " . a:fzf_port . " " . a:fzf_dict["options"]
    let fzf_arguments = {'source': a:fd_command, 'sink*': function('FzfFileSelector#open_files')}
    call extend(fzf_arguments, a:fzf_dict)
    call fzf#run(fzf#wrap(fzf_arguments))
endfunction

function! FzfFileSelector#run(query)
    if has('nvim')
        let g:fzf_layout = { 'window': 'enew' }

        let server_port = FzfFileSelector#start_server()

        let command_str = system([s:PYTHON, s:PLUGIN_DIR . "/python/create_fzf_command.py", ".", a:query, server_port])
        let command_json = json_decode(command_str)

        let fd_command = command_json["fd_command"]
        let fzf_dict = command_json["fzf_dict"]
        let fzf_port = command_json["fzf_port"]
        call system([s:CURL, "localhost:" . server_port . "?set_fzf_port=" . fzf_port])
        call FzfFileSelector#get_selected_items(fd_command, fzf_dict, fzf_port)
    else
    endif
endfunction

function! FzfFileSelector#is_gf_accessible(filename)
    let path_dirs = split(&path, ",")
    if a:filename[0] == "/"
        let path_dirs = [""]
    endif
    for dir in path_dirs
        if len(glob(dir . '/' . a:filename)) > 0
            return 1
        endif
    endfor
    return 0
endfunction

function! FzfFileSelector#gf(query)
    if has('nvim')
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
    else
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
