let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#vital#import('Vim.Message')


function! s:unit_test(f, cases)
    echom('* ' . string(a:f))
    let i = 0
    for case_ in a:cases
        let i = i + 1
        let len_of_args = len(case_)
        let actual = ""
        if len_of_args == 2
            let actual = a:f(case_[0])
        elseif len_of_args == 3
            let actual = a:f(case_[0], case_[1])
        elseif len_of_args == 4
            let actual = a:f(case_[0], case_[1], case_[2])
        endif
        let expected = case_[-1]
        if actual != expected
            call s:V.error(i . ' actual:   ' . string(actual))
            call s:V.error(i . ' expected: ' . string(expected))
        endif
    endfor
endfunction


let test_get_absdir_view = [
            \    ['/Users/sample.user/aaa', '/Users/sample.user', '~/aaa/'],
            \    ['/Users/sample.user/aaa/', '/Users/sample.user', '~/aaa/'],
            \    ['/absolute/path', '/Users/sample.user', '/absolute/path/'],
            \    ['/', '/Users/sample.user', '/'],
            \]
call s:unit_test(function('FzfFileSelector#get_absdir_view'), test_get_absdir_view)


let test_get_parent_dir = [
            \['.', '..'],
            \['/Users', '/'],
            \['/', '/'],
            \['test', '.']
            \]
"call s:unit_test(function('FzfFileSelector#get_parent_dir'), test_get_parent_dir)


let test_get_origin_path_query = [
            \['aaa/bbbccc', 7, ['aaa', 'bbb']],
            \['ls aaa/bbbccc', 10, ['aaa', 'bbb']]
            \]
"call s:unit_test(function('FzfFileSelector#get_origin_path_query'), test_get_origin_path_query)


let test_get_fd_command = [
            \['.', 'relative', 'f', 'fd --type f --color always ^ .'],
            \['.', 'absolute', 'f', 'fd --absolute-path --type f --color always ^ .'],
            \['.', 'absolute', 'A', 'fd --absolute-path --color always ^ .'],
            \['.', 'relative', 'A', 'fd --color always ^ .'], 
            \]
call s:unit_test(function('FzfFileSelector#get_fd_command'), test_get_fd_command)


let test_option_to_shell_string = [
            \[ 'key', v:null, '--key',],
            \[ 'key', ['abc', 'def'], "--key 'abc' --key 'def'",],
            \[ 'key', 123, "--key '123'",],
            \]
call s:unit_test(function('FzfFileSelector#option_to_shell_string'), test_option_to_shell_string)


let test_get_fzf_options_view = [
            \[ '/absolute/path/', "--reverse --header '/absolute/path/' --preview 'bat --color always {}' --preview-window down",],
            \[ '/', "--reverse --header '/' --preview 'bat --color always {}' --preview-window down",], 
            \]
call s:unit_test(function('FzfFileSelector#get_fzf_options_view'), test_get_fzf_options_view)


let test_get_left = [
            \['aaabbb', 3, ''],
            \['aaa bbb', 3, ''],
            \['aaa bbb', 4, 'aaa '],
            \['aaa/bbbccc', 7, ''],
            \]
"call s:unit_test(function('FzfFileSelector#get_left'), test_get_left)


let test_get_right = [
            \['aaabbb', 3, 'bbb'],
            \['aaa bbb', 3, ' bbb'],
            \['aaa bbb', 4, 'bbb'],
            \['aaa/bbbccc', 7, 'ccc'],
            \]
"call s:unit_test(function('FzfFileSelector#get_right'), test_get_right)


let test_get_buffer_from_items = [
            \['aaabbb', 3, 'select1\nselect2\n', 'select1 select2 bbb'],
            \['ls test/abbb', 9, 'select1\nselect2\n', 'ls select1 select2 bbb'], 
            \]
"call s:unit_test(function('FzfFileSelector#get_buffer_from_items'), test_get_buffer_from_items)


let test_get_cursor_from_items = [
            \['aaabbb', 3, 'select1\nselect2\n', 16],
            \['ls test/abbb', 9, 'select1\nselect2\n', 19], 
            \]
"call s:unit_test(function('FzfFileSelector#get_cursor_from_items'), test_get_cursor_from_items)


let &cpo = s:save_cpo
unlet s:save_cpo
