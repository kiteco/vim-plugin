function! kite#events#event(action)
  if wordcount().bytes > kite#max_file_size() | return | endif

  let filename = kite#utils#filepath(0)

  let text = kite#utils#buffer_contents()

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

  call kite#client#post_event(json, function('kite#events#handler'))
endfunction


function! kite#events#handler(response)
  if a:response.status == 500
    call kite#utils#warn('events: JSON error')
  endif
endfunction

