if exists('b:current_syntax')
  finish
endif


" Section headings
syntax match kiteHeading /\v^\u+$/
highlight link kiteHeading String


" Usages / Definitions
syntax include @python syntax/python.vim
syntax region kiteSnippet start=/\v^\[.+:\d+\]/ end=/$/ keepend contains=kiteRef,kiteCode
syntax match kiteRef /\v^\[.+:\d+\]/ contained
syntax region kiteCode start=/ / end=/$/ contains=@python contained
highlight link kiteRef Comment


" Links
syntax match kiteDomain /\v\([^. ]+\.\w{2,3}\)/
highlight link kiteDomain Comment


let b:current_syntax = 'kite'

