let s:base_url = 'http://127.0.0.1:46624/clientapi/editor'


function! kite#client#signatures(json, handler)
  return a:handler(kite#client#parse_response(system(s:curl_cmd('/signatures', a:json))))
endfunction


function! kite#client#completions(json, handler)
  return a:handler(kite#client#parse_response(system(s:curl_cmd('/completions', a:json))))
endfunction


function! kite#client#post_event(json, handler)
  call kite#async#execute(s:curl_cmd('/event', a:json), a:handler)
endfunction


function! s:curl_cmd(endpoint, json)
  return 'curl -sSi '.
        \ shellescape(s:base_url.a:endpoint).
        \ ' -X POST'.
        \ ' -d '.shellescape(a:json)
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

