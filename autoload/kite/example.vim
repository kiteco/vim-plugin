function! kite#example#handler(response)
  call kite#utils#log('example: '.a:response.status)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)

  let output = []

  call add(output, '# '.json.title)

  for snippet in json.prelude
    if snippet.type ==# 'code'
      call add(output, '')
      call add(output, snippet.content.code)
    endif
  endfor

  for snippet in json.code
    if snippet.type ==# 'code'
      call add(output, '')
      call extend(output, split(snippet.content.code, "\n"))
    elseif snippet.type ==# 'output'
      call extend(output, map(split(snippet.content.value, "\n"), {_,line -> '>> '.line}))
    endif
  endfor

  return output
endfunction
