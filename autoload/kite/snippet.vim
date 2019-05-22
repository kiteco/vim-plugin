function! kite#snippet#complete_done()
  if empty(v:completed_item) | return | endif

  " If we have just completed a placeholder (as opposed to a 'top level'
  " completion) move to the next placeholder.
  if exists('b:kite_placeholders') && !empty(b:kite_placeholders)
    return kite#snippet#next_placeholder()
  endif

  let placeholders = sort(json_decode(v:completed_item.user_data), {x,y -> x.begin - y.begin})
  let b:kite_placeholders = placeholders

  if empty(placeholders) | return | endif

  " Calculate column number of start of each placeholder.
  let inserted_text = v:completed_item.word
  let insertion_start = col('.') - strdisplaywidth(inserted_text)

  for ph in placeholders
    let ph.col_begin = insertion_start + ph.begin
  endfor

  " Highlight placeholders.
  call clearmatches()
  for ph in placeholders
    call matchaddpos('Underlined', [[linenr, ph.col_begin, ph.end - ph.begin]])
  endfor

  " Move to first placeholder.
  call s:placeholder(0)
endfunction



function! kite#snippet#next_placeholder()
  if !exists('b:kite_placeholders')       | return | endif
  if !exists('b:kite_placeholder_index')  | return | endif

  " Adjust current and subsequent placeholders for the amount of text entered
  " at the placeholder we are leaving.

  let line_length_delta = col('$') - b:kite_line_length

  " current placeholder
  let ph = b:kite_placeholders[b:kite_placeholder_index]
  let ph.end += line_length_delta

  " subsequent placeholders
  for ph in b:kite_placeholders[b:kite_placeholder_index+1:]
    let ph.col_begin += line_length_delta
  endfor

  call s:placeholder(b:kite_placeholder_index + 1)
endfunction



function! kite#snippet#previous_placeholder()
  if !exists('b:kite_placeholders')       | return | endif
  if !exists('b:kite_placeholder_index')  | return | endif

  call s:placeholder(b:kite_placeholder_index - 1)
endfunction



function! s:placeholder(index)
  if !exists('b:kite_placeholders') | return | endif
  if a:index < 0 || a:index >= len(b:kite_placeholders) | return | endif

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
