let s:should_trigger_completion = 0
let s:completion_counter = 0


function! kite#completion#insertcharpre()
  let s:should_trigger_completion = 1

  " Trigger a fresh completion after every keystroke when the popup menu
  " is visible (by calling the function which TextChangedI would call
  " (TextChangedI is not triggered when the popup menu is visible)).
  if pumvisible()
    call kite#utils#log('# Trigger autocomplete because of pumvisible(): '.v:char)
    call kite#completion#autocomplete()
  endif
endfunction


function! kite#completion#popup_exit(key)
  if pumvisible()
    let s:should_trigger_completion = 0
  endif
  return a:key
endfunction


function! kite#completion#autocomplete()
  if !g:kite_auto_complete | return | endif
  if exists('b:kite_skip') && b:kite_skip | return | endif

  if s:should_trigger_completion
    let s:should_trigger_completion = 0
    call feedkeys("\<C-X>\<C-U>")
  endif
endfunction


function! kite#completion#backspace()
  let s:should_trigger_completion = 1
  return "\<BS>"
endfunction


" Manual invocation calls this method.
function! kite#completion#complete(findstart, base)
  if a:findstart
    " Store the buffer contents and cursor position here because when Vim
    " calls this function the second time (with a:findstart == 0) Vim has
    " already deleted the text between `start` and the cursor position.
    let s:cursor = kite#utils#character_offset()
    let s:text = kite#utils#buffer_contents()

    let s:startcol = s:findstart()
    return s:startcol
  else
    " Leave CTRL-X submode so user can invoke other completion methods.
    call feedkeys("\<C-e>")
    call s:get_completions()
    return []
  endif
endfunction


function! s:findstart()
  let line = getline('.')
  let start = col('.') - 1

  let s:signature = s:before_function_call_argument(line[:start-1])

  if !s:signature
    while start > 0 && line[start - 1] =~ '\w'
      let start -= 1
    endwhile
  endif

  return start
endfunction


function! s:get_completions()
  if s:signature
    call kite#signature#increment_completion_counter()
  else
    let s:completion_counter = s:completion_counter + 1
  endif

  let filename = kite#utils#filepath(0)

  let params = {
        \   'filename':     filename,
        \   'editor':       'vim',
        \   'text':         s:text,
        \   'cursor_runes': s:cursor
        \ }

  let json = json_encode(params)

  if s:signature
    call kite#client#signatures(json, function('kite#signature#handler', [kite#signature#completion_counter(), s:startcol]))
  else
    call kite#client#completions(json, function('kite#completion#handler', [s:completion_counter, s:startcol]))
  endif
endfunction


function! kite#completion#handler(counter, startcol, response) abort
  call kite#utils#log('completion: '.a:response.status)

  " Ignore old completion results.
  if a:counter != s:completion_counter
    return
  endif

  if a:response.status != 200
    return
  endif

  " This should not happen but evidently it sometimes does (#107).
  if empty(a:response.body)
    return
  endif

  let json = json_decode(a:response.body)

  " API should return 404 status when no completions but it sometimes
  " return 200 status and an empty response body, or "completions":"null".
  if empty(json) || type(json.completions) != v:t_list
    return
  endif

  let matches = map(json.completions, {_, c ->
        \   {
        \     'word': c.insert,
        \     'abbr': c.display,
        \     'info': c.documentation_text,
        \     'menu': (kite#utils#present(c, 'symbol') && kite#utils#present(c.symbol, 'value') ? c.symbol.value[0].kind : '')
        \   }
        \ })
  call complete(a:startcol+1, matches)
endfunction


" Returns truthy if the cursor is:
"
" - just after an open parenthesis; or
" - just after a comma inside a function call; or
" - just after an equals sign inside a function call.
"
" Note this differs from all the other editor plugins.  They can all show both
" a signature popup and a completions popup at the same time, whereas Vim can
" only show one popup.  Therefore we need to switch its purpose between
" signature info and completions info at appropriate points inside a function
" call's arguments.
"
" line - the line up to the cursor position
function! s:before_function_call_argument(line)
  " Other editors basically do this:
  " return a:line =~ '\v[(][^)]*$'

  return a:line =~ '\v[(]([^)]+[=,])?\s*$'
endfunction

