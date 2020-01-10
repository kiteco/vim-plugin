let s:languages_supported_by_kited = []

" Returns true if the current buffer's language is supported by this plugin, false otherwise.
function! kite#languages#supported_by_plugin()
  return (&filetype == 'python' && expand('%:e') != 'pyi') || &filetype == 'go'
endfunction


" Returns true if the current buffer's language is supported by kited, false otherwise.
function! kite#languages#supported_by_kited()
  " Only check kited's languages once.
  if empty(s:languages_supported_by_kited)
    let s:languages_supported_by_kited = kite#client#languages(function('kite#languages#handler'))
  endif

  return index(s:languages_supported_by_kited, &filetype) != -1
endfunction


function! kite#languages#handler(response)
  if a:response.status != 200 | return [] | endif

  return json_decode(a:response.body)
endfunction
