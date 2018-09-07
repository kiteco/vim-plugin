let s:should_trigger_completion = 0
let s:pending = 0


function! kite#completion#insertcharpre()
  let s:should_trigger_completion = 0

  if v:char =~# '\S'
    let s:should_trigger_completion = 1
  else
    " Also trigger completion after a space inside fn call.
    let line = getline('.').v:char
    let start = col('.') - 1
    if s:before_function_call_argument(line[:start-1])
      let s:should_trigger_completion = 1
    endif
  endif

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
  if b:kite_skip | return | endif

  if s:should_trigger_completion
    let s:should_trigger_completion = 0

    call timer_start(0, function('s:invoke_complete'))
  endif
endfunction

function! s:invoke_complete(_timer)
  call feedkeys("\<C-X>\<C-U>")
endfunction


function! kite#completion#backspace()
  let s:should_trigger_completion = 1
  return "\<BS>"
endfunction


" NOTE: remember manual invocation calls this method.
function! kite#completion#complete(findstart, base)
  if a:findstart
    let s:pending += 1

    " Store the buffer contents and cursor position here because when Vim
    " calls this function the second time (with a:findstart == 0) Vim has
    " already deleted the text between `start` and the cursor position.
    let s:cursor = kite#utils#character_offset()
    let s:text = kite#utils#buffer_contents()

    return s:findstart()

  else
    let completions = s:get_completions()
    let s:pending -= 1
    return completions
  endif
endfunction


" sets s:signature
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


" depends on s:signature, s:text, s:cursor
function! s:get_completions()
  let filename = kite#utils#filepath(0)

  let params = {
        \   'filename':     filename,
        \   'editor':       'vim',
        \   'text':         s:text,
        \   'cursor_runes': s:cursor
        \ }

  let json = json_encode(params)

  " Discard this completion request if one is already pending
  " (remembering this request is already counted in s:pending).
  " Ideally we would discard the pending one in favour of this
  " but I do not know how to do that.
  if s:pending > 1
    return []
  endif

  if s:signature
    return kite#client#signatures(json, function('kite#signature#handler'))
  else
    return kite#client#completions(json, function('kite#completion#handler'))
  endif
endfunction


function! kite#completion#handler(response) abort
  call kite#utils#log('completion: '.a:response.status)
  if a:response.status != 200
    return []
  endif

  " This should not happen but evidently it sometimes does (#107).
  if empty(a:response.body)
    return []
  endif

  let json = json_decode(a:response.body)

  " API should return 404 status when no completions but it sometimes
  " return 200 status and an empty response body, or "completions":"null".
  if empty(json) || type(json.completions) != v:t_list
    return []
  endif

  return map(json.completions, {_, c ->
        \   {
        \     'word': c.insert,
        \     'abbr': c.display,
        \     'info': c.documentation_text,
        \     'menu': (kite#utils#present(c, 'symbol') && kite#utils#present(c.symbol, 'value') ? c.symbol.value[0].kind : '')
        \   }
        \ })
endfunction


" Returns truthy if the cursor is:
"
" - just after an open parenthesis; or
" - just after a comma inside a function call; or
" - just after an equals sign inside a function call.
"
" line - the line up to the cursor position
function! s:before_function_call_argument(line)
  return a:line =~ '\v[(]([^)]+[=,])?\s*$'
endfunction

