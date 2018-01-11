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


function Test_content_length()
  let text_with_content_length = join([
        \ 'HTTP/1.0 200 OK',
        \ 'Date: Thu, 11 Jan 2018 12:23:11 GMT',
        \ 'Content-Length: 131',
        \ 'Content-Type: text/plain; charset=utf-8',
        \ '',
        \ '{"id":35594,"name":"Joe Bloggs","email":"joe@example.com","bio":"","email_verified":false,"is_internal":false,"unsubscribed":false}'
        \ ], "\r\n")
  call assert_equal(131, kite#client#content_length(text_with_content_length))

  " I don't think we would see an HTTP response without a content length,
  " but just to be on the safe side...
  let text_without_content_length = join([
        \ 'HTTP/1.0 200 OK',
        \ 'Date: Thu, 11 Jan 2018 12:23:11 GMT',
        \ 'Content-Type: text/plain; charset=utf-8',
        \ '',
        \ ], "\r\n")
  call assert_equal(-1, kite#client#content_length(text_without_content_length))
endfunction


function Test_body_length()
  let text_with_non_empty_body = join([
        \ 'HTTP/1.0 200 OK',
        \ 'Date: Thu, 11 Jan 2018 12:23:11 GMT',
        \ 'Content-Length: 131',
        \ 'Content-Type: text/plain; charset=utf-8',
        \ '',
        \ '{"id":35594,"name":"Joe Bloggs","email":"joe@example.com","bio":"","email_verified":false,"is_internal":false,"unsubscribed":false}'
        \ ], "\r\n")
  call assert_equal(131, kite#client#body_length(text_with_non_empty_body))

  let text_with_empty_body = join([
        \ 'HTTP/1.0 200 OK',
        \ 'Date: Thu, 11 Jan 2018 12:23:11 GMT',
        \ 'Content-Length: 0',
        \ 'Content-Type: text/plain; charset=utf-8',
        \ '',
        \ ''
        \ ], "\r\n")
  call assert_equal(0, kite#client#body_length(text_with_empty_body))

  let text_with_no_body = join([
        \ 'HTTP/1.0 200 OK',
        \ 'Date: Thu, 11 Jan 2018 12:23:11 GMT',
        \ 'Content-Length: 0',
        \ 'Content-Type: text/plain; charset=utf-8',
        \ ], "\r\n")
  call assert_equal(-1, kite#client#body_length(text_with_no_body))
endfunction
