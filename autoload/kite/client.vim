let s:port               = 46624
let s:channel_base       = 'localhost:'.s:port
let s:base_url           = 'http://127.0.0.1:'.s:port
let s:editor_path        = '/clientapi/editor'
let s:hover_path         = '/api/buffer/vim'
let s:example_path       = '/api/python/curation'
let s:webapp_path        = '/clientapi/desktoplogin?d ='
let s:status_path        = '/clientapi/status?filename='
let s:user_path          = '/clientapi/user'
let s:plan_path          = '/clientapi/plan'
let s:copilot_path       = 'kite://home'
let s:counter_path       = '/clientapi/metrics/counters'
let s:symbol_report_path = '/api/editor/symbol'
let s:segment_path       = 'https://api.segment.io/v1/track'
let s:permissions_path   = 'kite://settings/permissions'


function! kite#client#settings()
  if kite#utils#windows()
    let cmd = 'start "" "'.s:settings_path.'"'
  else
    let cmd = 'open "'.s:settings_path.'"'
  endif
  silent call system(cmd)
endfunction


function! kite#client#permissions()
  if kite#utils#windows()
    let cmd = 'start "" "'.s:permissions_path.'"'
  else
    let cmd = 'open "'.s:permissions_path.'"'
  endif
  silent call system(cmd)
endfunction


function! kite#client#copilot()
  if kite#utils#windows()
    let cmd = 'start "" "'.s:copilot_path.'"'
  else
    let cmd = 'open "'.s:copilot_path.'"'
  endif
  silent call system(cmd)
endfunction


function! kite#client#counter(json, handler)
  let path = s:counter_path
  if has('channel')
    call s:async(function('s:timer_post', [path, g:kite_long_timeout, a:json, a:handler]))
  else
    call kite#async#execute(s:external_http(s:base_url.path, g:kite_long_timeout, a:json), a:handler)
  endif
endfunction


function! kite#client#logged_in(handler)
  let path = s:user_path
  if has('channel')
    let response = s:internal_http(path, g:kite_short_timeout)
  else
    let response = s:external_http(s:base_url.path, g:kite_short_timeout)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#status(filename, handler)
  let path = s:status_path.kite#utils#url_encode(a:filename)
  if has('channel')
    let response = s:internal_http(path, g:kite_short_timeout)
  else
    let response = s:external_http(s:base_url.path, g:kite_short_timeout)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#plan(handler)
  let path = s:plan_path
  if has('channel')
    let response = s:internal_http(path, g:kite_short_timeout)
  else
    let response = s:external_http(s:base_url.path, g:kite_short_timeout)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#webapp_link(id)
  call kite#utils#browse(s:base_url.s:webapp_path.kite#utils#url_encode('/docs/'.a:id))
endfunction


function! kite#client#example(id, handler)
  let path = s:example_path.'/'.a:id
  if has('channel')
    let response = s:internal_http(path, g:kite_long_timeout)
  else
    let response = s:external_http(s:base_url.path, g:kite_long_timeout)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#hover(filename, hash, cursor, handler)
  call s:wait_for_pending_events()

  let path = s:hover_path.'/'.a:filename.'/'.a:hash.'/hover?cursor_runes='.a:cursor
  if has('channel')
    call s:async(function('s:timer_get', [path, g:kite_long_timeout, a:handler]))
  else
    call kite#async#execute(s:external_http_cmd(s:base_url.path, g:kite_long_timeout),
          \ function('s:parse_and_handle', [a:handler]))
  endif
endfunction


function! kite#client#symbol_report(id, handler)
  let path = s:symbol_report_path.'/'.a:id
  if has('channel')
    call s:async(function('s:timer_get', [path, g:kite_long_timeout, a:handler]))
  else
    call kite#async#execute(s:external_http_cmd(s:base_url.path, g:kite_long_timeout),
          \ function('s:parse_and_handle', [a:handler]))
  endif
endfunction


function! kite#client#signatures(json, handler)
  call s:wait_for_pending_events()

  let path = s:editor_path.'/signatures'
  if has('channel')
    let response = s:internal_http(path, g:kite_long_timeout, a:json)
  else
    let response = s:external_http(s:base_url.path, g:kite_long_timeout, a:json)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#completions(json, handler)
  call s:wait_for_pending_events()

  let path = s:editor_path.'/completions'
  if has('channel')
    let response = s:internal_http(path, g:kite_long_timeout, a:json)
  else
    let response = s:external_http(s:base_url.path, g:kite_long_timeout, a:json)
  endif
  return a:handler(s:parse_response(response))
endfunction


function! kite#client#post_event(json, handler)
  let path = s:editor_path.'/event'
  if has('channel')
    call s:async(function('s:timer_post', [path, g:kite_short_timeout, a:json, a:handler]))
  else
    call kite#async#execute(s:external_http_cmd(s:base_url.path, g:kite_short_timeout, a:json),
          \ function('s:parse_and_handle', [a:handler]))
  endif
endfunction


function! kite#client#segment(json)
  let key = kite#utils#development() ? 'HB6YvUg60tbMahjKJPwb9TexnHAIJRuy' : 'rbTbZkh6ec2U78iJhVis24FaVSzoFJNs'
  let headers = {
        \ 'Content-Type': 'application/json',
        \ 'Authorization': 'Basic '.kite#base64#encode(key.':')
        \ }
  let NullHandler = {output -> output}
  call kite#async#execute(s:external_http_cmd(s:segment_path, g:kite_external_timeout, a:json, headers), NullHandler)
endfunction


function! s:timer_get(path, timeout, handler, timer)
  call a:handler(s:parse_response(s:internal_http(a:path, a:timeout)))
endfunction

function! s:timer_post(path, timeout, json, handler, timer)
  call a:handler(s:parse_response(s:internal_http(a:path, a:timeout, a:json)))
endfunction

function! s:async(callback)
  call timer_start(0, a:callback)
endfunction


function! s:on_std_out(_channel, message) dict
  let self.stdoutbuffer .= a:message
endfunction


" Optional argument is json to be posted
function! s:internal_http(path, timeout, ...)
  " Use HTTP 1.0 (not 1.1) to avoid having to parse chunked responses.
  if a:0
    let str = 'POST '.a:path." HTTP/1.0\nHost: localhost\nContent-Type: application/x-www-form-urlencoded\nContent-Length: ".len(a:1)."\n\n".a:1
  else
    let str = 'GET '.a:path." HTTP/1.0\nHost: localhost\n\n"
  endif
  call kite#utils#log('')
  call kite#utils#log(map(split(str, '\n', 1), '"> ".v:val'))

  let options = {'stdoutbuffer': ''}
  try
    let channel = ch_open(s:channel_base, {
          \   'mode':     'raw',
          \   'callback': function('s:on_std_out', options)
          \ })
  catch /E898\|E901\|E902/
    call kite#utils#log('Cannot open channel: '.str)
    return ''
  endtry

  try
    call ch_sendraw(channel, str)
  catch /E630\|E631\|E906/
    call kite#utils#log('Cannot send over channel: '.str)
    return ''
  endtry

  let start = reltime()

  while ch_status(channel) !=# 'closed'
    if reltimefloat(reltime(start))*1000 > a:timeout
      call kite#utils#log('| Timed out waiting for response (timeout: '.a:timeout.'ms)')
      try
        call ch_close(channel)
      catch /E906/
        " noop
      endtry
      return ''
    endif

    sleep 5m
  endwhile

  call kite#utils#log('| Received complete response: '.string(reltimefloat(reltime(start))*1000).'ms')

  return options.stdoutbuffer
endfunction


" Optional argument is json to be posted
function! s:external_http(url, timeout, ...)
  if a:0
    let cmd = call(function('s:external_http_cmd'), [a:url, a:timeout] + a:000)
  else
    let cmd = s:external_http_cmd(a:url, a:timeout)
  endif
  return system(cmd)
endif
endfunction


" Optional arguments:
" - json to be posted
" - http headers (dictionary)
function! s:external_http_cmd(endpoint, timeout, ...)
  let cmd = s:http_binary
  let cmd .= ' --timeout '.a:timeout.'ms'

  if a:0 > 0
    let cmd .= ' --post --data '
    if kite#utils#windows()
      let cmd .= s:win_escape_json(a:1)
    else
      let cmd .= s:shellescape(a:1)
    endif
  endif

  if a:0 > 1
    for [key, value] in items(a:2)
      let cmd.= ' --header '.key.'='.shellescape(value)
    endfor
  endif

  let cmd .= ' '.s:shellescape(a:endpoint)
  call kite#utils#log('')
  call kite#utils#log('> '.cmd)
  return cmd
endfunction


function! s:parse_and_handle(handler, out)
  call a:handler(s:parse_response(a:out))
endfunction


" Returns the integer HTTP response code and the string body in a dictionary.
"
" lines - either a list (from async commands) or a string (from sync)
function! s:parse_response(lines)
  if type(a:lines) == v:t_string
    let lines = split(a:lines, '\r\?\n', 1)
  else
    let lines = a:lines
  endif
  call kite#utils#log(map(copy(lines), '"< ".v:val'))

  if empty(a:lines)
    return {'status': 0, 'body': ''}
  endif

  if type(a:lines) == v:t_string
    let lines = split(a:lines, '\r\?\n')
  else
    let lines = a:lines
  endif

  " Ignore occasional 100 Continue.
  let i = match(lines, '^HTTP/1.[01] [2345]\d\d ')
  if i == -1
    return {'status': 0, 'body': ''}
  endif
  let status = split(lines[i], ' ')[1]

  let sep = match(lines, '^$', i)
  let body = join(lines[sep+1:], "\n")

  return {'status': status, 'body': body}
endfunction


function! s:wait_for_pending_events()
  while kite#events#any_events_pending()
    sleep 5m
  endwhile
endfunction


" Only used with NeoVim on not-Windows, in async jobs.
function! s:shellescape(str)
  let [_shell, &shell] = [&shell, 'sh']
  let escaped = shellescape(a:str)
  let &shell = _shell
  return escaped
endfunction


" Only used with NeoVim on Windows.
function! s:win_escape_json(str)
  " Literal " -> \"
  let a = escape(a:str, '"')
  " Literal \\" -> \\\"  (for double quotes escaped inside json property values)
  let b = substitute(a, '\\\\"', '\\\\\\"', 'g')
  return '"'.b.'"'
endfunction


let s:http_binary = kite#utils#lib('kite-http')

