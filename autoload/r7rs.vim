" Helper functions for r7rs-syntax plugin
" Last Change: 2020-07-01
" Author: Mitsuhiro Nakamura <m.nacamura@gmail.com>
" URL: https://github.com/mnacamura/vim-r7rs-syntax
" License: MIT

" Get value from a buffer-local or global variable with fall back
fun! r7rs#Get(varname, default) abort
  let l:prefixed_varname = 'r7rs_' . a:varname
  return get(b:, l:prefixed_varname, get(g:, l:prefixed_varname, a:default))
endfun
