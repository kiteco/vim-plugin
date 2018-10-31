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


function Test_cursor_characters()
  edit hover_example1.py

  normal 2Gfj
  call assert_equal(24, kite#utils#cursor_characters())

  normal v
  call assert_equal(24, kite#utils#cursor_characters())
  call assert_equal('v', mode())

  normal e
  call assert_equal(27, kite#utils#cursor_characters())
  call assert_equal('v', mode())
endfunction


function Test_character_offset()
  func ExitInsert(timer)
    let g:offset = kite#utils#character_offset()
    call feedkeys("\<Esc>", "t")
  endfunc

  enew

  " unix line endings
  set ff=unix

  " <newline><cursor>
  normal o
  call assert_equal(1, kite#utils#character_offset())

  " <cursor>json.
  %d _
  normal ijson.
  normal 0
  call assert_equal(0, kite#utils#character_offset())

  " j<cursor>son.
  %d _
  normal ijson.
  normal 0l
  call assert_equal(1, kite#utils#character_offset())

  " j.<cursor>
  " It's only possible to position the cursor after the . in insert mode.
  %d _
  call timer_start(100, 'ExitInsert')
  call feedkeys("ij.", "xt!")
  call assert_equal(2, g:offset)

  " import json<newline>json.<cursor>
  " It's only possible to position the cursor after the . in insert mode.
  %d _
  normal iimport json
  normal ojson
  call timer_start(100, 'ExitInsert')
  call feedkeys("A.", "xt!")
  call assert_equal(17, g:offset)

  " dos line endings
  set ff=dos

  " <newline><cursor>
  %d _
  normal o
  call assert_equal(2, kite#utils#character_offset())

  " <cursor>json.
  %d _
  normal ijson.
  normal 0
  call assert_equal(0, kite#utils#character_offset())

  " j<cursor>son.
  %d _
  normal ijson.
  normal 0l
  call assert_equal(1, kite#utils#character_offset())

  " j.<cursor>
  " It's only possible to position the cursor after the . in insert mode.
  %d _
  call timer_start(100, 'ExitInsert')
  call feedkeys("ij.", "xt!")
  call assert_equal(2, g:offset)

  " import json<newline>json.<cursor>
  " It's only possible to position the cursor after the . in insert mode.
  %d _
  normal iimport json
  normal ojson
  call timer_start(100, 'ExitInsert')
  call feedkeys("A.", "xt!")
  call assert_equal(18, g:offset)

  " Tidy up.
  bdelete!
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


function Test_document()
  let doc = g:kite#document#Document.New({'x': 42, 'y': ['a', 'b', {'c': [153]}], 'z': v:t_none})

  " number value
  call assert_equal(42, doc.dig('x', -1))
  " list value
  call assert_equal(['a', 'b', {'c': [153]}], doc.dig('y', []))
  " list access
  call assert_equal({'c': [153]}, doc.dig('y[-1]', {}))
  " nested list access
  call assert_equal(153, doc.dig('y[-1].c[0]', 0))

  " unknown key
  call assert_equal(-1, doc.dig('a', -1))
  " non-existent index
  call assert_equal({}, doc.dig('y[5]', {}))
  " wrong type
  call assert_equal('', doc.dig('x', ''))
  " none
  call assert_equal([], doc.dig('z.foo', []))
endfunction
