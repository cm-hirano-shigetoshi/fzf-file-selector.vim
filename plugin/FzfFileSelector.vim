scriptencoding utf-8
if exists('g:load_FzfFileSelector')
 finish
endif
let g:load_FzfFileSelector = 1

let s:save_cpo = &cpo
set cpo&vim

nnoremap <silent> <Plug>fzf-file-selector :<C-u>call FzfFileSelector#run("")<CR>
nnoremap <silent> gf :<C-u>call FzfFileSelector#gf(expand('<cfile>'))<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
