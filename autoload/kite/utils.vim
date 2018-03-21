let s:plugin_version = ''
let s:mac_address = ''

" Values for s:os are used in plugin directory structure
" and also metric values.
if has('win64') || has('win32') || has('win32unix')
  let s:os = 'windows'
else
  let uname = substitute(system('uname'), '\n', '', '')  " Darwin or Linux
  let s:os = uname ==? 'Darwin' ? 'macos' : 'linux'
endif

function! kite#utils#windows()
  return s:os ==# 'windows'
endfunction

let s:separator  = !exists('+shellslash') || &shellslash ? '/' : '\'
let s:plugin_dir = expand('<sfile>:p:h:h:h')
let s:doc_dir    = s:plugin_dir.s:separator.'doc'
let s:lib_dir    = s:plugin_dir.s:separator.'lib'
let s:lib_subdir = s:lib_dir.s:separator.(s:os)

if kite#utils#windows()
  let s:settings_path = join(
        \ [$LOCALAPPDATA, 'Kite', 'vim-plugin.json'],
        \ s:separator)
  let s:development_path = join(
        \ [$LOCALAPPDATA, 'Kite', 'vim-development'],
        \ s:separator)
else
  let s:settings_path    = fnamemodify('~/.kite/vim-plugin.json', ':p')
  let s:development_path = fnamemodify('~/.kite/vim-development', ':p')
endif


" Returns 1 if we are running in 'development mode', 0 otherwise.
function! kite#utils#development()
  return filereadable(s:development_path)
endfunction


" When called with 1 argument, read the value for the given key.
" Return 0 if the key is not present.
"
" When called with 2 arguments, write the key and value.
"
" Optional argument is value to set.
function! kite#utils#settings(key, ...)
  if filereadable(s:settings_path)
    let json = join(readfile(s:settings_path), "\n")
    let settings = json_decode(json)
  else
    let settings = {}
  endif

  if a:0
    let settings[a:key] = a:1
    let json = json_encode(settings)
    call writefile(split(json, "\n"), s:settings_path)
  else
    return get(settings, a:key)
  endif
endfunction


function! kite#utils#generate_help()
  execute 'helptags' s:doc_dir
endfunction


function! kite#utils#os()
  return s:os
endfunction


" Returns the current unix time (in seconds) as a string.
function! kite#utils#unix_timestamp()
  return split(reltimestr(reltime()), '\.')[0]
endfunction


function! kite#utils#mac_address()
  if empty(s:mac_address)
    if kite#utils#windows()
      let output = kite#async#sync('ipconfig /all')
    else
      let output = kite#async#sync('ifconfig')
    endif
    let s:mac_address = split(matchstr(output, 'ether \(\x\{2}[:-]\)\{5}\x\{2}'))[1]
    let s:mac_address = tr(s:mac_address, '-', ':')
  endif
  return s:mac_address
endfunction


function! kite#utils#plugin_version()
  let path = s:plugin_dir.s:separator.'VERSION'
  return readfile(path)[0]
endfunction


function! kite#utils#lib(filename)
  return s:lib_subdir.s:separator.a:filename
endfunction


function! kite#utils#kite_installed()
  if kite#utils#windows()
    let output = kite#async#sync('reg query HKEY_LOCAL_MACHINE\Software\Kite\AppData /v InstallPath /s /reg:64')
    " Assume Kite is installed if the output contains 'InstallPath'
    return match(split(output, '\n'), 'InstallPath') > -1
  else  " osx
    return !empty(kite#async#sync('mdfind ''kMDItemCFBundleIdentifier = "com.kite.Kite" || kMDItemCFBundleIdentifier = "enterprise.kite.Kite"'''))
  endif
endfunction


function! kite#utils#kite_running()
  if kite#utils#windows()
    let [cmd, process] = ['tasklist /FI "IMAGENAME eq kited.exe"', '^kited.exe']
  else  " osx
    let [cmd, process] = ['ps -axco command', '^Kite$']
  endif

  return match(split(kite#async#sync(cmd), '\n'), process) > -1
endfunction


" Optional argument is response dictionary (from kite#client#parse_response).
function! kite#utils#logged_in(...)
  if a:0
    return a:1.status == 200
  else
    return kite#client#logged_in(function('kite#utils#logged_in'))
  endif
endfunction


" Returns one of:
"
" 'unsupported'   - Kite is not supported on this computer
" 'uninstalled'   - Kite is supported but not installed on this computer
" 'installed'     - Kite is installed on this computer but not running
" 'running'       - Kite is running on this computer but kited is not reachable
" 'reachable'     - kited is reachable on this computer but the user is not logged in
" 'authenticated' - kited is reachable and the user is currently logged in
function! kite#utils#kited_state()
  if index(['macos', 'windows'], s:os) == -1
    return 'unsupported'
  endif

  if !kite#utils#kite_installed()
    return 'uninstalled'
  endif

  if !kite#utils#kite_running()
    return 'installed'
  endif

  " A response status of 0 indicates timeout/unreachable.
  let logged_in_status = kite#client#logged_in({response -> response.status})
  if !logged_in_status
    return 'running'
  endif

  if logged_in_status != 200
    return 'reachable'
  endif

  return 'authenticated'
endfunction


" msg - a list or a string
function! kite#utils#log(msg)
  if g:kite_log
    if type(a:msg) == v:t_string
      let msg = [a:msg]
    else
      let msg = a:msg
    endif
    call writefile(msg, 'kite-vim.log', 'a')
  endif
endfunction


function! kite#utils#warn(msg)
  echohl WarningMsg
  echo 'Kite: '.a:msg
  echohl None
  let v:warningmsg = a:msg
endfunction


function! kite#utils#info(msg)
  echohl Question
  echo a:msg
  echohl None
endfunction


" Returns the absolute path to the current file after resolving symlinks.
"
" url_format - when truthy, return the path in a URL-compatible format.
function! kite#utils#filepath(url_format)
  let path = resolve(expand('%:p'))

  if a:url_format
    let path = substitute(path, '[\/]', ':', 'g')
    if kite#utils#windows()
      let path = substitute(path, '^\(\a\)::', '\1:', '')
      let path = ':windows:'.path
    endif
    let path = kite#utils#url_encode(path)
  endif

  return path
endfunction


" Opens `url` in the user's browser.
function! kite#utils#browse(url)
  let metric = a:url =~ 'stackoverflow\.com' ? 'stackoverflow_example' : 'open_in_web'
  call kite#metrics#requested(metric)

  if !exists('g:loaded_netrw')
    runtime! autoload/netrw.vim
  endif
  if exists('*netrw#BrowseX')
    call netrw#BrowseX(a:url, 0)
  else
    call netrw#NetrwBrowseX(a:url, 0)
  endif

  call kite#metrics#fulfilled(metric)
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
"
" NOTE: the cursor is moved during the function (but finishes where it started).
function! s:selected_region(type)
  if mode() ==# 'n' || mode() ==# 'i'
    if a:type == 'c'
      let offset = kite#utils#character_offset()
    else
      let offset = kite#utils#byte_offset_start()
    endif
    return [offset, offset]
  endif

  if mode() ==? 'v'
    let pos_start = getpos('v')
    let pos_end   = getpos('.')

    if (pos_start[1] > pos_end[1]) || (pos_start[1] == pos_end[1] && pos_start[2] > pos_end[2])
      let [pos_start, pos_end] = [pos_end, pos_start]
    endif

    " switch to normal mode
    execute "normal! \<Esc>"

    call setpos('.', pos_start)
    if a:type == 'c'
      let offset1 = kite#utils#character_offset()
    else
      let offset1 = kite#utils#byte_offset_start()
    endif

    call setpos('.', pos_end)
    " end position is exclusive
    if a:type == 'c'
      let offset2 = kite#utils#character_offset() + 1
    else
      let offset2 = kite#utils#byte_offset_end() + 1
    endif

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
" If the cursor is on a multibyte character, it reports the character's
" first byte.
function! kite#utils#byte_offset_start()
  let offset = line2byte(line('.')) - 1 + col('.') - 1
  if offset < 0
    let offset = 0
  endif
  return offset
endfunction

" Returns the 0-based index into the buffer of the cursor position.
" If the cursor is on a multibyte character, it reports the character's
" last byte.
function! kite#utils#byte_offset_end()
  let offset = wordcount().cursor_bytes - 1
  if offset < 0
    let offset = 0
  endif
  return offset
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
"
" NOTE: the cursor is moved during the function (but finishes where it started).
function! s:token(type)
  " In insert mode, current column is the one we're about to insert into.
  let col = (mode() == 'i') ? col('.') - 1 : col('.')
  let character_under_cursor = matchstr(getline('.'), '\%'.col.'c.')
  if character_under_cursor =~ '\k'
    let pos = getpos('.')

    if mode() == 'i'
      normal! b
    else
      normal! l
      normal! b
    endif
    if a:type == 'c'
      let offset1 = kite#utils#character_offset()
    else
      let offset1 = kite#utils#byte_offset_start()
    endif

    normal! e
    " end position is exclusive
    if a:type == 'c'
      let offset2 = kite#utils#character_offset() + 1
    else
      let offset2 = kite#utils#byte_offset_end() + 1
    endif

    call setpos('.', pos)

    return [offset1, offset2]
  else
    return [-1, -1]
  endif
endfunction


function! kite#utils#buffer_contents()
  let line_ending = {"unix": "\n", "dos": "\r\n", "mac": "\r"}[&fileformat]
  return join(getline(1, '$'), line_ending).line_ending
endfunction


" Returns the MD5 hash of the buffer contents.
function! kite#utils#buffer_md5()
  return s:MD5(kite#utils#buffer_contents())
endfunction


" https://github.com/tpope/vim-unimpaired/blob/3a7759075cca5b0dc29ce81f2747489b6c8e36a7/plugin/unimpaired.vim#L327-L329
function! kite#utils#url_encode(str)
  return substitute(a:str,'[^A-Za-z0-9_.~-]','\="%".printf("%02X",char2nr(submatch(0)))','g')
endfunction


" Capitalises the first letter of str.
function! kite#utils#capitalize(str)
  return substitute(a:str, '^.', '\u\0', '')
endfunction


" Converts a list of lists (rows) and returns a list of strings.
" This left-aligns the columns and joins them with the separator.
function! kite#utils#columnise(data, separator)
  let maxWidths = map(copy(a:data[0]), 0)
  for row in a:data
    let i = 0
    for cell in row
      if strwidth(cell) > maxWidths[i]
        let maxWidths[i] = strwidth(cell)
      endif
      let i += 1
    endfor
  endfor

  return map(copy(a:data), {_,row ->
        \   join(
        \     map(copy(row), {i,v ->
        \       printf('%-'.maxWidths[i].'s', v)
        \     }),
        \     a:separator)
        \ })
endfunction


function! kite#utils#map_join(list, prop, sep)
  return join(map(copy(a:list), {_,v -> v[a:prop]}), a:sep)
endfunction


function! kite#utils#zip(list1, list2, none)
  let result = []
  let [len1, len2] = [len(a:list1), len(a:list2)]
  for i in range(max([len1, len2]))
    let e = []
    call add(e, i < len1 ? a:list1[i] : a:none)
    call add(e, i < len2 ? a:list2[i] : a:none)
    call add(result, e)
  endfor
  return result
endfunction


" Returns a list of lines, each no longer than length.
" The last line may be longer than length if it has no spaces.
" Assumes str is a constructor or function call.
"
" Example: json.dumps
"
"     dumps(obj, skipkeys, ensure_ascii, check_circular, allow_nan, cls, indent, separators, encoding, default, sort_keys, *args, **kwargs)
"
" - becomes when wrapped:
"
"     dumps(obj, skipkeys, ensure_ascii, check_circular,
"           allow_nan, cls, indent, separators, encoding,
"           default, sort_keys, *args, **kwargs)
"
function! kite#utils#wrap(str, length)
  let lines = []

  let str = a:str
  let [prefix; str] = split(a:str, '(\zs')
  let str = join(str)

  while v:true
    let line = prefix.str

    if len(line) <= a:length
      call add(lines, line)
      break
    endif

    let i = strridx(str[0:a:length-len(prefix)], ' ')

    if i == -1
      call add(lines, line)
      break
    endif

    let line = prefix . str[0:i-1]
    call add(lines, line)
    let str = str[i+1:]

    let prefix = repeat(' ', len(prefix))
  endwhile

  return lines
endfunction


function! kite#utils#coerce(dict, key, default)
  if has_key(a:dict, a:key)
    let v = a:dict[a:key]
    if type(v) == type(a:default)  " check type in case of null
      return v
    endif
  endif
  return a:default
endfunction


function! kite#utils#dig(dict, key, default)
  let dict = a:dict
  for k in split(a:key, '\.')
    if has_key(dict, k)
      let dict = dict[k]
    else
      return a:default
    endif
  endfor
  if type(dict) == type(a:default)  " in case of null
    return dict
  else
    return a:default
  endif
endfunction


function! kite#utils#present(dict, key)
  return has_key(a:dict, a:key) && !empty(a:dict[a:key])
endfunction


function! s:chomp(str)
  return substitute(a:str, '\n$', '', '')
endfunction


function! s:md5(text)
  return s:chomp(system('md5', a:text))
endfunction

function! s:md5sum(text)
  return split(system('md5sum', a:text), ' ')[0]
endfunction

function! s:md5bin(text)
  return s:chomp(system(s:md5_binary, a:text))
endfunction


if executable('md5')
  let s:MD5 = function('s:md5')
elseif executable('md5sum')
  let s:MD5 = function('s:md5sum')
else
  let s:md5_binary = kite#utils#lib('md5Sum.exe')
  let s:MD5 = function('s:md5bin')
endif

