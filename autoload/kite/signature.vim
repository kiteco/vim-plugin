function! kite#signature#handler(response) abort
  if a:response.status != 200
    return []
  endif

  let json = json_decode(a:response.body)
  let call = json.calls[0]
  let [callee, signatures] = [call.callee, call.signatures]
  let function_name = split(callee.repr, '\.')[-1]
  let spacer = {'word': '', 'empty': 1, 'dup': 1}
  let indent = '  '
  let completions = []


  "
  " Signature
  "
  call add(completions, s:heading('Signature'))

  let detail = callee.details.function  " callee.detail is deprecated
  let arguments = []

  if empty(detail)
    call add(arguments, '')

  else
    " https://docs.python.org/3/tutorial/controlflow.html#more-on-defining-functions

    " formal parameters / positional arguments
    if has_key(detail, 'parameters') && type(detail.parameters) == v:t_list
      for parameter in detail.parameters
        call add(arguments, parameter.name)
      endfor
    endif

    " *args (optional positional arguments)
    if has_key(detail, 'vararg') && type(detail.vararg) == v:t_dict
      call add(arguments, '*args')
    endif

    " **kwargs (optional keyword arguments)
    if has_key(detail, 'kwarg') && type(detail.kwarg) == v:t_dict
      call add(arguments, '**kwargs')
    endif
  endif

  " The completion popup does not wrap long lines so we simulate wrapping ourselves.
  "
  " When to wrap?
  "
  " We could calculate when wrapping is necessary and only fake-wrap then.
  " However the calculation is fiddly:
  "
  "     available width = &columns - screencols()  (more or less)
  "     popup width     = 1 space LH margin       +
  "                       width of widest <abbr>  +
  "                       1 space gutter          +
  "                       width of widest <menu>  +
  "                       1 space RH margin
  "     need to wrap    = (popup width > available width)
  "
  " It is much simpler to wrap when the argument list is longer than, say, 40
  " characters.
  "
  " Example: completing json.dumps gives --
  "
  "   default behaviour:
  "
  "     dumps(obj, skipkeys, ensure_ascii, check_circular, allow_nan, cls, indent, separators, encoding, default, sort_keys, *args, **kwargs)
  "
  "   fake wrapping:
  "
  "     dumps(obj, skipkeys, ensure_ascii, check_circular,
  "           allow_nan, cls, indent, separators, encoding,
  "           default, sort_keys, *args, **kwargs)
  "
  let break_after = 40
  let args_string = join(arguments, ', ')
  let first_line = 1
  while v:true
    if first_line
      let prefix = function_name.'('
      let first_line = 0
    else
      let prefix = substitute(function_name, '.', ' ', 'g').' '
    endif

    let i = match(args_string, ' ', break_after)
    if i == -1
      let display = indent . prefix . args_string . ')'
    else
      let display = indent . prefix . args_string[0:i]
      let args_string = args_string[i+1:]
    endif

    let completion = {
          \   'word':  '',
          \   'abbr':  display,
          \   'empty': 1,
          \   'dup':   1
          \ }
    call add(completions, completion)

    if i == -1 | break | endif
  endwhile

  "
  " kwarg details
  "
  if !empty(detail) && has_key(detail, 'kwarg_parameters') && type(detail.kwarg_parameters) == v:t_list
    call add(completions, spacer)
    call add(completions, s:heading('kwargs'))

    for kwarg in detail.kwarg_parameters
      let name = kwarg.name
      if type(kwarg.inferred_value) == v:t_list
        let types = join(map(kwarg.inferred_value, {_,t -> t.repr}), ' | ')
      else
        let types = ''
      endif
      call add(completions, {
            \   'word':  name.'=',
            \   'abbr':  indent.name,
            \   'menu':  types,
            \   'empty': 1,
            \   'dup':   1
            \ })
    endfor
  endif


  "
  " Popular patterns
  "
  if len(signatures) > 0
    call add(completions, spacer)
    call add(completions, s:heading('Popular Patterns'))
  endif

  for signature in signatures
    let arguments = []

    if type(signature.args) == v:t_list
      for arg in signature.args
        call add(arguments, arg.name)
      endfor
    endif

    if type(signature.kwargs) == v:t_list
      for kwarg in signature.kwargs
        call add(arguments, kwarg.name.'='.join(map(kwarg.types, {_,t -> t.name}), '|'))
      endfor
    endif

    " E.g. math.sin()
    if empty(signature.args) && empty(signature.kwargs)
      call add(arguments, '')
    endif

    let args_string = join(arguments, ', ')
    let completion = {
          \   'word':  '',
          \   'abbr':  indent.function_name.'('.args_string.')',
          \   'empty': 1,
          \   'dup':   1
          \ }
    call add(completions, completion)
  endfor

  return completions
endfunction


function s:heading(text)
  return {'abbr': a:text.':', 'word': '', 'empty': 1, 'dup': 1}
endfunction

