if exists('g:loaded_kite') || &cp || v:version < 700
  finish
endif
let g:loaded_kite = 1


filetype on


if !exists('g:kite_auto_complete')
  let g:kite_auto_complete = 1
endif

if !exists('g:kite_preview_code')
  let g:kite_preview_code = 0
endif

if !exists('g:kite_override_sign_column_highlight')
  let g:kite_override_sign_column_highlight = 1
endif

if !exists('g:kite_log')
  let g:kite_log = 0
endif

if !(has('nvim') || has('job'))
  call kite#utils#warn('disabled - requires nvim or vim with the +job feature')
  finish
endif

if !(has('nvim') || has('timers'))
  call kite#utils#warn('disabled - requires nvim or vim with the +timers feature')
  finish
endif

if kite#utils#windows()
  " Avoid taskbar flashing on Windows when executing system() calls.
  set noshelltemp
endif

augroup Kite
  autocmd!
  autocmd BufEnter * call kite#toggle()
augroup END


nnoremap <silent> <Plug>(kite-hover) :call kite#hover#hover()<CR>

command! KiteTour call kite#utils#generate_help() | help kite

