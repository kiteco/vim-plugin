" From https://github.com/tpope/vim-unimpaired.

let s:base64_chars = map(range(char2nr('A'),char2nr('Z')),'nr2char(v:val)')
      \            + map(range(char2nr('a'),char2nr('z')),'nr2char(v:val)')
      \            + map(range(char2nr('0'),char2nr('9')),'nr2char(v:val)')
      \            + ['+','/']

let s:base64_filler = '='
let s:base64_lookup = {}
let s:pos = 0
for s:char in s:base64_chars
  let s:base64_lookup[s:char] = s:pos
  let s:pos += 1
endfor
unlet s:pos

function! kite#base64#encode(str)
  " Respect current file encoding
  let input = a:str
  let encoded = ''
  while len(input) > 2
    let encoded .= s:base64_chars[char2nr(input[0])/4]
          \     .  s:base64_chars[16*(char2nr(input[0])%4 )+char2nr(input[1])/16]
          \     .  s:base64_chars[4 *(char2nr(input[1])%16)+char2nr(input[2])/64]
          \     .  s:base64_chars[char2nr(input[2])%64]
    let input = input[3:]
  endwhile
  if len(input) == 2
    let encoded .= s:base64_chars[char2nr(input[0])/4]
          \     .  s:base64_chars[16*(char2nr(input[0])%4 )+char2nr(input[1])/16]
          \     .  s:base64_chars[4 *(char2nr(input[1])%16)]
          \     .  s:base64_filler
  elseif len(input) == 1
    let encoded .= s:base64_chars[char2nr(input[0])/4]
          \     .  s:base64_chars[16*(char2nr(input[0])%4 )]
          \     .  s:base64_filler
          \     .  s:base64_filler
  endif
  return encoded
endfunction

function! kite#base64#decode(str)
  if len(a:str) % 4 != 0
    return a:str
  endif
  let input = a:str
  let decoded = ''
  while !empty(input)
    let decoded .= nr2char(4 * s:base64_lookup[input[0]] + (s:base64_lookup[input[1]] / 16))
    if input[2] !=# s:base64_filler
      let decoded .= nr2char(16 * (s:base64_lookup[input[1]] % 16) + (s:base64_lookup[input[2]]/4))
      if input[3] !=# s:base64_filler
        let decoded .= nr2char(64 * (s:base64_lookup[input[2]] % 4) + s:base64_lookup[input[3]])
      endif
    endif
    let input = input[4:]
  endwhile
  return decoded
endfunction

