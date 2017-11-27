function! kite#report#symbol_report(id)
  call kite#client#symbol_report(a:id, function('kite#report#symbol_report_handler'))
endfunction

function! kite#report#symbol_report_handler(response)
  call kite#utils#log('symbol report: '.a:response.status)
  if a:response.status != 200 | return | endif

  call kite#hover#handler(a:response)
endfunction
