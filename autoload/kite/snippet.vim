"
"  [
"    { index: 0, placeholders: { ... } },    <-- depth 0
"    { index: 0, placeholders: { ... } },    <-- depth 1
"    ...                                     <-- depth n
"  ]
"
"  index - the currently active placeholder at that depth
let b:kite_placeholder_stack = []


function! s:pop()
  return remove(b:kite_placeholder_stack, -1)
endfunction

function! s:peek()
  return get(b:kite_placeholder_stack, -1)
endfunction

function! s:push(item)
  call add(b:kite_placeholder_stack, a:item)
endfunction



function! kite#snippet#complete_done()
  if empty(v:completed_item) | return | endif

  let placeholders = json_decode(v:completed_item.user_data)

  " if completion does not contain placeholders and we have just completed a placeholder
  if empty(placeholders) && !empty(b:kite_placeholder_stack)
    call kite#snippet#next_placeholder()
    return
  endif

  let b:kite_linenr = line('.')

  call s:push({'placeholders': placeholders, 'index': 0})

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


" Go to next placeholder at current level, if there is one, or first placeholder at next level otherwise.
function! kite#snippet#next_placeholder()
  " if !exists('b:kite_placeholder_stack') | return | endif

  call s:update_placeholder_locations()

  call s:placeholder(s:peek().index + 1)
endfunction



function! kite#snippet#previous_placeholder()
  " if !exists('b:kite_placeholder_stack') | return | endif

  call s:placeholder(s:peek().index - 1)
endfunction


" Move to the placeholder at index and select its text.
function! s:placeholder(index)
  " if empty('b:kite_placeholder_stack') | return | endif

  let index = a:index

  " FIXME if another level in stack, go to that one
  if index < 0
    let index = 0
  endif

  let level = s:peek()
  let placeholders = level.placeholders

  " if navigating forward from last placeholder of current level
  if index == len(placeholders)
    call s:pop()
    if empty(b:kite_placeholder_stack)
      call s:goto_initial_completion_end()
    else
      " we have moved to next level where the index is the placeholder we have
      " just done; so go to subsequent index.
      call s:placeholder(s:peek().index + 1)
    endif
    return
  endif

  call s:clear_all_placeholder_highlights()
  call s:highlight_current_level_placeholders()

  let level.index = index
  let ph = placeholders[index]
  echom 'ph ' string(ph)

  " debug
  let i = 0
  for level in b:kite_placeholder_stack
    echom 'level' i
    echom '  index' level.index
    for pholder in level.placeholders
      echom '  '.string(pholder)
    endfor
    let i += 1
  endfor

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


function! s:goto_initial_completion_end()
  " FIXME
  call setpos('.', [0, b:kite_linenr, b:kite_insertion_end + col('$') - b:kite_line_length - 1])
  call feedkeys('a')
  call s:teardown()
endfunction


" Adjust current and subsequent placeholders for the amount of text entered
" at the placeholder we are leaving.
function! s:update_placeholder_locations()
  if !exists('b:kite_line_length') | return | endif

  let line_length_delta = col('$') - b:kite_line_length

  " current placeholder
  let ph = s:peek().placeholders[s:peek().index]
  let ph.end += line_length_delta
  let marker = ph.end

  " subsequent placeholders at current level
  for ph in s:peek().placeholders[s:peek().index+1:]
    let ph.col_begin += line_length_delta
  endfor

  " placeholders at outer levels
  for level in b:kite_placeholder_stack[:-2]
    for ph in level.placeholders
      if ph.col_begin > marker
        let ph.col_begin += line_length_delta
      endif
    endfor
  endfor

  let b:kite_line_length = col('$')
endfunction


function! s:highlight_current_level_placeholders()
  let linenr = line('.')
  for ph in s:peek().placeholders
    let ph.matchid = matchaddpos('Underlined', [[linenr, ph.col_begin, ph.end - ph.begin]])
  endfor
endfunction


function! s:clear_all_placeholder_highlights()
  for level in b:kite_placeholder_stack
    for ph in level.placeholders
      if has_key(ph, 'matchid')
        call matchdelete(ph.matchid)
        unlet ph.matchid
      endif
    endfor
  endfor
endfunction


function! s:setup_maps()
  echom 'setup maps'
  " FIXME don't do anything when pumvisible()
  "
  " when pumvisble(), and the selection has been changed with ctrl-n / ctrl-p,
  " the mapping is interpreted differently - the rhs is written in literally
  " but it is written in the correct place, i.e. it does execute the command

  " execute 'inoremap <buffer> <silent>' g:kite_next_placeholder     '<C-\><C-O>:set nonumber<CR>'
  " execute 'inoremap <buffer> <silent>' g:kite_next_placeholder     '<C-\><C-O>:if !pumvisible()<bar>call kite#snippet#next_placeholder()<bar>endif<CR>'
  " execute 'inoremap <buffer> <silent>' g:kite_next_placeholder     '<C-R>=pumvisible() ? "" : call kite#snippet#next_placeholder()<CR>'
  "
  execute 'inoremap <buffer> <silent>' g:kite_next_placeholder     '<C-\><C-O>:silent call kite#snippet#next_placeholder()<CR>'
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
  echom 'teardown maps'
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
          \ call s:clear_all_placeholder_highlights() |
          \ call s:highlight_current_level_placeholders()
    autocmd CursorMoved,CursorMovedI <buffer> call s:cursormoved()
    autocmd InsertLeave              <buffer> call s:insertleave()
  augroup END
endfunction


function! s:teardown_autocmds()
  autocmd! KiteSnippets * <buffer>
endfunction


function! s:teardown()
  call s:clear_all_placeholder_highlights()
  call s:teardown_maps()
  call s:teardown_autocmds()
  call s:restore_smaps()
  call s:pop()  " must come after s:clear_placeholder_highlights()
  unlet! b:kite_linenr b:kite_line_length b:kite_insertion_end
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
