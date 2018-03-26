"
" Editor feature metrics
"

let s:prompted = 0


" Optional argument is value by which to increment named metric.
" Defaults to 1.
function! kite#metrics#requested(name)
  call s:increment('vim_'.a:name.'_requested')
endfunction


function! kite#metrics#fulfilled(name)
  call s:increment('vim_'.a:name.'_fulfilled')
endfunction


function! s:increment(name)
  let json = json_encode({'name': a:name, 'value': 1})
  call kite#client#counter(json, function('kite#metrics#handler'))
endfunction


function! kite#metrics#handler(response)
  " Noop
endfunction



"
" kited metrics
"


" Optional argument is a timer id (when called by a timer).
function! kite#metrics#send(...)
  if !s:editor_metrics_is_enabled()
    return
  endif

  let payload = {
        \   'userId': 0,
        \   'event':  'kited_health',
        \   'properties': {
        \     'user_id':        kite#utils#mac_address(),
        \     'value':          kite#utils#kited_state(),
        \     'os_name':        kite#utils#os(),
        \     'plugin_version': kite#utils#plugin_version(),
        \     'sent_at':        kite#utils#unix_timestamp(),
        \     'source':         'vim'
        \   }
        \ }

  call kite#client#segment(json_encode(payload))
endfunction


function! kite#metrics#show_editor_metrics_opt_in()
  if s:editor_metrics_decided()
    return
  endif

  if s:prompted
    return
  endif
  let s:prompted = 1

  let prompt =
        \ "Kite can periodically send information to our servers about the\n".
        \ "status of the Kite application to ensure that it is running correctly.\n".
        \ "Type 'Yes' to opt-in or 'No' to disable this (or <Esc> or <Enter> to cancel): "
  let response = input(prompt)
  if response =~? '^y'
    call kite#metrics#enable_editor_metrics()
  elseif response =~? '^n'
    call kite#metrics#disable_editor_metrics()
  endif
endfunction


function! kite#metrics#enable_editor_metrics()
  call kite#utils#settings(s:editor_metrics_key, 'yes')
endfunction


function! kite#metrics#disable_editor_metrics()
  call kite#utils#settings(s:editor_metrics_key, 'no')
endfunction


" Whether the user has made a decision on whether to opt in to editor metrics.
function! s:editor_metrics_decided()
  return kite#utils#settings(s:editor_metrics_key) =~# 'yes\|no'
endfunction


function! s:editor_metrics_is_enabled()
  return kite#utils#settings(s:editor_metrics_key) ==# 'yes'
endfunction


let s:editor_metrics_key = 'editor_metrics_enabled'

