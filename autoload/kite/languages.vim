let s:languages_supported_by_kited = []

" Returns true if the current buffer's language is supported by this plugin, false otherwise.
function! kite#languages#supported_by_plugin()
  if s:supported_filetype('python') && expand('%:e') != 'pyi'
    return 1
  endif

  for lang in ['go', 'javascript', 'vue', 'typescript', 'css', 'html', 'less', 'c', 'scala', 'java', 'kotlin']
    if s:supported_filetype(lang)
      return 1
    endif
  endfor

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


function s:supported_filetype(name)
  return &filetype == a:name && index(g:kite_supported_languages, a:name) != -1
endfunction
