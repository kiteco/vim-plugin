let s:should_trigger_completion = 0
let s:completion_counter = 0
let s:begin = 0
let s:end = 0


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
  if wordcount().bytes > kite#max_file_size() | return | endif

  if s:should_trigger_completion
    let s:should_trigger_completion = 0
    call feedkeys("\<C-X>\<C-U>")
  endif
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


function! kite#completion#snippet(begin, end)
  let s:begin = a:begin
  let s:end = a:end
  " call kite#completion#autocomplete()
  call feedkeys("\<C-X>\<C-U>")
endfunction


function! s:findstart()
  let line = getline('.')
  let start = col('.') - 1

  let s:signature = s:before_function_call_argument(line[:start-1]) && s:begin == 0

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

  if s:signature
    let params = {
          \   'filename':     filename,
          \   'editor':       'vim',
          \   'text':         s:text,
          \   'cursor_runes': s:cursor
          \ }
  else
    let params = {
          \   'no_snippets':  (g:kite_snippets ? v:false : v:true),
          \   'filename':     filename,
          \   'editor':       'vim',
          \   'text':         s:text,
          \   'position': {
          \     'begin': (s:begin > 0 ? s:begin : s:cursor),
          \     'end':   (s:end   > 0 ? s:end   : s:cursor),
          \   },
          \   'placeholders': []
          \ }
    let s:begin = 0
    let s:end   = 0
  endif

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


  let max_hint_length = s:max_hint_length(json.completions)

  let matches = []
  for c in json.completions
    call add(matches, s:adapt(c, max_hint_length, 0))

    if has_key(c, 'children')
      for child in c.children
        call add(matches, s:adapt(child, max_hint_length, 1))
      endfor
    endif
  endfor

  if !has('patch-8.0.1493')
    let b:kite_completions = {}
    for item in filter(copy(matches), 'has_key(v:val, "user_data")')
      let b:kite_completions[item.word] = item.user_data
    endfor
  endif

  if mode(1) ==# 'i'
    call complete(a:startcol+1, matches)
  endif
endfunction


function! s:adapt(completion_option, max_hint_length, nesting)
  " By default the hint is separated from the preceding text by a single
  " space.  We want two spaces.
  let max = a:max_hint_length + 1
  let hint = ' '.s:branded_hint(a:completion_option.hint)

  " Right align.
  if strdisplaywidth(hint) < max
    let hint = repeat(' ', max - strdisplaywidth(hint)).hint
  endif

  let indent = repeat('  ', a:nesting)

  return {
        \   'word': a:completion_option.snippet.text,
        \   'abbr': indent.a:completion_option.display,
        \   'info': a:completion_option.documentation.text,
        \   'menu': hint,
        \   'equal': 1,
        \   'user_data': json_encode(a:completion_option.snippet.placeholders)
        \ }
endfunction


function! s:max_hint_length(completions)
  let max = 0

  for e in a:completions
    let len = strdisplaywidth(s:branded_hint(e.hint))
    if len > max
      let max = len
    endif

    if has_key(e, 'children')
      let len = s:max_hint_length(e.children)
      if len > max
        let max = len
      endif
    endif
  endfor

  return max
endfunction


function! s:branded_hint(text)
  return empty(a:text) ? kite#symbol() : a:text.' '.kite#symbol()
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

