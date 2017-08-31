if exists('b:current_syntax')
  finish
endif


" Section headings
syntax match kiteHeading /\v^\u+$/
highlight link kiteHeading String


" Usages / Definitions
syntax include @python syntax/python.vim
syntax region kSnippet start=/\v^\[.+:\d+\]/ end=/$/ keepend contains=kRef,kCode
syntax match kRef /\v^\[.+:\d+\]/ contained
syntax region kCode start=/ / end=/$/ contains=@python contained
highlight link kRef Comment


" Links
syntax match kiteDomain /\v\([^. ]+\.\w{2,3}\)/
highlight link kiteDomain Comment


let b:current_syntax = 'kite'

