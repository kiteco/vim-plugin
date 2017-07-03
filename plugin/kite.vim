let g:kite_auto_complete = 1


let s:supported_languages = ['javascript', 'python']


if !(has('nvim') || has('job'))
  call kite#utils#warn('disabled - requires nvim or vim with job support')
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
    autocmd InsertCharPre            * call kite#completion#insertcharpre()
    autocmd TextChangedI             * call kite#completion#autocomplete()
  augroup END

  setlocal completefunc=kite#completion#complete
  setlocal completeopt-=menu
  setlocal completeopt+=menuone

  " When the pop-up menu is closed with <C-e>, <C-y>, or <CR>,
  " the TextChangedI event is fired again, which re-opens the
  " pop-up menu.  To avoid this, we set a flag when one of those
  " keys is pressed.
  "
  " Note the <CR> mapping can conflict with vim-endwise because vim-endwise
  " also maps <CR>.  There are two ways around the conflict:
  "
  " - Either:
  "
  "     let g:kite_deconflict_cr = 1
  "
  "   This works but you will see the mapping echoed in the status line
  "   because vim-endwise ignores the <silent> when it re-maps the map.
  "
  " - Or use vim-endwise's experimental abbreviations instead:
  "
  "     let g:endwise_abbreviations = 1
  "     let g:endwise_no_mappings = 1
  "
  inoremap <buffer> <expr> <C-e> kite#completion#popup_exit("\<C-e>")
  inoremap <buffer> <expr> <C-y> kite#completion#popup_exit("\<C-y>")
  if !exists('g:kite_deconflict_cr')
    inoremap <buffer> <expr> <CR> kite#completion#popup_exit("\<CR>")
  else
    inoremap <silent> <buffer> <CR> <C-R>=kite#completion#popup_exit('')<CR><CR>
  endif
endfunction


function! s:disable()
  if exists('#KiteFiles')
    autocmd! KiteFiles
    augroup! KiteFiles
  endif

  inoremap <buffer> <C-e> <C-e>
  inoremap <buffer> <C-y> <C-y>
  inoremap <buffer> <CR> <CR>
endfunction


augroup Kite
  autocmd!
  autocmd BufEnter * call <SID>toggle()
augroup END

