let s:port         = 46624
let s:channel_base = 'localhost:'.s:port
let s:base_url     = 'http://127.0.0.1:'.s:port
let s:editor_path  = '/clientapi/editor'
let s:hover_path   = '/api/buffer/vim'
let s:example_path = '/api/python/curation'
let s:webapp_path  = '/clientapi/desktoplogin?d='
let s:status_path  = '/clientapi/status?filename='
let s:user_path    = '/clientapi/user'


function! kite#client#logged_in(handler)
  let path = s:user_path
  if has('channel')
    let response = s:internal_http(path)
  else
    let response = s:external_http(s:base_url.path)
  endif
  return a:handler(kite#client#parse_response(response))
endfunction


function! kite#client#status(filename, handler)
  let path = s:status_path.a:filename
  if has('channel')
    let response = s:internal_http(path)
  else
    let response = s:external_http(s:base_url.path)
  endif
  return a:handler(kite#client#parse_response(response))
endfunction


function! kite#client#webapp_link(id)
  call kite#utils#browse(s:base_url.s:webapp_path.kite#utils#url_encode('/docs/python/'.a:id))
endfunction


function! kite#client#example(id, handler)
  let path = s:example_path.'/'.a:id
  if has('channel')
    let response = s:internal_http(path)
  else
    let response = s:external_http(s:base_url.path)
  endif
  return a:handler(kite#client#parse_response(response))
endfunction


function! kite#client#hover(filename, hash, characters_start, characters_end, handler)
  let path = s:hover_path.'/'.a:filename.'/'.a:hash.'/hover?selection_begin_runes='.a:characters_start.'&selection_end_runes='.a:characters_end
  if has('channel')
    call s:async(function('s:timer_hover', [path, a:handler]))
  else
    call kite#async#execute(s:curl_cmd(s:base_url.path), a:handler)
  endif
endfunction

function! s:timer_hover(path, handler, timer)
  call a:handler(kite#client#parse_response(s:internal_http(a:path)))
endfunction


function! kite#client#signatures(json, handler)
  let path = s:editor_path.'/signatures'
  if has('channel')
    let response = s:internal_http(path, a:json)
  else
    let response = s:external_http(s:base_url.path, a:json)
  endif
  return a:handler(kite#client#parse_response(response))
endfunction


function! kite#client#completions(json, handler)
  let path = s:editor_path.'/completions'
  if has('channel')
    let response = s:internal_http(path, a:json)
  else
    let response = s:external_http(s:base_url.path, a:json)
  endif
  return a:handler(kite#client#parse_response(response))
endfunction


function! kite#client#post_event(json, handler)
  let path = s:editor_path.'/event'
  if has('channel')
    call s:async(function('s:timer_post_event', [path, a:json, a:handler]))
  else
    call kite#async#execute(s:curl_cmd(s:base_url.path, a:json), a:handler)
  endif
endfunction

function! s:timer_post_event(path, json, handler, timer)
  call a:handler(kite#client#parse_response(s:internal_http(a:path, a:json)))
endfunction


function! s:async(callback)
  call timer_start(0, a:callback)
endfunction


" Optional argument is json to be posted
function! s:internal_http(path, ...)
  call kite#utils#log('> channel: '.a:path)
  let channel = ch_open(s:channel_base, {'mode': 'raw'})
  " Use HTTP 1.0 (not 1.1) to avoid having to parse chunked responses.
  if a:0
    let str = 'POST '.a:path." HTTP/1.0\nHost: localhost\nContent-Type: application/x-www-form-urlencoded\nContent-Length: ".len(a:1)."\n\n".a:1
  else
    let str = 'GET '.a:path." HTTP/1.0\nHost: localhost\n\n"
  endif
  return ch_evalraw(channel, str)
endfunction


" Optional argument is json to be posted
function! s:external_http(url, ...)
  call kite#utils#log('> external: '.a:url)
  if a:0
    let cmd = s:curl_cmd(a:url, a:1)
  else
    let cmd = s:curl_cmd(a:url)
  endif
  return system(cmd)
endif
endfunction


" Optional argument is json to be posted
function! s:curl_cmd(endpoint, ...)
  if executable('curl')
    let cmd = 'curl -sSi '.shellescape(a:endpoint)
    if a:0
      let cmd .= ' -X POST -d '
      if kite#utils#windows()
        let cmd .= s:win_escape_json(a:1)
      else
        let cmd .= shellescape(a:1)
      endif
    endif
    call kite#utils#log('> '.cmd)
    return cmd

  elseif kite#utils#windows()
    let cmd = s:http_binary
    if a:0
      let cmd .= ' --post --data '.s:win_escape_json(a:1)
    endif
    let cmd .= ' '.shellescape(a:endpoint)
    call kite#utils#log('> '.cmd)
    return cmd

  else
    " Should not get here due to check in plugin/kite.vim
    throw 'requires curl or windows'
  endif
endfunction


" Returns the integer HTTP response code and the string body in a dictionary.
"
" lines - either a list (from async commands) or a string (from sync)
function! kite#client#parse_response(lines)
  if type(a:lines) == v:t_string
    let lines = split(a:lines, "\r\n")
  else
    let lines = a:lines
  endif
  call kite#utils#log(map(lines, '"< ".v:val'))

  if empty(a:lines)
    return {'status': 0, 'body': ''}
  endif

  if type(a:lines) == v:t_string
    let lines = split(a:lines, "\r\n")
  else
    let lines = a:lines
  endif

  " Ignore occasional 100 Continue.
  let i = match(lines, '^HTTP/1.[01] [2345]\d\d ')
  let status = split(lines[i], ' ')[1]

  let sep = match(lines, '^$', i)
  let body = join(lines[sep+1:], "\n")

  return {'status': status, 'body': body}
endfunction


function! s:win_escape_json(str)
  " Literal " -> \"
  let a = escape(a:str, '"')
  " Literal \\" -> \\\"  (for double quotes escaped inside json property values)
  let b = substitute(a, '\\\\"', '\\\\\\"', 'g')
  return '"'.b.'"'
endfunction


let s:http_binary = kite#utils#lib('kite-http')

