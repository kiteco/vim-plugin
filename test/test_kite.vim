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


function Test_goto_character()
  " unix line endings
  set ff=unix

  %d _
  normal iimport json
  normal ojson
  normal oimport

  call kite#utils#goto_character(1)  " first line: i
  call assert_equal(1, wordcount().cursor_chars)

  call kite#utils#goto_character(8)  " first line: j
  call assert_equal(8, wordcount().cursor_chars)

  call kite#utils#goto_character(12)  " first line: newline
  call assert_equal(11, wordcount().cursor_chars)  " first line: n

  call kite#utils#goto_character(20)  " third line: p
  call assert_equal(20, wordcount().cursor_chars)

  " dos line endings
  set ff=dos

  %d _
  normal iimport json
  normal ojson
  normal oimport

  call kite#utils#goto_character(1)  " first line: i
  call assert_equal(1, wordcount().cursor_chars)

  call kite#utils#goto_character(8)  " first line: j
  call assert_equal(8, wordcount().cursor_chars)

  call kite#utils#goto_character(12)  " first line: newline first char
  call assert_equal(11, wordcount().cursor_chars)  " first line: n
  call kite#utils#goto_character(13)  " first line: newline second char
  call assert_equal(11, wordcount().cursor_chars)  " first line: n

  call kite#utils#goto_character(20)  " third line: i
  call assert_equal(20, wordcount().cursor_chars)

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

  call assert_equal(expected, kite#utils#wrap(str, 20, 4))
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


function Test_normalise_version()
  " vim
  let version_str = join([
        \   'VIM - Vi IMproved 8.0 (2016 Sep 12, compiled Aug 17 2018 17:24:51)',
        \   'Included patches: 1-503, 505-680, 682-1283',
        \   'Compiled by root@apple.com',
        \ ], "\n")
  call assert_equal('8.0.1-503,505-680,682-1283', kite#utils#normalise_version(version_str))

  " macvim
  let version_str = join([
        \   'VIM - Vi IMproved 8.1 (2018 May 18, compiled Jan 28 2019 11:54:37)',
        \   'macOS version',
        \   'Included patches: 1-822',
        \   'Compiled by Homebrew',
        \ ], "\n")
  call assert_equal('8.1.1-822', kite#utils#normalise_version(version_str))

  " gvim
  let version_str = join([
        \   'VIM - Vi IMproved 8.1 (2018 May 18, compiled May 18 2019 18:36:07)',
        \   'MS-Windows 32-bit GUI version with OLE support',
        \   'Included patches: 1',
        \   'Compiled by mool@tororo',
        \ ], "\n")
  call assert_equal('8.1.1', kite#utils#normalise_version(version_str))

  " windows
  let version_str = join([
        \ 'VIM - Vi IMproved 8.2 (2019 Dec 12, compiled Dec 12 2019 13:19:27)',
        \ 'MS-Windows 32-bit console version',
        \ 'Compiled by mool@tororo',
        \ ], "\n")
  call assert_equal('8.2.0', kite#utils#normalise_version(version_str))

  " german
  let version_str = join([
        \   'VIM - Vi IMproved 8.1 (2018 May 18 kompiliert am Feb 11 2019 00:14:42)',
        \   'MS-Windows 32 Bit GUI Version mit OLE-Unterstützung',
        \   'Inklusive der Patches: 1-895',
        \   'Übersetzt von appveyor@APPVYR-WIN'
        \ ], "\n")
  call assert_equal('8.1.1-895', kite#utils#normalise_version(version_str))

  " neovim
  let version_str = join([
        \ 'NVIM v0.2.2',
        \ 'Build type: Release',
        \ ], "\n")
  call assert_equal('NVIM v0.2.2', kite#utils#normalise_version(version_str))
endfunction


function Test_ralign()
  " No room
  call assert_equal('', kite#utils#ralign('foobar', 0))
  call assert_equal('', kite#utils#ralign('foobar', -1))

  " The required length
  call assert_equal('foobar', kite#utils#ralign('foobar', 6))

  " Less than the required length
  call assert_equal('   foobar', kite#utils#ralign('foobar', 9))

  " Greater than the required length
  if kite#utils#windows()
    call assert_equal('fo...', kite#utils#ralign('foobar', 5))
    call assert_equal('   ', kite#utils#ralign('foobar', 3))
    call assert_equal('  ', kite#utils#ralign('foobar', 2))
    call assert_equal(' ', kite#utils#ralign('foobar', 1))
  else
    call assert_equal('foob…', kite#utils#ralign('foobar', 5))
    call assert_equal('fo…', kite#utils#ralign('foobar', 3))
    call assert_equal('f…', kite#utils#ralign('foobar', 2))
    call assert_equal(' ', kite#utils#ralign('foobar', 1))
  endif
endfunction


function Test_truncate()
  " Enough room
  call assert_equal('foobar', kite#utils#truncate('foobar', 10))
  call assert_equal('foobar', kite#utils#truncate('foobar', 6))

  " Not enough room
  if kite#utils#windows()
    call assert_equal('fo...', kite#utils#truncate('foobar', 5))
    call assert_equal('f...', kite#utils#truncate('foobar', 4))
    call assert_equal('f..', kite#utils#truncate('foobar', 3))
    call assert_equal('f.', kite#utils#truncate('foobar', 2))
  else
    call assert_equal('foob…', kite#utils#truncate('foobar', 5))
    call assert_equal('foo…', kite#utils#truncate('foobar', 4))
    call assert_equal('fo…', kite#utils#truncate('foobar', 3))
    call assert_equal('f…', kite#utils#truncate('foobar', 2))
  endif
endfunction
