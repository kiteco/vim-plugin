function! kite#codenav#from_file()
  call kite#codenav#request_related(expand('%:p'), v:null)
endfunction


function! kite#codenav#from_line()
  if getline(".") ==# ''
    echohl WarningMsg | echo "Code finder only works on non-empty lines."
    return
  endif
  call kite#codenav#request_related(expand('%:p'), line("."))
endfunction


function! kite#codenav#request_related(filename, line)
  let json = json_encode({
    \ 'editor': 'vim',
    \ 'location': {'filename': a:filename, 'line': a:line}
    \ })
  call kite#client#request_related(json, function('kite#codenav#handler'))
endfunction


function! kite#codenav#handler(response) abort
  if a:response.status != 200
    if a:response.status == 0
      echohl WarningMsg | echo "Kite could not be reached. Please check that Kite Engine is running."
      return
    endif

    let err = trim(a:response.body)
    if err == 'ErrProjectStillIndexing'
      echohl WarningMsg | echo "Kite is not done indexing your project yet."
    elseif err == 'ErrPathNotInSupportedProject'
      echohl WarningMsg | echo "Code finder only works in Git projects."
    endif
  endif
endfunction
