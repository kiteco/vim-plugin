let s:is_pro = 1


" Optional argument is timer.
function! kite#plan#check(...)
  call kite#client#plan(function('kite#plan#handler'))
endfunction


function! kite#plan#is_pro()
  return s:is_pro
endfunction


function! kite#plan#handler(response)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  let s:is_pro = json.active_subscription ==? 'pro' && json.status ==? 'active'
endfunction
