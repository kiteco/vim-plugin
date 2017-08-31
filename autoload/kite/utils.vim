let s:windows_os = has('win64') || has('win32') || has('win32unix')


function! kite#utils#warn(msg)
  echohl WarningMsg
  echo 'kite: '.a:msg
  echohl None
  let v:warningmsg = a:msg
endfunction


" Returns the absolute path to the current file after resolving symlinks.
"
" url_format - when truthy, return the path in a URL-compatible format.
function! kite#utils#filepath(url_format)
  let path = resolve(expand('%:p'))

  if a:url_format
    let path = substitute(path, '[\/]', ':', 'g')
    if s:windows_os
      let path = ':windows:'.path
    endif
    let path = kite#utils#url_encode(path)
  endif

  return path
endfunction


" Opens `url` in the user's browser.
function! kite#utils#browse(url)
  if !exists('g:loaded_netrw')
    runtime! autoload/netrw.vim
  endif
  if exists('*netrw#BrowseX')
    call netrw#BrowseX(a:url, 0)
  else
    call netrw#NetrwBrowseX(a:url, 0)
  endif
endfunction


" Returns a 2-element list of 0-based character indices into the buffer.
"
" When no text is selected, both elements are the cursor position.
"
" When text is selected, the elements are the start (inclusive) and
" end (exclusive) of the selection.
"
" Returns [-1, -1] when not in normal, insert, or visual mode.
function! kite#utils#selected_region_characters()
  return s:selected_region('c')
endfunction


" Returns a 2-element list of 0-based byte indices into the buffer.
"
" When no text is selected, both elements are the cursor position.
"
" When text is selected, the elements are the start (inclusive) and
" end (exclusive) of the selection.
"
" Returns [-1, -1] when not in normal, insert, or visual mode.
function! kite#utils#selected_region_bytes()
  return s:selected_region('b')
endfunction


" Returns a 2-element list of 0-based indices into the buffer.
"
" When no text is selected, both elements are the cursor position.
"
" When text is selected, the elements are the start (inclusive) and
" end (exclusive) of the selection.
"
" Returns [-1, -1] when not in normal, insert, or visual mode.
"
" param type (String) - 'c' for character indices, 'b' for byte indices
function! s:selected_region(type)
  if a:type == 'c'
    let Offset = function('kite#utils#character_offset')
  else
    let Offset = function('kite#utils#byte_offset')
  endif

  if mode() ==# 'n' || mode() ==# 'i'
    let offset = Offset()
    return [offset, offset]
  endif

  if mode() ==? 'v'
    let pos_start = getpos('v')
    let pos_end   = getpos('.')

    if (pos_start[1] > pos_end[1]) || (pos_start[1] == pos_end[1] && pos_start[2] > pos_end[2])
      let [pos_start, pos_end] = [pos_end, pos_start]
    endif

    " switch to normal mode
    normal! v

    call setpos('.', pos_start)
    let offset1 = Offset()

    call setpos('.', pos_end)
    " end position is exclusive
    let [ve, &virtualedit] = [&virtualedit, 'onemore']
    normal! l
    let offset2 = Offset()
    let &virtualedit = ve

    " restore visual selection
    normal! gv

    return [offset1, offset2]
  endif

  return [-1, -1]
endfunction


" Returns the 0-based index into the buffer of the cursor position.
" Returns -1 when the buffer is empty.
"
" Does not work in visual mode.
function! kite#utils#character_offset()
  return (wordcount().cursor_chars) - 1
endfunction


" Returns the 0-based index into the buffer of the cursor position.
" Returns -2 for a new, empty buffer or 0 for an existing, empty buffer.
function! kite#utils#byte_offset()
  " We could use `return (wordcount().cursor_bytes) - 1` but with a multibyte
  " character it reports the character's last byte rather than its first.  So
  " we would have to step one character left, get the byte offset, and add 1.
  " Overall, the following is easier.
  return line2byte(line('.')) - 1 + col('.') - 1
endfunction


" Returns a 2-element list of 0-based character indices into the buffer.
"
" When a token is under the cursor, the elements are the start (inclusive)
" and end (exclusive) of the token.
"
" Returns [-1, -1] when no token is under the cursor.
function! kite#utils#token_characters()
  return s:token('c')
endfunction


" Returns a 2-element list of 0-based byte indices into the buffer.
"
" When a token is under the cursor, the elements are the start (inclusive)
" and end (exclusive) of the token.
"
" Returns [-1, -1] when no token is under the cursor.
function! kite#utils#token_bytes()
  return s:token('b')
endfunction


" Returns a 2-element list of 0-based indices into the buffer.
"
" When a token is under the cursor, the elements are the start (inclusive)
" and end (exclusive) of the token.
"
" Returns [-1, -1] when no token is under the cursor.
"
" param type (String) - 'c' for character indices, 'b' for byte indices
function! s:token(type)
  if a:type == 'c'
    let Offset = function('kite#utils#character_offset')
  else
    let Offset = function('kite#utils#byte_offset')
  endif

  let character_under_cursor = matchstr(getline('.'), '\%'.col('.').'c.')
  if character_under_cursor =~ '\k'
    let pos = getpos('.')

    normal! lb
    let offset1 = Offset()
    normal! e
    " end position is exclusive
    let [ve, &virtualedit] = [&virtualedit, 'onemore']
    normal! l
    let offset2 = Offset()
    let &virtualedit = ve

    call setpos('.', pos)

    return [offset1, offset2]
  else
    return [-1, -1]
  endif
endfunction


function! kite#utils#buffer_contents()
  let [unnamed, zero] = [@", @0]
  silent %y
  let [contents, @", @0] = [@0, unnamed, zero]
  return contents
endfunction


" Returns the MD5 hash of the buffer contents.
function! kite#utils#buffer_md5()
  return s:MD5(kite#utils#buffer_contents())
endfunction


" https://github.com/tpope/vim-unimpaired/blob/3a7759075cca5b0dc29ce81f2747489b6c8e36a7/plugin/unimpaired.vim#L327-L329
function! kite#utils#url_encode(str)
  return substitute(a:str,'[^A-Za-z0-9_.~-]','\="%".printf("%02X",char2nr(submatch(0)))','g')
endfunction


function! s:separator()
  return !exists('+shellslash') || &shellslash ? '/' : '\'
endfunction


function! s:md5(text)
  return substitute(system('md5', a:text), '\n$', '', '')
endfunction

function! s:md5sum(text)
  return split(system('md5sum', a:text), ' ')[0]
endfunction

function! s:md5bin(text)
  return substitute(system(s:md5_binary, a:text), '\n$', '', '')
endfunction


if executable('md5')
  let s:MD5 = function('s:md5')
elseif executable('md5sum')
  let s:MD5 = function('s:md5sum')
else
  let s:md5_binary = expand('<sfile>:p:h:h').s:separator().'lib'.s:separator().'md5Sum.exe'
  let s:MD5 = function('s:md5bin')
endif

