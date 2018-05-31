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

if !exists('g:kite_short_timeout')
  let g:kite_short_timeout = 120  " ms
endif

if !exists('g:kite_long_timeout')
  let g:kite_long_timeout = 400  " ms
endif

if !exists('g:kite_external_timeout')
  let g:kite_external_timeout = 1000  " ms
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

call kite#init()

augroup Kite
  autocmd!
  autocmd BufEnter * call kite#bufenter()
augroup END


nnoremap <silent> <Plug>(kite-hover) :call kite#hover#hover()<CR>

command! KiteDocsAtCursor call kite#hover#hover()
command! KiteOpenSidebar  call kite#hover#openKiteWindow()
command! KiteCloseSidebar call kite#hover#closeKiteWindow()
command! KiteOpenCopilot  call kite#client#copilot()
command! KiteGeneralSettings call kite#client#settings()

command! KiteTour call kite#utils#generate_help() | help kite

command! KiteEnableEditorMetrics :call kite#metrics#enable_editor_metrics()
command! KiteDisableEditorMetrics :call kite#metrics#disable_editor_metrics()

