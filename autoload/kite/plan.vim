function! kite#plan#is_pro()
  return kite#client#plan(function('kite#plan#handler'))
endfunction


function! kite#plan#handler(response)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  return json.active_subscription ==? 'pro' && json.status ==? 'active'
endfunction
