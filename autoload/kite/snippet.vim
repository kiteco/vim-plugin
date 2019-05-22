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
  let linenr = line('.')

  for ph in placeholders
    let ph.col_begin = insertion_start + ph.begin
  endfor

  " let i = 0
  for ph in placeholders
    " match by location (doesn't move when text moves)
    " call matchaddpos('Underlined', [[linenr, ph.col_begin, ph.end - ph.begin]])

    " marks update automatically when the text changes - but only the line
    " number, not the column :(
    " let letter = nr2char(char2nr('a') + i)
    " call setpos("'".letter, [0, linenr, ph.col_begin])
    " let i += 1

    " match by regex (moves with text)
    let placeholder_text = strcharpart(inserted_text, ph.begin, ph.end - ph.begin)
    let ph.text = placeholder_text
    call matchadd('Underlined', '\V\%'.linenr.'l'.escape(placeholder_text, '\'))

    " or perhaps think of placeholders as holes in the overall completion
    " then navigate between the non-hole parts?
  endfor



  " once a placeholder has been filled in, do we need to be able to navigate
  " to it?


  normal! ^
  let b:kite_placeholder = -1
  call kite#snippet#next_placeholder()



  " " now trigger (non-signature) completion for placeholder
  " " to do this i think we need to delete the placeholder first
  " execute 'normal! '.offset.'h'
  " execute 'normal!'.(placeholders[0].end - placeholders[0].begin).'x'

  " " now trigger (non-signature) completion for placeholder
  " " with placeholder range
  " call kite#completion#snippet(placeholders[0].begin, placeholders[0].end)
endfunction



"
" maybe keep track of current placeholder; then we can just go the next
"
" if we are moving via regex, what do we do when two placeholders have same
" regex e.g. "..." - how do we know which one we are on?
"
" use search() for regex-based navigation
"
"
" moves to next placholder and selects it
function! kite#snippet#next_placeholder()
  if !exists('b:kite_placeholders') | return | endif
  if !exists('b:kite_placeholder')  | return | endif

  " let col = col('v')
  " for i in range(len(b:kite_placeholders))
  "   let ph = b:kite_placeholders[i]
  "   if ph.col_begin > col
  "     call s:placeholder(i)
  "     return
  "   endif
  " endfor

  " echom b:kite_placeholder
  if b:kite_placeholder == len(b:kite_placeholders) - 1
    return
  endif

  let b:kite_placeholder += 1
  call s:placeholder(b:kite_placeholder, 1)
endfunction




function! kite#snippet#previous_placeholder()
  if !exists('b:kite_placeholders') | return | endif
  if !exists('b:kite_placeholder')  | return | endif

  " let col = col('v')
  " for i in range(len(b:kite_placeholders) - 1, 0, -1)
  "   let ph = b:kite_placeholders[i]
  "   if ph.col_begin < col
  "     call s:placeholder(i)
  "     return
  "   endif
  " endfor

  " echom b:kite_placeholder
  if b:kite_placeholder == 0
    return
  endif

  let b:kite_placeholder -= 1
  call s:placeholder(b:kite_placeholder, -1)
endfunction



function! s:placeholder(i, dir)
  if !exists('b:kite_placeholders') | return | endif

  let ph = b:kite_placeholders[a:i]

  " call setpos("'<", [0, line('.'), ph.col_begin])
  " call setpos("'>", [0, line('.'), ph.col_begin + ph.end - ph.begin - 1])
  " " change to select mode
  " " execute "normal! gv\<c-g>"
  " normal! gv

  let result = search('\V\%'.line('.').'l'.escape(ph.text, '\'), (a:dir == -1 ? 'b' : '').'z', line('.'))
  " if result == 0
  "   if a:dir == -1
  "     call kite#snippet#previous_placeholder()
  "   else
  "     call kite#snippet#next_placeholder()
  "   endif
  " endif
endfunction
