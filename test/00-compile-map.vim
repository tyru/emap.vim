" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

function! s:get_sid_from_sfile(regex) "{{{
    redir => lines
    silent scriptnames
    redir END

    for line in split(lines, '\n')
        let m = matchlist(line, '^\s*\(\d\+\): \(.\+\)$'.'\C')
        if !empty(m) && m[2] =~# a:regex
            return m[1] + 0
        endif
    endfor
    return -1
endfunction "}}}

function! s:run() "{{{
    " FIXME This should not be included to `tests`.
    " Because this is prior condition.
    " :Assert like command is needed?
    let emap_sid = s:get_sid_from_sfile('/autoload/emap\.vim$')
    Isnt emap_sid, -1

    let emap_snr = printf('<SNR>%d_', emap_sid)
    let named_prefix = emap_snr . '$'

    silent! DefUnmap [n] foo
    Is emap#compile_map('<foo>bar', 'n'), '<foo>bar'

    DefMap [n] foo bar
    Is emap#compile_map('<foo>bar', 'n'), named_prefix . 'foobar'
    DefUnmap [n] foo

    DefMacroMap [n] foo baz
    Is emap#compile_map('<foo>bar', 'n'), 'bazbar'
endfunction "}}}

call s:run()
Done

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
