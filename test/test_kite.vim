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

