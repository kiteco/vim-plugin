function! kite#hover#hover()
  if wordcount().bytes > kite#max_file_size() | return | endif

  let filename = kite#utils#filepath(1)
  let hash = kite#utils#buffer_md5()
  let [token_start, token_end] = kite#utils#token_characters()
  if [token_start, token_end] == [-1, -1] | return | endif

  call kite#client#hover(filename, hash, token_start, token_end, function('kite#hover#handler'))
endfunction


function! kite#hover#handler(response)
  if a:response.status != 200 | return | endif

  " options for display
  " - status line only
  " - dedicated window (open automatically? when to close?)

  let json = json_decode(a:response.body)
  let report = json.report
  let description = report.description_text
  echo description
endfunction
