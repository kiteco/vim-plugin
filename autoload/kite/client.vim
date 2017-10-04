let s:base_url    = 'http://127.0.0.1:46624'
let s:editor_url  = s:base_url.'/clientapi/editor'
let s:hover_url   = s:base_url.'/api/buffer/vim'
let s:example_url = s:base_url.'/api/python/curation'
let s:webapp_url  = s:base_url.'/clientapi/desktoplogin?d='
let s:status_url  = s:base_url.'/clientapi/status?filename='


function! kite#client#status(filename, handler)
  let url = s:status_url.a:filename
  return a:handler(kite#client#parse_response(system(s:curl_cmd(url))))
endfunction


function! kite#client#webapp_link(id)
  let url = s:webapp_url.kite#utils#url_encode('/docs/python/'.a:id)
  call kite#utils#browse(url)
endfunction


function! kite#client#example(id, handler)
  let url = s:example_url.'/'.a:id
  return a:handler(kite#client#parse_response(system(s:curl_cmd(url))))
endfunction


function! kite#client#hover(filename, hash, characters_start, characters_end, handler)
  let url = s:hover_url.'/'.a:filename.'/'.a:hash.'/hover?selection_begin_runes='.a:characters_start.'&selection_end_runes='.a:characters_end
  call kite#async#execute(s:curl_cmd(url), a:handler)
endfunction


function! kite#client#signatures(json, handler)
  let url = s:editor_url.'/signatures'
  return a:handler(kite#client#parse_response(system(s:curl_cmd(url, a:json))))
endfunction


function! kite#client#completions(json, handler)
  let url = s:editor_url.'/completions'
  return a:handler(kite#client#parse_response(system(s:curl_cmd(url, a:json))))
endfunction


function! kite#client#post_event(json, handler)
  let url = s:editor_url.'/event'
  call kite#async#execute(s:curl_cmd(url, a:json), a:handler)
endfunction


" Optional argument is json to be posted
function! s:curl_cmd(endpoint, ...)
  let cmd = 'curl -sSi '.shellescape(a:endpoint)
  if a:0
    let cmd .= ' -X POST -d '.shellescape(a:1)
  endif
  return cmd
endfunction


" Returns the integer HTTP response code and the string body in a dictionary.
"
" lines - either a list (from async commands) or a string (from sync)
function! kite#client#parse_response(lines)
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

