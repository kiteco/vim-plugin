" These names are pretend filenames and must not contain whitespace.
" Assumes one name is not a substring of the other.
let s:kite_window = '\[Kite\]'
let s:kite_examples_window = '\[Kite__Example\]'


function! kite#hover#hover()
  if b:kite_skip | return | endif
  if wordcount().bytes > kite#max_file_size() | return | endif

  let filename = kite#utils#filepath(1)
  let hash = kite#utils#buffer_md5()
  let cursor = kite#utils#cursor_characters()

  call kite#metrics#requested('expand_panel')
  call kite#client#hover(filename, hash, cursor, function('kite#hover#handler'))
endfunction


function! kite#hover#handler(response)
  call kite#utils#log('hover: '.a:response.status)
  if a:response.status != 200 | return | endif
  call kite#metrics#fulfilled('expand_panel')

  let json = json_decode(a:response.body)

  let sym = type(json.symbol) == v:t_list ? json.symbol[0] : json.symbol
  let symbol = g:kite#document#Document.New(sym)

  let report = json.report

  call s:openKiteWindow()
  silent %d _

  let s:clickables = {}
  let kind = symbol.dig('value[0].kind', '')
  let winwidth = winwidth(0) - 8  " subtract a safe 8 for sign column, line number columns, fold column.

  if kind ==# 'function'

    " 1. Name of function with parameters.  Label: "function"

    " a. Name
    let name = symbol.dig('value[0].repr', '')
    " b. Parameters
    let parameters = []
    for parameter in symbol.dig('value[0].details.function.parameters', [])
      " i. name
      call add(parameters, parameter.name)
    endfor
    " ii. vararg indicator
    let v = symbol.dig('value[0].details.function.language_details.python.vararg.name', '')
    if v != ''
      call add(parameters, '*'.v)
    endif
    " iii. keyword arguments indicator
    let v = symbol.dig('value[0].details.function.language_details.python.kwarg.name', '')
    if v != ''
      call add(parameters, '**'.v)
    endif
    let fn_name = name.'('.join(parameters, ', ').')'
    " c. Label 'function'
    let label = symbol.dig('value[0].kind', '')

    let padding = '    '
    let left_width = winwidth - len(label) - len(padding)
    let left_lines = kite#utils#wrap(fn_name, left_width)
    let masthead = kite#utils#zip(left_lines, [label], '')
    call s:section(kite#utils#columnise(masthead, padding), 1)


    " 2. Function's popular patterns

    let patterns = []
    for signature in symbol.dig('value[0].details.function.signatures', [])
      let sigdoc = g:kite#document#Document.New(signature)
      " i. name of function
      let name = symbol.dig('name', '')
      " ii. arguments
      let arguments = map(copy(sigdoc.dig('args', [])), {_,v -> v.name})
      " iii. keyword arguments
      for kwarg in sigdoc.dig('language_details.python.kwargs', [])
        call add(arguments, kwarg.name.'='.join(map(filter(copy(kwarg.types), '!empty(v:val.examples)'), {_,v -> v.examples[0]}), '|'))
      endfor
      call add(patterns, name.'('.join(arguments, ', ').')')
    endfor
    if !empty(patterns)
      call s:section('HOW OTHERS USED THIS')
      call s:content(patterns)
    endif


    " 3. Parameters and their types.

    let parameters = []
    for parameter in symbol.dig('value[0].details.function.parameters', [])
      let paramdoc = g:kite#document#Document.New(parameter)
      " i. name; ii. types
      call add(parameters, [parameter.name, kite#utils#map_join(paramdoc.dig('inferred_value', []), 'repr', ' | ')])
    endfor
    if !empty(parameters)
      call s:section('PARAMETERS')
      call s:content(kite#utils#columnise(parameters, '    '))
    endif


    " 4. Keyword arguments

    let kwargs = []
    for kwarg in symbol.dig('value[0].details.function.language_details.python.kwarg_parameters', [])
      let kwargdoc = g:kite#document#Document.New(kwarg)
      " i. name; ii. types
      call add(kwargs, [kwarg.name, kite#utils#map_join(kwargdoc.dig('inferred_value', []),'repr', ' | ')])
    endfor
    if !empty(kwargs)
      call s:section('KEYWORD ARGUMENTS')
      call s:content(kite#utils#columnise(kwargs, '    '))
    endif


    " 5. Returns
    let returns = kite#utils#map_join(symbol.dig('value[0].details.function.return_value', []), 'repr', ' | ')
    if !empty(returns)
      call s:section('RETURNS')
      call s:content(returns)
    endif


  elseif kind ==# 'module'
    " 1. Name of module.  Label: "module"

    " a. Name
    let name = symbol.dig('value[0].repr', '')
    " b. Label
    let label = symbol.dig('value[0].kind', '')

    let padding = winwidth - len(name) - len(label)
    call s:section(kite#utils#columnise([[name, label]], repeat(' ', padding)), 1)

    " 2. Top members

    " a.i, a.ii
    let members = map(copy(symbol.dig('value[0].details.module.members', [])), {_,v -> [v.name, v.value[0].kind]})
    if !empty(members)
      call s:section('POPULAR MEMBERS')
      let members_with_types = kite#utils#columnise(members, '    ')
      let i = 0
      let module = symbol.dig('value[0].details.module', {})
      for line in members_with_types
        call s:content(line)
        let s:clickables[line('$')] = {
              \   'type': 'symbol_report',
              \   'id': module.members[i].id
              \ }
        let i += 1
      endfor
    endif

  elseif kind ==# 'type'
    " 1. Name of type.  Label: type

    " a. Name
    let name = symbol.dig('value[0].repr', '')
    " b. Label
    let label = symbol.dig('value[0].kind', '')
    " c. Constructor
    let parameters = []
    let constructor = symbol.dig('value[0].details.type.language_details.python.constructor', {})
    if !empty(constructor)
      let condoc = g:kite#document#Document.New(constructor)
      " i. Parameters
      let parameters = map(copy(condoc.dig('parameters', [])), {_,v -> v.name})
      " ii. Vararg indicator
      let v = condoc.dig('language_details.python.vararg.name', '')
      if v != ''
        call add(parameters, '*'.v)
      endif
      " iii. Keyword arguments indicator
      let v = condoc.dig('language_details.python.kwarg.name', '')
      if v != ''
        call add(parameters, '**'.v)
      endif
    endif

    let fn_name = name.'('.join(parameters, ', ').')'
    let padding = '    '
    let left_width = winwidth - len(label) - len(padding)
    let left_lines = kite#utils#wrap(fn_name, left_width)
    let masthead = kite#utils#zip(left_lines, [label], '')
    call s:section(kite#utils#columnise(masthead, padding), 1)

    " 2. Popular constructor patterns


    let constructor = symbol.dig('value[0].details.type.language_details.python.constructor', {})
    if !empty(constructor)
      if len(constructor.signatures) > 0
        call s:section('POPULAR CONSTRUCTOR PATTERNS')
      endif

      " a. Popular pattern
      for signature in constructor.signatures
        let sigdoc = g:kite#document#Document.New(signature)

        let arguments = []
        " i. Name of function
        let name = symbol.dig('name', '')
        " ii. Arguments
        call add(arguments, signature.args)
        " iii. Keyword arguments
        let kwargs = sigdoc.dig('language_details.python.kwargs', [])
        if !empty(kwargs)
          call add(arguments, map(copy(kwargs), {_,v -> v.name.'='.kite#utils#coerce(v.types[0], 'examples', [''])[0]}))
        endif

        call s:content(name.'('.join(arguments, ', ').')')
      endfor
    endif

    " 3. Constructor parameters

    let constructor = symbol.dig('value[0].details.type.language_details.python.constructor', {})
    if !empty(constructor)
      let condoc = g:kite#document#Document.New(constructor)
      " a. Parameters
      let parameters = []
      for parameter in condoc.dig('language_details.parameters', [])
        " i. Name, ii. Type
        call add(parameters, [parameter.name, kite#utils#map_join(kite#utils#coerce(parameter, 'inferred_value', []), 'repr', ' | ')])
      endfor
      if !empty(parameters)
        call s:section('CONSTRUCTOR PARAMETERS')
        call s:content(kite#utils#columnise(parameters, '    '))
      endif
    endif

    " 4. Constructor **kwargs

    let constructor = symbol.dig('value[0].details.type.language_details.python.constructor', {})
    if !empty(constructor)
      let condoc = g:kite#document#Document.New(constructor)
      " a. Kwarg
      let parameters = []
      for parameter in condoc.dig('language_details.python.kwarg_parameters', [])
        " i. Name, ii. Type
        call add(parameters, [parameter.name, kite#utils#map_join(kite#utils#coerce(parameter, 'inferred_value', []), 'repr', ' | ')])
      endfor
      if !empty(parameters)
        call s:section('CONSTRUCTOR **KWARGS')
        call s:content(kite#utils#columnise(parameters, '    '))
      endif
    endif

    " 5. Top attributes

    " a. Member
    " i. Name, ii. Id
    let members = symbol.dig('value[0].details.type.members', [])
    if !empty(members)
      let members_with_kind = map(copy(members), {_,v -> [v.name, !empty(v.value) ? v.value[0].kind : '']})
      call s:section('POPULAR MEMBERS')
      let members_with_types = kite#utils#columnise(members_with_kind, '    ')
      let i = 0
      for line in members_with_types
        call s:content(line)

        let s:clickables[line('$')] = {
              \   'type': 'symbol_report',
              \   'id': members[i].id
              \ }
        let i += 1
      endfor
    endif


  elseif kind ==# 'instance'
    " 1. Name of instance.  Label: {type of instance}

    " a. Name
    let name = symbol.dig('value[0].repr', '')
    " b. Type
    let type = symbol.dig('value[0].type', '')

    let padding = winwidth - len(name) - len(type)
    call s:section(kite#utils#columnise([[name, type]], repeat(' ', padding)), 1)

    " 2. Top members of type
    " TBD in spec

  endif



  call s:section('DESCRIPTION')
  " Handle embedded line breaks.
  call s:content(split(report.description_text, "\n"))

  if !empty(symbol)
    call s:content('')
    call s:content('-> Online documentation')
    let s:clickables[line('$')] = {
          \   'type': 'doc',
          \   'id': symbol.dig('value[0].id', '')
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


  if !empty(report.examples)
    call s:section('HOW TO')
    for example in report.examples
      call s:content('-> '.example.title)
      let s:clickables[line('$')] = {
            \   'type': 'example',
            \   'id': example.id
            \ }
    endfor
  endif


  let report_doc = g:kite#document#Document.New(report)
  let [filename, line] = [report_doc.dig('definition.filename', ''), report_doc.dig('definition.line', '')]
  if !empty(filename)
    call s:section('DEFINITION')
    call s:content(fnamemodify(filename, ':t').':'.line)
    let s:clickables[line('$')] = {
          \   'type': 'jump',
          \   'file': filename,
          \   'line': line
          \ }
  endif


  " The noautocmd doesn't appear to have any effect (vim/vim#2084).
  noautocmd wincmd p
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

  " Use the sign column as a margin between the window divider and our content.
  if exists('&signcolumn')
    set signcolumn=yes
  else
    sign define KiteDummy
    execute 'sign place 42 line=9999 name=KiteDummy buffer='.bufnr('%')
  endif

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
    elseif clickable.type == 'symbol_report'
      call kite#report#symbol_report(clickable.id)
    endif
  endif
endfunction


" Optional argument is zero-based byte offset into file.
function! s:show_code(file, line, ...)
  call kite#metrics#requested('usage')

  if g:kite_preview_code
    silent! noautocmd wincmd P
    if !&previewwindow
      noautocmd execute 'botright' &previewheight 'new'
      set previewwindow
      setlocal buftype=nofile bufhidden=wipe noswapfile
      set ft=python
    endif
    silent %d _

    let lines_of_context = 3

    let first = a:line - 1 - lines_of_context
    if first < 0 | let first = 0 | endif

    let last = a:line - 1 + lines_of_context

    0put =readfile(a:file)[first : last]
    "
    " See :help CursorHold-example for how to highlight the
    " matching line in the preview window.

    " The noautocmd doesn't appear to have any effect (vim/vim#2084).
    noautocmd wincmd p

  else
    execute 'noautocmd keepjumps keepalt '.bufwinnr(t:source_buffer).'wincmd w'
    if a:0
      if a:file !=? expand('%:p')
        execute 'hide edit' a:file
      endif
      execute (a:1 + 1).'go'
    else
      if a:file !=? expand('%:p')
        execute 'hide edit +'.a:line a:file
      else
        execute a:line
      endif
    endif
  endif

  call kite#metrics#fulfilled('usage')
endfunction


function! s:show_example(id)
  call kite#metrics#requested('code_example')
  let code = kite#client#example(a:id, function('kite#example#handler'))
  call s:openKiteExamplesWindow()
  silent %d _
  call append(0, code)
endfunction


" Optional arg: truthy to indicate first section.
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
