scriptencoding utf-8
if exists('g:load_FzfFileSelector')
 finish
endif
let g:load_FzfFileSelector = 1

let s:save_cpo = &cpo
set cpo&vim

"nnoremap <silent> <Plug>selectable-gf :lua require('FzfFileSelector').gf(vim.fn.expand('<cfile>'))<cr>
nnoremap <silent> <Plug>selectable-gf :lua require('FzfFileSelector').run_cfile()<cr>
nnoremap <silent> <Plug>fzf-file-selector :lua require('FzfFileSelector').run()<cr>


let &cpo = s:save_cpo
unlet s:save_cpo
