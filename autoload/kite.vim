let s:supported_languages = ['python']
let s:status_poll_interval = 5000  " milliseconds
let s:timer = -1


if g:kite_override_sign_column_highlight
  highlight! link SignColumn LineNr
endif


function kite#statusline()
  if exists('b:kite_status') && !empty(b:kite_status)
    return 'Kite: '.kite#utils#capitalize(b:kite_status)
  else
    return ''
  endif
endfunction


function! kite#toggle()
  " Always set up Kite events
  call s:setup_kite_events()
  call s:on_bufenter()

  if s:supported_language() && s:file_size_ok()
    call s:enable()
  else
    call s:disable()
  endif
endfunction


function! kite#max_file_size()
  return 1048576  " 1MB
endfunction


function s:setup_kite_events()
  augroup KiteEvents
    autocmd! * <buffer>
    autocmd CursorHold               <buffer> call kite#events#event('selection')
    autocmd TextChanged,TextChangedI <buffer> call kite#events#event('edit')
    autocmd FocusGained              <buffer> call kite#events#event('focus')
    autocmd BufEnter                 <buffer> call s:on_bufenter()
  augroup END
endfunction


function! s:on_bufenter()
  call kite#events#event('focus')
  call kite#status#status()
endfunction


function! s:enable()
  if s:timer == -1
    let s:timer = timer_start(s:status_poll_interval,
          \   function('kite#status#status'),
          \   {'repeat': -1}
          \ )
  else
    call timer_pause(s:timer, 0)  " unpause
  endif

  if getbufvar('', 'kite_enabled') | return | endif

  augroup KiteFiles
    autocmd! * <buffer>
    autocmd InsertCharPre            <buffer> call kite#completion#insertcharpre()
    autocmd TextChangedI             <buffer> call kite#completion#autocomplete()

    if exists('g:kite_documentation_continual') && g:kite_documentation_continual
      autocmd CursorHold,CursorHoldI <buffer> call kite#hover#hover()
    endif
  augroup END

  if &pumheight == 0
    set pumheight=10
  endif

  if &updatetime == 4000
    set updatetime=100
  endif

  set shortmess+=c
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

  " InsertCharPre is not fired for non-printable characters such as backspace.
  " TextChangedI is not fired when the pop-up menu is open.  Therefore use
  " an insert-mode mapping to force completion to re-occur when backspace is
  " pressed while the pop-up menu is open.
  inoremap <buffer> <expr> <BS> pumvisible() ? kite#completion#backspace() : "\<BS>"

  if exists('g:kite_tab_complete')
    inoremap <buffer> <expr> <Tab> pumvisible() ? "\<C-y>" : "\<Tab>"
  endif

  if empty(maparg('K', 'n')) && !hasmapto('(kite-hover)', 'n')
    nmap <silent> <buffer> K <Plug>(kite-hover)
  endif

  call setbufvar('', 'kite_enabled', 1)
endfunction


function! s:disable()
  if exists('#KiteFiles')
    autocmd! KiteFiles * <buffer>
  endif
  call timer_pause(s:timer, 1)
endfunction


" Configure &completeopt if and only if it has not been set already.
"
" Note there's no way to distinguish the option not having been set from
" the option having been set by hand to the default value.  So if the user
" sets the option by hand to the default value we will re-configure it.
"
" The alternative is simply to leave the option alone.
function! s:configure_completeopt()
  " Display the option's value.  If it has been set somewhere, there
  " will be a second line showing the location.
  redir => output
    silent verbose set completeopt
  redir END
  let lines = len(split(output, '\n'))
  " Don't (re-)configure option if:
  " - (option has been set somewhere) OR
  " - (option hasn't been set / option was set by hand AND is not the default value)
  if lines > 1 || (lines == 1 && &completeopt !=# 'menu,preview') | return | endif

  " completeopt is not global-local.

  set completeopt-=menu
  set completeopt+=menuone
  set completeopt-=longest
  set completeopt-=preview
  set completeopt+=noinsert
  set completeopt-=noselect
endfunction


function! s:supported_language()
  return index(s:supported_languages, &filetype) > -1
endfunction


function! s:file_size_ok()
  let size = getfsize(expand('%'))
  return size > 0 && size < kite#max_file_size()
endfunction

