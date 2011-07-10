" Utilities for buffer.

let s:save_cpo = &cpo
set cpo&vim


let s:Functor = {}
function! s:_vital_loaded(V)
    PP! ['s:_vital_loaded()', a:V]
    let s:Functor = a:V.import('Functor')
endfunction


function! s:functor()
    return s:Functor
endfunction
function! s:get_foo()
    return s:Functor.localfunc('__foo', s:__SID())
endfunction
function! s:__foo()
    echom 'foo'
endfunction


function! s:__SID()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze___SID$')
endfunction




let &cpo = s:save_cpo
