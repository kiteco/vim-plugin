function! kite#signature#handler(response) abort
  call kite#utils#log('signature: '.a:response.status)
  if a:response.status != 200
    return []
  endif

  let json = json_decode(a:response.body)
  let call = json.calls[0]
  let function_name = split(call.callee.repr, '\.')[-1]
  let spacer = {'word': '', 'empty': 1, 'dup': 1}
  let indent = '  '
  let completions = []
  let wrap_width = 50


  "
  " Signature
  "
  call add(completions, s:heading('Signature'))

  let fn = call.callee.details.function
  let parameters = []

  if empty(fn)
    call add(parameters, '')

  else
    " 1. Name of function with parameters.
    let parameters = []
    let [current_arg, in_kwargs] = [call.arg_index, call.language_details.python.in_kwargs]

    " 1.b Parameters
    for parameter in kite#utils#dig(call.callee.details.function, 'parameters', [])
      " i. Parameter
      let name = parameter.name
      if kite#utils#present(parameter.language_details.python, 'default_value')
        let name .= '='.parameter.language_details.python.default_value[0].repr
      endif
      " 2. Highlight current argument
      if !in_kwargs && len(parameters) == current_arg
        let name = '*'.name.'*'
      endif
      call add(parameters, name)
    endfor

    " ii. vararg indicator
    if kite#utils#present(call.callee.details.function.language_details.python, 'vararg')
      call add(parameters, '*'.call.callee.details.function.language_details.python.vararg.name)
    endif

    " iii. keyword arguments indicator
    if kite#utils#present(call.callee.details.function.language_details.python, 'kwarg')
      call add(parameters, '**'.call.callee.details.function.language_details.python.kwarg.name)
    endif
  endif

  " The completion popup does not wrap long lines so we wrap manually.
  for line in kite#utils#wrap(function_name.'('.join(parameters, ', ').')', wrap_width)
    let completion = {
          \   'word':  '',
          \   'abbr':  indent.line,
          \   'empty': 1,
          \   'dup':   1
          \ }
    call add(completions, completion)
  endfor


  " 3. Keyword arguments
  if !empty(fn) && has_key(fn, 'kwarg_parameters') && type(fn.kwarg_parameters) == v:t_list
    call add(completions, spacer)
    call add(completions, s:heading('**kw'))

    for kwarg in call.callee.details.function.kwarg_parameters
      let name = kwarg.name
      let types = kite#utils#map_join(kwarg.inferred_value, 'repr', '|')
      if empty(types)
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


  " 4. Popular patterns
  let signatures = call.signatures
  if len(signatures) > 0
    call add(completions, spacer)
    call add(completions, s:heading('Popular Patterns'))
  endif

  for signature in signatures

    " b. Arguments
    let arguments = []
    for arg in kite#utils#coerce(signature, 'args', [])
      call add(arguments, arg.name)
    endfor

    " c. Keyword arguments
    for kwarg in kite#utils#coerce(signature.language_details.python, 'kwargs', [])
      let name = kwarg.name
      let examples = kite#utils#coerce(kwarg.types[0], 'examples', [])
      if len(examples) > 0
        let name .= '='.examples[0]
      endif
      call add(arguments, name)
    endfor


    for line in kite#utils#wrap(function_name.'('.join(arguments, ', ').')', wrap_width)
      let completion = {
            \   'word':  '',
            \   'abbr':  indent.line,
            \   'empty': 1,
            \   'dup':   1
            \ }
      call add(completions, completion)
    endfor
  endfor

  return completions
endfunction


function s:heading(text)
  return {'abbr': a:text.':', 'word': '', 'empty': 1, 'dup': 1}
endfunction

