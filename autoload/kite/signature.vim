function! kite#signature#handler(response) abort
  call kite#utils#log('signature: '.a:response.status)
  if a:response.status != 200
    return []
  endif

  let json = json_decode(a:response.body)
  let call = g:kite#document#Document.New(json.calls[0])
  let function_name = split(call.dig('callee.repr', ''), '\.')[-1]
  let spacer = {'word': '', 'empty': 1, 'dup': 1}
  let indent = '  '
  let completions = []
  let wrap_width = 50


  "
  " Signature
  "
  call add(completions, s:heading('Signature'))

  let parameters = []

  if empty(call.dig('callee.details.function', {}))
    call add(parameters, '')

  else
    " 1. Name of function with parameters.
    let [current_arg, in_kwargs] = [call.dig('arg_index', 0), call.dig('language_details.python.in_kwargs', 0)]

    " 1.b Parameters
    for parameter in call.dig('callee.details.function.parameters', [])
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
    let vararg = call.dig('callee.details.function.language_details.python.vararg', {})
    if !empty(vararg)
      call add(parameters, '*'.vararg.name)
    endif

    " iii. keyword arguments indicator
    let kwarg = call.dig('callee.details.function.language_details.python.kwarg', {})
    if !empty(kwarg)
      call add(parameters, '**'.kwarg.name)
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
  let kwarg_parameters = call.dig('callee.details.function.kwarg_parameters', [])
  if !empty(kwarg_parameters)
    call add(completions, spacer)
    call add(completions, s:heading('**kw'))

    for kwarg in kwarg_parameters
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
  if kite#plan#is_pro()
    let signatures = call.dig('signatures', [])
    if len(signatures) > 0
      call add(completions, spacer)
      call add(completions, s:heading('How Others Used This'))
    endif

    for signature in signatures
      let sigdoc = g:kite#document#Document.New(signature)

      " b. Arguments
      let arguments = []
      for arg in sigdoc.dig('args', [])
        call add(arguments, arg.name)
      endfor

      " c. Keyword arguments
      for kwarg in sigdoc.dig('language_details.python.kwargs', [])
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
  endif

  return completions
endfunction


function s:heading(text)
  return {'abbr': a:text.':', 'word': '', 'empty': 1, 'dup': 1}
endfunction
