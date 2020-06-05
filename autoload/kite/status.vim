" Updates the status of the current buffer.
"
" Optional argument is a timer id (when called by a timer).
function! kite#status#status(...)
  if !s:status_in_status_line() | return | endif

  let buf = bufnr('')
  let msg = 'NOT SET'

  " Check kited status (logged-in / installed / running) every 10 file status checks.
  let counter = getbufvar(buf, 'kite_status_counter', 0)
  if counter == 0
    if !kite#utils#logged_in()
      let msg = 'Kite: not logged in'
      if !kite#utils#kite_installed()
        let msg = 'Kite: not installed'
      elseif !kite#utils#kite_running()
        let msg = 'Kite: not running'
      endif
    endif
  endif
  call setbufvar(buf, 'kite_status_counter', (counter + 1) % 10)

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

  " indexing | ready | noIndex
  let status = json.status
  let msg = ''

  if status == 'ready'
    let msg = 'Kite'
  endif

  if status == 'indexing'
    let msg = 'Kite: indexing'
  endif

  if status == 'noIndex'
    let msg = 'Kite: ready (unindexed)'
  endif

  if msg !=# getbufvar(a:buffer, 'kite_status')
    call setbufvar(a:buffer, 'kite_status', msg)
    redrawstatus
  endif
endfunction


function! s:status_in_status_line()
  return stridx(&statusline, 'kite#statusline()') != -1
endfunction

