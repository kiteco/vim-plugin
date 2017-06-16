function! kite#events#event(action)
  let filename = resolve(expand('%:p'))

  let text = s:buffer_contents()
  if strlen(text) > kite#max_file_size()
    return
  endif

  let [sel_start, sel_end] = kite#utils#selected_region_characters()
  if [sel_start, sel_end] == [-1, -1]
    return
  endif
  let selections = [{ 'start': sel_start, 'end': sel_end }]

  let json = json_encode({
        \ 'source':     'vim',
        \ 'filename':   filename,
        \ 'text':       text,
        \ 'action':     a:action,
        \ 'selections': selections
        \ })

  call kite#client#post_event(json)
endfunction


function! s:buffer_contents()
  let [unnamed, zero] = [@", @0]
  silent %y
  let [contents, @", @0] = [@0, unnamed, zero]
  return contents
endfunction

