function! kite#snippet#complete_done()
  if empty(v:completed_item)
    return
  endif

  " Ensure sorted
  let placeholders = sort(json_decode(v:completed_item.user_data), {x,y -> x.begin - y.begin})

  echo len(placeholders) . ' placeholder(s)'

  if empty(placeholders)
    return
  endif

  if exists('b:kite_placeholders') && !empty(b:kite_placeholders)
    " Avoid nesting for now.
    return
  endif


  let b:kite_placeholders = placeholders


  " The entire signature is inserted.
  let inserted_text = v:completed_item.word
  let w = strdisplaywidth(inserted_text)  " todo maybe use characters / bytes?
  " start of inserted text
  let insertion_start = col('.') - w


  call clearmatches()

  for ph in placeholders
    let ph.col_begin = insertion_start + ph.begin
  endfor

  for ph in placeholders
    call matchaddpos('Underlined', [[line('.'), ph.col_begin, ph.end - ph.begin]])
  endfor
  " call matchaddpos('Underlined', map(copy(placeholders), {_,ph -> [line('.'), insertion_start + ph.begin, ph.end - ph.begin]}))



  " " now trigger (non-signature) completion for placeholder
  " " to do this i think we need to delete the placeholder first
  " execute 'normal! '.offset.'h'
  " execute 'normal!'.(placeholders[0].end - placeholders[0].begin).'x'

  " " now trigger (non-signature) completion for placeholder
  " " with placeholder range
  " call kite#completion#snippet(placeholders[0].begin, placeholders[0].end)
endfunction



" moves to next placholder and selects it
function! kite#snippet#next_placeholder()
  let col = col('v')
  for i in range(len(b:kite_placeholders))
    let ph = b:kite_placeholders[i]
    if ph.col_begin > col
      call s:placeholder(i)
      return
    endif
  endfor
endfunction



function! kite#snippet#previous_placeholder()
  let col = col('v')
  for i in range(len(b:kite_placeholders) - 1, 0, -1)
    let ph = b:kite_placeholders[i]
    if ph.col_begin < col
      call s:placeholder(i)
      return
    endif
  endfor
endfunction



function! s:placeholder(i)
  let ph = b:kite_placeholders[a:i]

  call setpos("'<", [0, line('.'), ph.col_begin])
  call setpos("'>", [0, line('.'), ph.col_begin + ph.end - ph.begin - 1])
  " change to select mode
  " execute "normal! gv\<c-g>"
  normal! gv
endfunction
