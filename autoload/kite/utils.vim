function! kite#utils#warn(msg)
  echohl WarningMsg
  echo 'kite: '.a:msg
  echohl None
  let v:warningmsg = a:msg
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


function! kite#utils#buffer_contents()
  let [unnamed, zero] = [@", @0]
  silent %y
  let [contents, @", @0] = [@0, unnamed, zero]
  return contents
endfunction

