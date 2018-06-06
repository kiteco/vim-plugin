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

    let s:pending += 1
    call timer_start(0, function('kite#completion#get'))
  endif
endfunction


function! kite#completion#get(_timer)
  let cursor = kite#utils#character_offset()
  let text = kite#utils#buffer_contents()
  if strlen(text) > kite#max_file_size() | return | endif

  let line = getline('.')
  let s:start = col('.') - 1

  let signature = s:before_function_call_argument(line[:s:start-1])

  if !signature
    while s:start > 0 && line[s:start - 1] =~ '\w'
      let s:start -= 1
    endwhile
  endif

  let filename = kite#utils#filepath(0)

  let params = {
        \   'filename':     filename,
        \   'editor':       'vim',
        \   'text':         text,
        \   'cursor_runes': cursor
        \ }

  let json = json_encode(params)

  if s:pending > 1
    let s:pending -= 1
    return
  endif

  if signature
    let s:completions = kite#client#signatures(json, function('kite#signature#handler'))
  else
    let s:completions = kite#client#completions(json, function('kite#completion#handler'))
  endif

  if s:pending > 1
    let s:pending -= 1
    return
  endif

  call kite#utils#log('go for complete '.s:start.' // '.len(s:completions))

  let s:pending -= 1
  call feedkeys("\<C-X>\<C-U>")
endfunction


function! kite#completion#backspace()
  let s:should_trigger_completion = 1
  return "\<BS>"
endfunction


" NOTE: remember manual invocation calls this method.
function! kite#completion#complete(findstart, base)
  if a:findstart
    return s:start

  else
    return s:completions
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

