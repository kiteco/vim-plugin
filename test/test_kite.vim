function Test_buffer_contents()
  edit hover_example1.py

  let _ff = &ff

  set ff=unix
  call assert_equal("import os\nout = os.path.join(\"abc\", \"def\")\n", kite#utils#buffer_contents())

  set ff=dos
  call assert_equal("import os\r\nout = os.path.join(\"abc\", \"def\")\r\n", kite#utils#buffer_contents())

  let &ff=_ff
endfunction


function Test_selected_region_example1()
  edit hover_example1.py

  " move to start of "os" on first line
  normal 1Gw
  call assert_equal([7, 7], kite#utils#selected_region_characters())
  call assert_equal([7, 7], kite#utils#selected_region_bytes())

  " select "os"
  normal ve
  call assert_equal([7, 9], kite#utils#selected_region_characters())
  call assert_equal([7, 9], kite#utils#selected_region_bytes())
  normal v

  " move to start of "out" on second line
  normal 2G^
  call assert_equal([10, 10], kite#utils#selected_region_characters())
  call assert_equal([10, 10], kite#utils#selected_region_bytes())

  " select "out"
  normal ve
  call assert_equal([10, 13], kite#utils#selected_region_characters())
  call assert_equal([10, 13], kite#utils#selected_region_bytes())
  normal v

  " select "os" on second line
  normal fove
  call assert_equal([16, 18], kite#utils#selected_region_characters())
  call assert_equal([16, 18], kite#utils#selected_region_bytes())
  normal v

  " select "path" on second line
  normal fpve
  call assert_equal([19, 23], kite#utils#selected_region_characters())
  call assert_equal([19, 23], kite#utils#selected_region_bytes())
  normal v

  " select "join" on second line
  normal fjve
  call assert_equal([24, 28], kite#utils#selected_region_characters())
  call assert_equal([24, 28], kite#utils#selected_region_bytes())
  normal v
endfunction


function Test_selected_region_example2()
  edit hover_example2.py

  " select word inside brackets
  normal f(vi)
  call assert_equal([6, 8],  kite#utils#selected_region_characters())
  call assert_equal([6, 12], kite#utils#selected_region_bytes())
endfunction


function Test_columnise()
  let data = [
        \ [ 'a',   'bb', 'ccc'   ],
        \ [ 'aaa', 'b',  'ccccc' ]
        \ ]
  let expected = [
        \ 'a   - bb - ccc  ',
        \ 'aaa - b  - ccccc'
        \ ]
  call assert_equal(expected, kite#utils#columnise(data, ' - '))
endfunction


function Test_map_join()
  let list = [ {'x':42}, {'x': 153} ]
  let expected = '42 - 153'
  call assert_equal(expected, kite#utils#map_join(list, 'x', ' - '))
endfunction


function Test_wrap()
  let str = 'foo(A, quick, brown, fox, jumped, over, the, lazy, dog)'

  let expected = [
        \ 'foo(A, quick, brown,',
        \ '    fox, jumped,',
        \ '    over, the, lazy,',
        \ '    dog)'
        \ ]

  call assert_equal(expected, kite#utils#wrap(str, 20))
endfunction


function Test_zip()
  let a = [1, 2, 3]
  let b = [7, 8, 9]
  let expected = [ [1,7], [2,8], [3,9] ]
  call assert_equal(expected, kite#utils#zip(a, b, ''))

  let a = [1, 2   ]
  let b = [7, 8, 9]
  let expected = [ [1,7], [2,8], ['',9] ]
  call assert_equal(expected, kite#utils#zip(a, b, ''))
endfunction


function Test_token_characters()
  edit hover_example1.py

  " last character of line
  normal 1G$
  call assert_equal([7, 9], kite#utils#token_characters())

  " first character of last word of line
  normal b
  call assert_equal([7, 9], kite#utils#token_characters())
endfunction

