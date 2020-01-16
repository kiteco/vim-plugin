let s:languages_supported_by_kited = []

" Returns true if the current buffer's language is supported by this plugin, false otherwise.
function! kite#languages#supported_by_plugin()
  if &filetype == 'python' && expand('%:e') != 'pyi' && index(g:kite_supported_languages, 'python') != -1
    return 1
  endif

  if &filetype == 'go' && index(g:kite_supported_languages, 'go') != -1
    return 1
  endif

  return 0
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
