if !exists('g:kite_auto_complete')
  let g:kite_auto_complete = 1
endif

if !exists('g:kite_preview_code')
  let g:kite_preview_code = 0
endif


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


" Configure &completeopt if and only if it has not been set already.
function! s:configure_completeopt()
  " Display the option's value.  If it has been set somewhere, there
  " will be a second line showing the location.
  redir => output
    silent verbose set completeopt
  redir END
  if len(split(output, '\n')) > 1 | return | endif

  " completeopt is not global-local.

  set completeopt-=menu
  set completeopt+=menuone
  set completeopt-=longest
  set completeopt-=preview
  set completeopt+=noinsert
  set completeopt-=noselect
endfunction


function! s:enable()
  augroup KiteFiles
    autocmd!
    autocmd CursorMoved              * call kite#events#event('selection')
    autocmd TextChanged,TextChangedI * call kite#events#event('edit')
    autocmd BufEnter,FocusGained     * call kite#events#event('focus')
    autocmd InsertCharPre            * call kite#completion#insertcharpre()
    autocmd TextChangedI             * call kite#completion#autocomplete()

    if exists('g:kite_documentation_continual') && g:kite_documentation_continual
      autocmd CursorMoved * call kite#hover#hover()
    endif
  augroup END

  setlocal completefunc=kite#completion#complete
  call s:configure_completeopt()

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
  if exists('g:kite_deconflict_cr') && g:kite_deconflict_cr
    inoremap <silent> <buffer> <CR> <C-R>=kite#completion#popup_exit('')<CR><CR>
  else
    inoremap <buffer> <expr> <CR> kite#completion#popup_exit("\<CR>")
  endif
  if exists('g:kite_tab_complete')
    inoremap <buffer> <expr> <Tab> pumvisible() ? "\<C-y>" : "\<Tab>"
  endif

  if empty(maparg('K', 'n')) && !hasmapto('(kite-hover)', 'n')
    nmap <silent> <buffer> K <Plug>(kite-hover)
  endif
endfunction


function! s:disable()
  if exists('#KiteFiles')
    autocmd! KiteFiles
    augroup! KiteFiles
  endif
endfunction


augroup Kite
  autocmd!
  autocmd BufEnter * call <SID>toggle()
augroup END


nnoremap <silent> <Plug>(kite-hover) :call kite#hover#hover()<CR>

