function! kite#docs#docs()
  if empty(expand('<cword>')) | return | endif

  let b:kite_id = ''

  call kite#hover#hover()

  while b:kite_id == ''
    sleep 5m
  endwhile

  if b:kite_id == -1
    call kite#utils#info('No documentation available.')
    return
  endif

  call kite#client#docs(b:kite_id)
endfunction

