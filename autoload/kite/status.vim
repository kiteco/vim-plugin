" Updates the status of the current buffer.
"
" Optional argument is a timer id (when called by a timer).
function! kite#status#status(...)
  if !s:status_in_status_line() | return | endif

  let buf = bufnr('')
  let msg = 'NOT SET'

  if !kite#utils#logged_in()
    let msg = 'Kite: not logged in'
    if !kite#utils#kite_installed()
      let msg = 'Kite: not installed'
    elseif !kite#utils#kite_running()
      let msg = 'Kite: not running'
    endif
  endif

  if wordcount().bytes > kite#max_file_size()
    let msg = 'Kite: file too large'
  endif

  if msg !=# 'NOT SET'
    if msg !=# getbufvar(buf, 'kite_status')
      call setbufvar(buf, 'kite_status', msg)
      redrawstatus
    endif
    return
  endif

  let filename = kite#utils#filepath(0)
  call kite#client#status(filename, function('kite#status#handler', [buf]))
endfunction


function! kite#status#handler(buffer, response)
  call kite#utils#log('kite status status: '.a:response.status.', body: '.a:response.body)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  " indexing | syncing | ready
  let status = json.status
  let msg = ''

  if status == 'ready'
    let msg = 'Kite'
  endif

  if status == 'syncing'
    let msg = 'Kite: syncing'
  endif

  if status == 'indexing'
    let msg = 'Kite: indexing'
  endif

  if msg !=# getbufvar(a:buffer, 'kite_status')
    call setbufvar(a:buffer, 'kite_status', msg)
    redrawstatus
  endif
endfunction


function! s:status_in_status_line()
  return stridx(&statusline, 'kite#statusline()') != -1
endfunction

