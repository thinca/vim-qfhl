scriptversion 4

const s:HL_TYPES = [
\   'error',
\   'warning',
\   'info',
\ ]

let s:hl_groups = {}


" Options

if !exists('g:qfhl#multi_loclist')
  let g:qfhl#multi_loclist = 'keep'
endif


" APIs

function qfhl#set_auto(on) abort
  if !!a:on == qfhl#is_auto_on()
    return v:false
  endif
  if a:on
    call s:setup_autocmd()
  else
    call s:cleanup_autocmd()
  endif
  return v:true
endfunction

function qfhl#is_auto_on() abort
  return exists('#plugin-qfhl-update')
endfunction

function qfhl#update(winid, ...) abort
  let bufnr = winbufnr(a:winid)
  if bufnr < 0
    return
  endif
  let force = a:0 ? a:1 : v:false

  let last_status = getbufvar(bufnr, 'qfhl_last_status', v:null)
  if last_status is v:null
    let last_status = {}
    call setbufvar(bufnr, 'qfhl_last_status', last_status)
  endif

  let current_qf = getqflist(#{id: 0, changedtick: 0})
  if force || current_qf != get(last_status, 'quickfix', {})
    call s:clear_highlights(bufnr, 'quickfix')
    let locations = s:filter_locations_by_bufnr(getqflist(), bufnr)
    call qfhl#add_highlights(locations, 'quickfix')
    let last_status.quickfix = current_qf
  endif

  if g:qfhl#multi_loclist is# 'merge'
    let winids = sort(win_findbuf(bufnr), 'n')
  else
    let winids = [a:winid]
  endif
  let current_ll = {}
  for winid in winids
    let current_ll[winid] = getloclist(winid, #{id: 0, changedtick: 0})
  endfor
  if force || current_ll != get(last_status, 'loclist', {})
    let locations = []
    for winid in winids
      let locations += s:filter_locations_by_bufnr(getloclist(winid), bufnr)
    endfor
    if g:qfhl#multi_loclist isnot# 'keep' || len(locations)
      call s:clear_highlights(bufnr, 'loclist')
      call qfhl#add_highlights(locations, 'loclist')
    endif
    let last_status.loclist = current_ll
  endif
endfunction

function qfhl#update_all(tabnr, ...) abort
  let tabinfos = 0 <= a:tabnr ? gettabinfo(a:tabnr) : gettabinfo()
  let force = a:0 ? a:1 : v:false
  for tabinfo in tabinfos
    for winid in tabinfo.windows
      call qfhl#update(winid, force)
    endfor
  endfor
endfunction

function qfhl#add_highlights(locations, hl_group) abort
  call s:prepare_hl_group(a:hl_group)
  for loc in a:locations
    let bufnr = loc.bufnr
    let lnum = get(loc, 'lnum')
    if !get(loc, 'valid', 1) || lnum <= 0 || !bufloaded(bufnr)
      continue
    endif

    let col = get(loc, 'col') ?? 1
    let end_lnum = get(loc, 'end_lnum') ?? lnum

    let line = getbufline(bufnr, lnum)
    let end_line = lnum == end_lnum ? line : getbufline(bufnr, end_lnum)
    if empty(line) || empty(end_line) || len(line[0]) + 2 < col
      continue
    endif

    let end_col = get(loc, 'end_col')
    if end_col
      if len(end_line[0]) + 2 < end_col
        continue
      endif
    else
      let end_col = len(end_line[0]) + 1
    endif

    let type = get(loc, 'type')
    let hl_type =
    \   type is# 'E' ? 'error' :
    \   type is# 'W' ? 'warning' :
    \   'info'
    let prop_type = printf('qfhl_%s_%s', a:hl_group, hl_type)
    let props = #{
    \   bufnr: bufnr,
    \   type: prop_type,
    \   end_lnum: end_lnum,
    \   end_col: end_col,
    \ }
    call prop_add(lnum, col, props)
  endfor
endfunction

function qfhl#clear(bufnr, keep, ...) abort
  let hl_groups = a:0 ? a:1 : s:existing_hl_groups()
  for hl_group in hl_groups
    call s:clear_highlights(a:bufnr, hl_group)
    if !a:keep
      call s:clear_updated_flag(a:bufnr, hl_group)
    endif
  endfor
endfunction

function qfhl#clear_all(keep, ...) abort
  let hl_groups = a:0 ? a:1 : s:existing_hl_groups()
  for bufinfo in getbufinfo(#{bufloaded: v:true})
    call qfhl#clear(bufinfo.bufnr, a:keep, hl_groups)
  endfor
endfunction


" utils

function s:prepare_hl_group(hl_group) abort
  if !has_key(s:hl_groups, a:hl_group)
    call s:init_hl_group(a:hl_group)
    let s:hl_groups[a:hl_group] = 1
  endif
endfunction

function s:existing_hl_groups() abort
  return keys(s:hl_groups)
endfunction

function s:clear_highlights(bufnr, hl_group) abort
  if !has_key(s:hl_groups, a:hl_group)
    return
  endif
  for hl_type in s:HL_TYPES
    let prop_type = printf('qfhl_%s_%s', a:hl_group, hl_type)
    call prop_remove(#{
    \   type: prop_type,
    \   bufnr: a:bufnr,
    \   all: v:true,
    \ })
  endfor
endfunction

function s:clear_updated_flag(bufnr, hl_group) abort
  let buf_scope = getbufvar(a:bufnr, '', {})
  let last_status = get(buf_scope, 'qfhl_last_status', {})
  if has_key(last_status, a:hl_group)
    call remove(last_status, a:hl_group)
  endif
endfunction

function s:on_buf_unload(bufnr) abort
  let buf_scope = getbufvar(a:bufnr, '', {})
  if has_key(buf_scope, 'qfhl_last_status')
    call remove(buf_scope, 'qfhl_last_status')
  endif
endfunction

function s:filter_locations_by_bufnr(locations, bufnr) abort
  return filter(a:locations, { _, loc -> loc.bufnr == a:bufnr })
endfunction


" auto

function s:setup_autocmd() abort
  augroup plugin-qfhl-update
    autocmd!
    autocmd BufEnter,WinEnter * ++nested QfhlUpdate
    autocmd QuickFixCmdPost * ++nested QfhlUpdateAll
  augroup END
endfunction

function s:cleanup_autocmd() abort
  autocmd! plugin-qfhl-update
  augroup! plugin-qfhl-update
endfunction

function s:init_hl_group(hl_group) abort
  for hl_type in s:HL_TYPES
    let prop_type = printf('qfhl_%s_%s', a:hl_group, hl_type)
    if empty(prop_type_get(prop_type))
      let hl_name = substitute(prop_type,
      \   '\(\a\+\)_\(\a\+\)_\(\a\+\)', '\u\1\u\2\u\3', '')
      let link_to = substitute(prop_type,
      \   '\(\a\+\)_\a\+_\(\a\+\)', '\u\1\u\2', '')
      execute printf('highlight default link %s %s', hl_name, link_to)
      call prop_type_add(prop_type, #{
      \   highlight: hl_name,
      \   priority: 10,
      \ })
    endif
  endfor
endfunction

function s:init_highlight() abort
  highlight default link QfhlError SpellBad
  highlight default link QfhlWarning SpellCap
  highlight default link QfhlInfo QfhlWarning
endfunction

augroup plugin-qfhl-highlights
  autocmd!
  autocmd ColorScheme * call s:init_highlight()
augroup END
call s:init_highlight()


augroup plugin-qfhl-buffers
  autocmd!
  autocmd BufUnload * call s:on_buf_unload(expand('<afile>'))
augroup END
