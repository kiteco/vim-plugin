let s:status_poll_interval = 5 * 1000  " 5sec in milliseconds
let s:timer = -1

if !kite#utils#windows()
  let s:kite_symbol = nr2char(printf('%d', '0x27E0'))
else
  let s:kite_symbol = '[k]'
endif

let s:inited = 0
let s:kite_auto_launched = 0


function kite#enable_auto_start()
  call kite#utils#set_setting('start_kited_at_startup', 1)
  call s:launch_kited()
  call kite#utils#info('Kite: auto-start enabled')
endfunction

function kite#disable_auto_start()
  call kite#utils#set_setting('start_kited_at_startup', 0)
  call kite#utils#info('Kite: auto-start disabled')
endfunction

function kite#symbol()
  return s:kite_symbol
endfunction


function kite#statusline()
  if exists('b:kite_status')
    return b:kite_status
  else
    return ''
  endif
endfunction


function! kite#max_file_size()
  return 76800  " 75KB
endfunction


function! kite#configure_completeopt()
  " If the user has configured completeopt, leave it alone.
  redir => output
    silent verbose set completeopt
  redir END
  if len(split(output, '\n')) > 1 | return | endif

  set completeopt=menuone,noinsert
endfunction


function! s:setup_options()
  let s:pumheight = &pumheight
  if &pumheight == 0
    set pumheight=10
  endif

  let s:updatetime = &updatetime
  if &updatetime == 4000
    set updatetime=100
  endif

  let s:shortmess = &shortmess
  set shortmess+=c

  if kite#utils#windows()
    " Avoid taskbar flashing on Windows when executing system() calls.
    let s:shelltemp = &shelltemp
    set noshelltemp
  endif
endfunction


function! s:restore_options()
  if !exists('s:pumheight') | return | endif

  let &pumheight   = s:pumheight
  let &updatetime  = s:updatetime
  let &shortmess   = s:shortmess
  if kite#utils#windows()
    let &shelltemp = s:shelltemp
  endif
endfunction


function! kite#bufenter()
  if s:supported_language()
    call s:launch_kited()

    call s:setup_options()
    call s:setup_events()
    call s:setup_mappings()

    setlocal completefunc=kite#completion#complete

    call kite#events#event('focus')
    call kite#status#status()
    call s:start_status_timer()

  else
    call s:restore_options()
    call s:stop_status_timer()
  endif
endfunction


function s:setup_events()
  augroup KiteEvents
    autocmd! * <buffer>

    autocmd CursorHold               <buffer> call kite#events#event('selection')
    autocmd TextChanged,TextChangedI <buffer> call kite#events#event('edit')
    autocmd FocusGained              <buffer> call kite#events#event('focus')

    autocmd InsertCharPre            <buffer> call kite#completion#insertcharpre()
    autocmd TextChangedI             <buffer> call kite#completion#autocomplete()

    autocmd CompleteDone             <buffer> call kite#snippet#complete_done()

    if exists('g:kite_documentation_continual') && g:kite_documentation_continual
      autocmd CursorHold,CursorHoldI <buffer> call kite#docs#docs()
    endif
  augroup END
endfunction


function! s:setup_mappings()
  " When the pop-up menu is closed with <C-e>, <C-y>, or <CR>,
  " the TextChangedI event is fired again, which re-opens the
  " pop-up menu.  To avoid this, we set a flag when one of those
  " keys is pressed.
  "
  " Note the <CR> mapping can conflict with vim-endwise because vim-endwise
  " also maps <CR>.  To work around the conflict:
  "
  "     let g:kite_deconflict_cr = 1
  "
  imap <buffer> <expr> <C-e> kite#completion#popup_exit("\<C-e>")
  imap <buffer> <expr> <C-y> kite#completion#popup_exit("\<C-y>")
  if exists('g:kite_deconflict_cr') && g:kite_deconflict_cr
    imap <silent> <buffer> <CR> <C-R>=kite#completion#popup_exit('')<CR><CR>
  else
    imap <buffer> <expr> <CR> kite#completion#popup_exit("\<CR>")
  endif

  if exists('g:kite_tab_complete')
    imap <buffer> <expr> <Tab> pumvisible() ? "\<C-y>" : "\<Tab>"
  endif

  if empty(maparg('K', 'n')) && !hasmapto('(kite-docs)', 'n')
    nmap <silent> <buffer> K <Plug>(kite-docs)
  endif
endfunction


function! s:start_status_timer()
  if s:timer == -1
    let s:timer = timer_start(s:status_poll_interval,
          \   function('kite#status#status'),
          \   {'repeat': -1}
          \ )
  else
    call timer_pause(s:timer, 0)  " unpause
  endif
endfunction


function! s:stop_status_timer()
  call timer_pause(s:timer, 1)
endfunction


function! s:launch_kited()
  if !s:kite_auto_launched && kite#utils#get_setting('start_kited_at_startup', 1)
    call kite#utils#launch_kited()
    let s:kite_auto_launched = 1
  endif
endfunction


function! s:supported_language()
  return index(['py', 'go'], expand('%:e')) >= 0
endfunction

