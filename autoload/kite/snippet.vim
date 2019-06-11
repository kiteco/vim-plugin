function! kite#snippet#complete_done()
  if empty(v:completed_item) | return | endif

  " If we have just completed a placeholder (as opposed to a 'top level'
  " completion) move to the next placeholder.
  if exists('b:kite_placeholders') && !empty(b:kite_placeholders)
    return kite#snippet#next_placeholder()
  endif

  let placeholders = json_decode(v:completed_item.user_data)
  let b:kite_placeholders = placeholders
  let b:kite_linenr = line('.')

  if empty(placeholders) | return | endif

  call s:setup_maps()
  call s:setup_autocmds()

  " Calculate column number of start of each placeholder.
  let inserted_text = v:completed_item.word
  let insertion_start = col('.') - strdisplaywidth(inserted_text)
  let b:kite_insertion_end = col('.')

  for ph in placeholders
    let ph.col_begin = insertion_start + ph.begin
  endfor

  " Move to first placeholder.
  call s:placeholder(0)
endfunction



function! kite#snippet#next_placeholder()
  if !exists('b:kite_placeholders')       | return | endif
  if !exists('b:kite_placeholder_index')  | return | endif

  call s:update_placeholder_locations()

  call s:placeholder(b:kite_placeholder_index + 1)
endfunction



function! kite#snippet#previous_placeholder()
  if !exists('b:kite_placeholders')       | return | endif
  if !exists('b:kite_placeholder_index')  | return | endif

  call s:placeholder(b:kite_placeholder_index - 1)
endfunction


" Move to the placeholder at index and select its text.
function! s:placeholder(index)
  if !exists('b:kite_placeholders') | return | endif

  if a:index < 0 | return | endif

  if a:index == len(b:kite_placeholders)
    " go to end of original completion
    call setpos('.', [0, b:kite_linenr, b:kite_insertion_end + col('$') - b:kite_line_length - 1])
    call feedkeys('a')
    call s:teardown()
    return
  endif

  call s:clear_placeholder_highlights()
  call s:highlight_placeholders()

  let b:kite_placeholder_index = a:index
  let ph = b:kite_placeholders[a:index]

  " store line length before placeholder gets changed by user
  let b:kite_line_length = col('$')

  " insert mode -> normal mode
  stopinsert

  let linenr = line('.')
  call setpos("'<", [0, linenr, ph.col_begin])
  call setpos("'>", [0, linenr, ph.col_begin + ph.end - ph.begin - (mode() == 'n' ? 1 : 0)])
  " normal mode -> visual mode -> select mode
  execute "normal! gv\<c-g>"
endfunction


" Adjust current and subsequent placeholders for the amount of text entered
" at the placeholder we are leaving.
function! s:update_placeholder_locations()
  if !exists('b:kite_line_length') | return | endif

  let line_length_delta = col('$') - b:kite_line_length

  " current placeholder
  let ph = b:kite_placeholders[b:kite_placeholder_index]
  let ph.end += line_length_delta

  " subsequent placeholders
  for ph in b:kite_placeholders[b:kite_placeholder_index+1:]
    let ph.col_begin += line_length_delta
  endfor

  let b:kite_line_length = col('$')
endfunction


function! s:highlight_placeholders()
  let linenr = line('.')
  for ph in b:kite_placeholders
    let ph.matchid = matchaddpos('Underlined', [[linenr, ph.col_begin, ph.end - ph.begin]])
  endfor
endfunction


function! s:clear_placeholder_highlights()
  for ph in b:kite_placeholders
    if has_key(ph, 'matchid')
      call matchdelete(ph.matchid)
    endif
  endfor
endfunction


function! s:setup_maps()
  execute 'inoremap <buffer> <silent>' g:kite_next_placeholder     '<C-\><C-O>:call kite#snippet#next_placeholder()<CR>'
  execute 'inoremap <buffer> <silent>' g:kite_previous_placeholder '<C-\><C-O>:call kite#snippet#previous_placeholder()<CR>'
  execute 'snoremap <buffer> <silent>' g:kite_next_placeholder     '<Esc>:call kite#snippet#next_placeholder()<CR>'
  execute 'snoremap <buffer> <silent>' g:kite_previous_placeholder '<Esc>:call kite#snippet#previous_placeholder()<CR>'

  call s:remove_smaps_for_printable_characters()
endfunction


" Many plugins use vmap for visual-mode mappings but vmap maps both
" visual-mode and select-mode (they should use xmap instead).  Assume any
" visual-mode mappings for printable characters are not wanted and remove them
" (but remember them so we can restore them afterwards).  Similarly for map.
" Assume any select-only-mode maps are deliberate.
"
" :help mapmode-s
" :help Select-mode-mapping
function! s:remove_smaps_for_printable_characters()
  let b:kite_maps = []
  let printable_keycodes = [
        \ '<Space>',
        \ '<Bslash>',
        \ '<Tab>',
        \ '<C-Tab>',
        \ '<NL>',
        \ '<CR>',
        \ '<BS>',
        \ '<Leader>',
        \ '<LocalLeader>'
        \ ]

  " Get a list of maps active in select mode.
  for scope in ['<buffer>', '']
    redir => maps | silent execute 'smap' scope | redir END

    let mappings = split(maps, "\n")

    " 'No mapping found' or localised equivalent (starts with capital letter).
    if len(mappings) == 1 && mappings[0][0] =~ '\u' | continue | endif

    " Assume select-mode maps are deliberate and ignore them.
    call filter(mappings, 'v:val[0:2] !~# "s"')

    for mapping in mappings
      let lhs = matchlist(mapping, '\v^...(\S+)\s.*')[1]
      "                                ^^^ ^^^
      "                               mode lhs

      " Ignore keycodes for non-printable characters, e.g. <Left>
      if lhs[0] == '<' && index(printable_keycodes, lhs) == -1 | continue | endif

      " Remember the mapping so we can restore it later.
      call add(b:kite_maps, maparg(lhs, 's', 0, 1))

      " Remove the mapping.
      silent! execute 'sunmap' scope lhs
    endfor
  endfor
endfunction


function! s:restore_smaps()
  for mapping in b:kite_maps
    silent! execute mapping.mode . (mapping.noremap ? 'nore' : '') . 'map '
          \ . (mapping.buffer  ? '<buffer> ' : '')
          \ . (mapping.expr    ? '<expr> '   : '')
          \ . (mapping.nowait  ? '<nowait> ' : '')
          \ . (mapping.silent  ? '<silent> ' : '')
          \ . mapping.lhs . ' '
          \ . substitute(mapping.rhs, '<SID>', '<SNR>'.mapping.sid.'_', 'g')
  endfor

  unlet! b:kite_maps
endfunction


function! s:teardown_maps()
  iunmap <buffer> <C-J>
  iunmap <buffer> <C-K>
  sunmap <buffer> <C-J>
  sunmap <buffer> <C-K>
endfunction


function! s:setup_autocmds()
  augroup KiteSnippets
    autocmd! * <buffer>

    autocmd CursorMovedI <buffer>
          \ call s:update_placeholder_locations() |
          \ call s:clear_placeholder_highlights() |
          \ call s:highlight_placeholders()
    autocmd CursorMoved,CursorMovedI <buffer> call s:cursormoved()
    autocmd InsertLeave              <buffer> call s:insertleave()
  augroup END
endfunction


function! s:teardown_autocmds()
  autocmd! KiteSnippets * <buffer>
endfunction


function! s:teardown()
  call s:clear_placeholder_highlights()
  call s:teardown_maps()
  call s:teardown_autocmds()
  call s:restore_smaps()
  unlet! b:kite_linenr b:kite_line_length b:kite_placeholder_index b:kite_placeholders b:kite_insertion_end
endfunction


function! s:cursormoved()
  if !exists('b:kite_linenr') | return | endif
  if b:kite_linenr == line('.') | return | endif

  call s:teardown()
endfunction


function! s:insertleave()
  " Modes established by experimentation.
  if mode(1) !=# 's' && mode(1) !=# 'niI'
    call s:teardown()
  endif
endfunction
