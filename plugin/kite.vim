let s:supported_languages = ['javascript', 'python']


if !(has('nvim') || has('job'))
  call kite#utils#warn('disabled - requires a vim with job support')
  finish
endif

if !executable('curl')
  call kite#utils#warn('disabled - requires curl')
  finish
endif


function! kite#max_file_size()
  return 1048576  " 1MB
endfunction


function! s:toggle()
  if s:supported_language() && s:file_size_ok()
    call s:enable()
  else
    call s:disable()
  endif
endfunction


function! s:supported_language()
  return index(s:supported_languages, &filetype) > -1
endfunction


function! s:file_size_ok()
  let size = getfsize(expand('%'))
  return size > 0 && size < kite#max_file_size()
endfunction


function! s:enable()
  augroup KiteFiles
    autocmd!
    autocmd CursorMoved              * call kite#events#event('selection')
    autocmd TextChanged,TextChangedI * call kite#events#event('edit')
    autocmd BufEnter,FocusGained     * call kite#events#event('focus')
  augroup END
endfunction


function! s:disable()
  augroup KiteFiles
    autocmd!
  augroup END
endfunction


augroup Kite
  autocmd!
  autocmd BufEnter * call <SID>toggle()
augroup END

