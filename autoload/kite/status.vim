" Updates the status of the current buffer.
"
" Optional argument is a timer id (when called by a timer).
function! kite#status#status(...)
  let buf = bufnr('')
  let msg = 'NOT SET'

  if !getbufvar('', 'kite_enabled')
    let msg = ''
  elseif !kite#utils#kite_installed()
    let msg = 'not installed'
  elseif !kite#utils#kite_running()
    let msg = 'not running'
  elseif !kite#utils#logged_in()
    let msg = 'not logged in'
  endif

  if msg !=# 'NOT SET'
    call setbufvar(buf, 'kite_status', msg)
    return
  endif

  let filename = kite#utils#filepath(0)
  call kite#client#status(filename, function('kite#status#handler', [buf]))
endfunction


function! kite#status#handler(buffer, response)
  call kite#utils#log('kite status status: '.a:response.status.', body: '.a:response.body)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  " indexing | syncing | ready | not whitelisted | ignored | blacklisted
  let status = json.status

  if !exists('b:kite_whitelist_checked')
    if status ==? 'not whitelisted'
      call kite#utils#info("Kite is not enabled for this file. Please whitelist it in Kite's settings to enable Kite.")
    endif
    let b:kite_whitelist_checked = 1
  endif

  if index(['not whitelisted', 'blacklisted', 'ignored'], status) > -1
    let status = 'ready'
  endif

  call setbufvar(a:buffer, 'kite_status', json.status)
endfunction

