let s:should_trigger_completion = 0


function! kite#completion#insertcharpre()
  let s:should_trigger_completion = (v:char =~# '\m\S')
endfunction


function! kite#completion#popup_exit(key)
  if pumvisible()
    let s:should_trigger_completion = 0
  endif
  return a:key
endfunction


function! kite#completion#autocomplete()
  if !g:kite_auto_complete | return | endif

  if s:should_trigger_completion
    let s:should_trigger_completion = 0
    call feedkeys("\<C-X>\<C-U>")
  endif
endfunction


function! kite#completion#complete(findstart, base)
  if a:findstart
    " Store the buffer contents and cursor position here because when Vim
    " calls this function the second time (with a:findstart == 0) Vim has
    " already deleted the text between `start` and the cursor position.
    let s:cursor = kite#utils#character_offset()
    let s:text = kite#utils#buffer_contents()
    if strlen(s:text) > kite#max_file_size() | return -3 | endif

    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~ '\w'
      let start -= 1
    endwhile
    return start

  else
    let filename = resolve(expand('%:p'))
    let [text, cursor] = [s:text, s:cursor]
    unlet s:text s:cursor

    let json = json_encode({
          \   'filename':     filename,
          \   'text':         text,
          \   'cursor_runes': cursor
          \ })

    return kite#client#completions(json, function('kite#completion#handler'))
  endif
endfunction


function! kite#completion#handler(response) abort
  if a:response.status != 200
    " echo a:response.status
    return []
  endif

  let json = json_decode(a:response.body)

  " API should return 404 status when no completions but it sometimes
  " return 200 status and "completions":"null".
  if type(json.completions) == v:t_list
    return map(json.completions, {_, c ->
          \   {
          \     'word': c.insert,
          \     'abbr': c.display,
          \     'info': c.documentation_text,
          \     'menu': c.hint
          \   }
          \ })
  else
    return []
  endif
endfunction

