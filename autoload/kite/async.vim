function! kite#async#execute(cmd, handler)
  let options = {
        \ 'stdoutbuffer': [],
        \ 'handler': a:handler,
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
    elseif has('win64') || has('win32')
      return ['cmd.exe', '/c', a:cmd]
    else
      throw 'unknown os'
    endif
  else
    if has('unix')
      return ['sh', '-c', a:cmd]
    elseif has('win64') || has('win32')
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
  call self.handler(self.stdoutbuffer)
endfunction


function! s:on_stdout_nvim(_job_id, data, event) dict
  if empty(self.stdoutbuffer)
    let self.stdoutbuffer = a:data
  else
    let self.stdoutbuffer = self.stdoutbuffer[:-2] +
          \ [self.stdoutbuffer[-1] . a:data[0]] +
          \ a:data[1:]
  endif
endfunction


function! s:on_exit_nvim(_job_id, _data, _event) dict
  call map(self.stdoutbuffer, 'substitute(v:val, "\r$", "", "")')
  call self.handler(self.stdoutbuffer)
endfunction
