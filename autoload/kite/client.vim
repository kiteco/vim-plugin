function! kite#client#post_event(json)
  let cmd = 'curl -sSi '.
        \ shellescape('http://127.0.0.1:46624/clientapi/editor/event').
        \ ' -X POST'.
        \ ' -d '.shellescape(a:json)
  call s:execute(cmd)
endfunction


function! s:execute(cmd)
  let options = {
        \ 'stdoutbuffer': []
        \ }
  let command = s:build_command(a:cmd)

  if has('nvim')
    call jobstart(command, extend(options, {
          \ 'on_stdout': function('s:on_stdout_nvim'),
          \ 'on_exit':   function('s:on_exit_nvim')
          \ }))
  else
    call job_start(command, {
          \ 'out_cb':       function('s:on_stdout_vim', options),
          \ 'close_cb':     function('s:on_close_vim', options)
          \ })
  endif
endfunction


function! s:build_command(cmd)
  if has('nvim')
    if has('unix')
      return ['sh', '-c', a:cmd]
    elseif has('win32')
      return ['cmd.exe', '/c', a:cmd]
    else
      throw 'unknown os'
    endif
  else
    if has('unix')
      return ['sh', '-c', a:cmd]
    elseif has('win32')
      return 'cmd.exe /c '.a:cmd
    else
      throw 'unknown os'
    endif
  endif
endfunction


function! s:on_stdout_vim(_channel, data) dict
  " a:data - an output line
  call add(self.stdoutbuffer, a:data)
endfunction


function! s:on_close_vim(channel) dict
  if empty(self.stdoutbuffer)
    return
  endif

  let status = split(self.stdoutbuffer[0], ' ')[1]

  if status == 500
    call kite#utils#warn('events: JSON error')
  endif
endfunction


" TODO: handle incomplete last line - this happens
" when line exceeds 8192 bytes (neovim/neovim#4266).
function! s:on_stdout_nvim(_job_id, data, event) dict
  if a:event ==# 'stdout'
    " a:data - array of output lines
    call extend(self.stdoutbuffer, a:data)
  endif
endfunction


function! s:on_exit_nvim(_job_id, _data, _event) dict
  if empty(self.stdoutbuffer)
    return
  endif

  let status = split(self.stdoutbuffer[0], ' ')[1]

  if status == 500
    call kite#utils#warn('events: JSON error')
  endif
endfunction

