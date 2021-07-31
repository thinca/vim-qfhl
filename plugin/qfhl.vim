if exists('g:loaded_qfhl')
  finish
endif
let g:loaded_qfhl = 1

command! -nargs=0 -bar QfhlEnable QfhlAutoOn | QfhlUpdateAll
command! -nargs=0 -bar QfhlDisable QfhlAutoOff | QfhlClearAll
command! -nargs=0 -bar QfhlToggle execute qfhl#is_auto_on() ?
\                                 'QfhlDisable' : 'QfhlEnable'

command! -nargs=0 -bar QfhlAutoOn call qfhl#set_auto(1)
command! -nargs=0 -bar QfhlAutoOff call qfhl#set_auto(0)
command! -nargs=0 -bar QfhlAutoStatus echo qfhl#is_auto_on() ? 'on' : 'off'
command! -nargs=0 -bar QfhlAutoToggle call qfhl#set_auto(!qfhl#is_auto_on())

command! -nargs=0 -bar -bang QfhlUpdate call qfhl#update(win_getid(), <bang>0)
command! -nargs=0 -bar -bang QfhlUpdateAll call qfhl#update_all(0, <bang>0)
command! -nargs=0 -bar -bang QfhlClear call qfhl#clear(bufnr('%'), <bang>0)
command! -nargs=0 -bar -bang QfhlClearAll call qfhl#clear_all(<bang>0)

if exists('g:qfhl_startup') && g:loaded_qfhl isnot# 'lazy'
  if g:qfhl_startup is# 'enable'
    QfhlEnable
  endif
  finish
endif

function s:lazy_setup() abort
  autocmd! plugin-qfhl-lazy-setup
  augroup! plugin-qfhl-lazy-setup
  QfhlEnable
endfunction

augroup plugin-qfhl-lazy-setup
  autocmd!
  autocmd QuickFixCmdPost * ++nested
  \   call s:lazy_setup()
  \ | delfunction s:lazy_setup
  autocmd FileType qf ++nested
  \   call s:lazy_setup()
  \ | delfunction s:lazy_setup
augroup END
