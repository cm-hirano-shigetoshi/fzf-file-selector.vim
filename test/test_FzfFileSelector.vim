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


let test_get_cursor_from_items = [
            \['python', 1],
            \['./python', 1],
            \['../python', 0],
            \['apython', 0],
            \['/python', 0],
            \['/etc', 1],
            \['.', 1],
            \['/.', 1],
            \['..', 1],
            \['/..', 1],
            \]
call s:unit_test(function('FzfFileSelector#is_gf_accessible'), test_get_cursor_from_items)


let &cpo = s:save_cpo
unlet s:save_cpo
