" These names are pretend filenames and must not contain whitespace.
" Assumes one name is not a substring of the other.
let s:kite_window = '\[Kite\]'
let s:kite_examples_window = '\[Kite__Example\]'


function! kite#hover#hover()
  if wordcount().bytes > kite#max_file_size() | return | endif

  let filename = kite#utils#filepath(1)
  let hash = kite#utils#buffer_md5()
  let [token_start, token_end] = kite#utils#token_characters()
  if [token_start, token_end] == [-1, -1] | return | endif

  call kite#client#hover(filename, hash, token_start, token_end, function('kite#hover#handler'))
endfunction


function! kite#hover#handler(response)
  if a:response.status != 200 | return | endif

  let json = json_decode(a:response.body)
  let report = json.report

  if exists('g:kite_documentation') && g:kite_documentation ==? 'window'
    call s:openKiteWindow()

    normal! gg"_dG

    let s:clickables = {}

    call s:section('DESCRIPTION', 1)
    " Handle embedded line breaks.
    call s:content(split(report.description_text, "\n"))

    if !empty(json.symbol)
      call s:content('')
      call s:content('-> Online documentation')
      let s:clickables[line('$')] = {
            \   'type': 'doc',
            \   'id': json.symbol[0].value[0].id
            \ }
    endif


    if !empty(report.examples)
      call s:section('EXAMPLES')
      for example in report.examples
        call s:content('-> '.example.title)
        let s:clickables[line('$')] = {
              \   'type': 'example',
              \   'id': example.id
              \ }
      endfor
    endif


    if !empty(report.definition)
      call s:section('DEFINITION')
      call s:content(fnamemodify(report.definition.filename, ':t').':'.report.definition.line)
      let s:clickables[line('$')] = {
            \   'type': 'jump',
            \   'file': report.definition.filename,
            \   'line': report.definition.line
            \ }
    endif


    if !empty(report.usages)
      call s:section('USAGES')
      for usage in report.usages
        let location = fnamemodify(usage.filename, ':t').':'.usage.line
        let code = substitute(usage.code, '\v^\s+', '', 'g')
        call s:content('['.location.'] '.code)
        let s:clickables[line('$')] = {
              \   'type': 'jump',
              \   'file': usage.filename,
              \   'line': usage.line,
              \   'byte': usage.begin_runes
              \ }
      endfor
    endif


    if !empty(report.links)
      call s:section('LINKS')
      for link in report.links
        let domain = matchlist(link.url, '\vhttps?://([^/]+)/')[1]
        call s:content('-> '.link.title .' ('.domain.')')
        let s:clickables[line('$')] = {
              \   'type': 'link',
              \   'url': link.url
              \ }
      endfor
    endif


    wincmd p
  else
    echo report.description_text
  endif

endfunction


function! s:openKiteWindow()
  let t:source_buffer = bufnr('%')
  let win = bufwinnr(s:kite_window)
  if win != -1
    execute 'keepjumps keepalt '.win.'wincmd w'
  else
    call s:setupKiteWindow()
  endif
endfunction


function! s:setupKiteWindow()
  if bufwinnr(s:kite_examples_window) == -1
    silent execute 'keepjumps keepalt vertical botright split '.s:kite_window
  else
    call s:openKiteExamplesWindow()
    silent execute 'keepjumps keepalt above split '.s:kite_window
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  set filetype=kite

  nmap <buffer> <silent> <CR> :call <SID>handle_click()<CR>
endfunction


function! s:openKiteExamplesWindow()
  let win = bufwinnr(s:kite_examples_window)
  if win != -1
    execute 'keepjumps keepalt '.win.'wincmd w'
  else
    call s:setupKiteExamplesWindow()
  endif
endfunction


function! s:setupKiteExamplesWindow()
  silent execute 'keepjumps keepalt below new '.s:kite_examples_window
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  set ft=python
endfunction


function! s:handle_click()
  let lnum = line('.')
  if has_key(s:clickables, lnum)
    let clickable = s:clickables[lnum]
    if clickable.type == 'example'
      call s:show_example(clickable.id)
    elseif clickable.type == 'link'
      call kite#utils#browse(clickable.url)
    elseif clickable.type == 'doc'
      call kite#client#webapp_link(clickable.id)
    elseif clickable.type == 'jump'
      if has_key(clickable, 'byte')
        call s:show_code(clickable.file, clickable.line, clickable.byte)
      else
        call s:show_code(clickable.file, clickable.line)
      endif
    endif
  endif
endfunction


" Optional argument is zero-based byte offset into file.
function! s:show_code(file, line, ...)
  if g:kite_preview_code
    silent! wincmd P
    if !&previewwindow
      noautocmd execute 'botright' &previewheight 'new'
      set previewwindow
      setlocal buftype=nofile bufhidden=wipe noswapfile
      set ft=python
    endif
    normal! gg"_dG

    let lines_of_context = 3

    let first = a:line - 1 - lines_of_context
    if first < 0 | let first = 0 | endif

    let last = a:line - 1 + lines_of_context

    0put =readfile(a:file)[first : last]

    wincmd p

  else
    execute 'keepjumps keepalt '.bufwinnr(t:source_buffer).'wincmd w'
    if a:0
      execute 'edit' a:file
      execute (a:1 + 1).'go'
    else
      execute 'edit +'.a:line a:file
    endif
  endif
endfunction


function! s:show_example(id)
  let code = kite#client#example(a:id, function('kite#example#handler'))
  call s:openKiteExamplesWindow()
  normal! gg"_dG
  call append(0, code)
endfunction


function! s:section(title, ...)
  if a:0
    call append(0, a:title)
  else
    call append(line('$'), ['', '', a:title, ''])
  endif
endfunction

function! s:content(text)
  call append(line('$'), a:text)
endfunction
