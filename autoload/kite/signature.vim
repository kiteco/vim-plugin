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

  if type(detail) == v:t_none
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

  let args_string = join(arguments, ', ')
  let completion = {
        \   'word':  '',
        \   'abbr':  indent.function_name.'('.args_string.')',
        \   'empty': 1,
        \   'dup':   1
        \ }
  call add(completions, completion)

  "
  " kwarg details
  "
  if type(detail) != v:t_none && has_key(detail, 'kwarg_parameters') && type(detail.kwarg_parameters) == v:t_list
    call add(completions, spacer)
    call add(completions, s:heading('kwargs'))

    for kwarg in detail.kwarg_parameters
      let name = kwarg.name
      let types = map(kwarg.inferred_value, {_,t -> t.repr})
      call add(completions, {
            \   'word':  name.'=',
            \   'abbr':  indent.name,
            \   'menu':  join(types, ' | '),
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
    if type(signature.args) == v:t_none && type(signature.kwargs) == v:t_none
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

