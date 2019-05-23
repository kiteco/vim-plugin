function! kite#snippet#complete_done()
  if empty(v:completed_item) | return | endif

  " If we have just completed a placeholder (as opposed to a 'top level'
  " completion) move to the next placeholder.
  if exists('b:kite_placeholders') && !empty(b:kite_placeholders)
    return kite#snippet#next_placeholder()
  endif

  let placeholders = sort(json_decode(v:completed_item.user_data), {x,y -> x.begin - y.begin})
  let b:kite_placeholders = placeholders
  let b:kite_linenr = line('.')

  if empty(placeholders) | return | endif

  call s:setup_maps()
  call s:setup_autocmds()

  " Calculate column number of start of each placeholder.
  let inserted_text = v:completed_item.word
  let insertion_start = col('.') - strdisplaywidth(inserted_text)

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
  if a:index < 0 || a:index >= len(b:kite_placeholders) | return | endif

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
  inoremap <buffer> <silent> <c-j> <c-\><c-o>:call kite#snippet#next_placeholder()<cr>
  inoremap <buffer> <silent> <c-k> <c-\><c-o>:call kite#snippet#previous_placeholder()<cr>
  snoremap <buffer> <silent> <c-j> <esc>:call kite#snippet#next_placeholder()<cr>
  snoremap <buffer> <silent> <c-k> <esc>:call kite#snippet#previous_placeholder()<cr>

  " snoremap <silent> <bs> <c-g>c
  " snoremap <silent> <del> <c-g>c
  " snoremap <silent> <c-h> <c-g>c
  " snoremap <silent> <c-r> <c-g>"_c<c-r>
endfunction


function! s:teardowm_maps()
  iunmap <buffer> <c-j>
  iunmap <buffer> <c-k>
  sunmap <buffer> <c-j>
  sunmap <buffer> <c-k>
endfunction


function! s:setup_autocmds()
  augroup KiteSnippets
    autocmd! * <buffer>

    autocmd CursorMovedI <buffer> call s:update_placeholder_locations() | call s:clear_placeholder_highlights() | call s:highlight_placeholders()
    " TODO use <SID>?
    autocmd CursorMoved,CursorMovedI <buffer> call kite#snippet#cursormoved()
    " TODO use <SID>?
    autocmd InsertLeave <buffer> call kite#snippet#insertleave()
  augroup END
endfunction


function! s:teardown_autocmds()
  autocmd! KiteSnippets * <buffer>
endfunction


function! s:teardown()
  call s:clear_placeholder_highlights()
  call s:teardowm_maps()
  call s:teardown_autocmds()
  unlet! b:kite_linenr b:kite_line_length b:kite_placeholder_index b:kite_placeholders
endfunction


function! kite#snippet#cursormoved()
  if !exists('b:kite_linenr') | return | endif
  if b:kite_linenr == line('.') | return | endif

  call s:teardown()
endfunction


function! kite#snippet#insertleave()
  " Modes established by experimentation.
  if mode(1) !=# 's' && mode(1) !=# 'niI'
    call s:teardown()
  endif
endfunction
