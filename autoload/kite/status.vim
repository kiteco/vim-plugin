function! kite#status#status(...)
  let buf = bufnr('')

  if !getbufvar('', 'kite_enabled')
    call setbufvar(buf, 'kite_status', 'ready')
    return
  endif

  let filename = kite#utils#filepath(0)
  call kite#client#status(filename, function('kite#status#handler', [buf]))
endfunction


function! kite#status#handler(buffer, response)
  call kite#utils#log('kite#status#handler: '.a:response.status.' :: '.a:response.body.' :: buffer '.a:buffer)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  " indexing | syncing | ready | not whitelisted | ignored | blacklisted
  let status = json.status

  if index(['not whitelisted', 'blacklisted', 'ignored'], status) > -1
    let status = 'ready'
  endif

  call setbufvar(a:buffer, 'kite_status', json.status)
endfunction

