" vim:foldmethod=marker:fen:
scriptencoding utf-8
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Script variables {{{
let s:PRAGMA_IGNORE_SPACES = 'ignore-spaces'
let s:PRAGMA_LEADER_MACRO = 'leader-macro'
let s:PRAGMA_WARNINGS_MODE = 'warnings-mode'

let s:pragmas = {
\   s:PRAGMA_IGNORE_SPACES : 0,
\   s:PRAGMA_LEADER_MACRO  : 0,
\   s:PRAGMA_WARNINGS_MODE : 1,
\}
let s:GROUP_PRAGMAS = {
\   'all': 'emap#available_pragmas()',
\   'warnings': printf('filter(emap#available_pragmas(), %s)', string('v:val =~# "^warnings-"')),
\}

let s:vimrc_sid = -1

function! s:SID() "{{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction "}}}
let s:EMAP_SNR = printf("<SNR>%d_", s:SID())

" s:map_dict {{{
let s:map_dict = {'stash': {}}

function! s:map_dict_new() "{{{
    return deepcopy(s:map_dict)
endfunction "}}}

function! s:map_dict.map(mode, map_info_options, lhs, rhs) dict "{{{
    let self.stash[a:mode . a:lhs] =
    \   s:map_dict_create_rhs(a:rhs, a:map_info_options)
endfunction "}}}
function! s:map_dict.unmap(mode, map_info_options, lhs) dict "{{{
    unlet self.stash[a:mode . a:lhs]
endfunction "}}}
function! s:map_dict_create_rhs(rhs, map_info_options) "{{{
    " NOTE: This function may be frequently called by :for.
    " And `a:map_info_options` may be same object during :for.
    return extend(
    \   a:map_info_options,
    \   {'_rhs': a:rhs},
    \   'keep',
    \)
endfunction "}}}

function! s:map_dict.maparg(lhs, mode) dict "{{{
    " NOTE: a:mode is only one character.
    return get(self.stash, a:mode . a:lhs, {'_rhs': ''})._rhs
endfunction "}}}
" }}}

let s:named_map = s:map_dict_new()
let s:macro_map = s:map_dict_new()
" }}}

" Functions {{{


let s:Mapping = vital#of('emap').import('Mapping')


" Utilities
function! s:skip_spaces(q_args) "{{{
    return substitute(a:q_args, '^[ \t]*', '', '')
endfunction "}}}

function! s:has_elem(list, elem) "{{{
    return index(a:list, a:elem) isnot -1
endfunction "}}}

function! s:has_all_of(list, elem) "{{{
    " a:elem is List:
    "   a:list has a:elem[0] && a:list has a:elem[1] && ...
    " a:elem is not List:
    "   a:list has a:elem

    if type(a:elem) == type([])
        for i in a:elem
            if !s:has_elem(a:list, i)
                return 0
            endif
        endfor
        return 1
    else
        return s:has_elem(a:list, a:elem)
    endif
endfunction "}}}

function! s:get_each_modes(modes, pragmas, options) "{{{
    let ret = []
    let modes = a:0 && a:modes == '' ? a:1 : a:modes
    for m in split(modes, '\zs')
        if s:Mapping.is_mode_char(m)
            call add(ret, m)
        elseif s:has_pragma(a:pragmas, s:PRAGMA_WARNINGS_MODE, a:options)
            call s:warn("'" . m . "' is not available mode.")
            sleep 1
        endif
    endfor
    return ret
endfunction "}}}


" Errors
function! s:echomsg(hl, msg) "{{{
    execute 'echohl' a:hl
    try
        echomsg a:msg
    finally
        echohl None
    endtry
endfunction "}}}

function! s:warn(...) "{{{
    call s:echomsg('WarningMsg', 'emap: ' . join(a:000))
endfunction "}}}

function! s:error(...) "{{{
    call s:echomsg('ErrorMsg', 'emap: ' . join(a:000))
endfunction "}}}

function! s:errorf(msg, ...) "{{{
    call s:error(call('printf', [a:msg] + a:000))
endfunction "}}}

function! s:parse_error(msg) "{{{
    return 'parse error: ' . a:msg
endfunction "}}}

function! s:argument_error(msg) "{{{
    return 'argument error: ' . a:msg
endfunction "}}}


" For ex commands
" s:EX_COMMANDS {{{
let s:EX_COMMANDS = {
\   'EmDefMacroMap': {
\       'opt': '-nargs=* -bang -complete=mapping',
\       'def': 'call s:cmd_defmacromap(<cmdname>, <q-args>, <bang>0)',
\   },
\   'EmDefMap': {
\       'opt': '-nargs=* -bang -complete=mapping',
\       'def': 'call s:cmd_defmap(<cmdname>, <q-args>, <bang>0)',
\   },
\   'EmMap': {
\       'opt': '-nargs=* -bang -complete=mapping',
\       'def': 'call s:cmd_map(<cmdname>, <q-args>, <bang>0)',
\   },
\   'EmSetPragmas': {
\       'opt': '-bar -nargs=+ -bang',
\       'def': 'call s:cmd_set_pragmas([<f-args>], <bang>0)',
\   },
\}
" }}}
function! emap#load(...) "{{{
    " Define Ex commands.
    " This can change those names like:
    "   call emap#load({
    "   \   'EmMap': 'Map',
    "   \   'EmDefMacroMap': 'DefMacroMap',
    "   \   'EmDefMap': 'DefMap',
    "   \   'EmSetPragmas': 'SetPragmas',
    "   \})
    "   call emap#load('noprefix')    " same as above

    if a:0
        if type(a:1) == type({})
            let def_names = a:1
        elseif type(a:1) == type("") && a:1 ==# 'noprefix'
            let def_names = map(
            \   copy(s:EX_COMMANDS),
            \   'substitute(v:key, "^Em", "", "")'
            \)
        else
            call s:error("invalid arguments for emap#load().")
            return
        endif
    else
        let def_names = {}
    endif

    for [name, info] in items(s:EX_COMMANDS)
        let def =
        \   substitute(
        \       info.def,
        \       '<cmdname>\C',
        \       string(name),
        \       ''
        \   )
        execute
        \   'command!'
        \   info.opt
        \   get(def_names, name, name)
        \   def
    endfor
endfunction "}}}

function! s:cmd_defmacromap(cmdname, q_args, bang) "{{{
    return {a:bang ? 's:do_unmap_command' : 's:do_map_command'}(a:cmdname, a:q_args, 's:convert_defmacromap_lhs', s:macro_map)
endfunction "}}}
function! s:cmd_defmap(cmdname, q_args, bang) "{{{
    return {a:bang ? 's:do_unmap_command' : 's:do_map_command'}(a:cmdname, a:q_args, 's:convert_defmap_lhs', s:named_map)
endfunction "}}}
function! s:cmd_map(cmdname, q_args, bang) "{{{
    return {a:bang ? 's:do_unmap_command' : 's:do_map_command'}(a:cmdname, a:q_args, 's:convert_map_lhs', {})
endfunction "}}}

function! s:convert_defmap_lhs(mode, map_info) "{{{
    return s:get_snr_named_lhs(a:map_info.lhs)
endfunction "}}}
function! s:convert_defmacromap_lhs(mode, map_info) "{{{
    return s:get_snr_macro_lhs(a:map_info.lhs)
endfunction "}}}
function! s:convert_map_lhs(mode, map_info) "{{{
    return s:compile_map(
    \   a:mode,
    \   a:map_info.lhs,
    \   a:map_info.options,
    \   s:create_context_from_map_info(a:map_info)
    \)
endfunction "}}}

function! s:do_map_command(cmdname, q_args, convert_lhs_fn, dict_map) "{{{
    try
        let map_info = s:parse_args(a:q_args)
    catch /^parse error:/
        call s:errorf("%s: %s", a:cmdname, v:exception)
        return
    endtry

    for m in s:get_each_modes(
    \   map_info.modes != '' ? map_info.modes : s:Mapping.get_all_modes(),
    \   map_info.pragmas,
    \   map_info.options
    \)
        let args = [
        \   m,
        \   map_info.options,
        \   {a:convert_lhs_fn}(m, map_info),
        \   s:compile_map(
        \       m, map_info.rhs, map_info.options,
        \       s:create_context_from_map_info(map_info)),
        \]
        if map_info.options.abbr
            let command = call(s:Mapping.get_abbr_command, args, s:Mapping)
        else
            let command = call(s:Mapping.get_map_command, args, s:Mapping)
        endif
        try
            " List or register mappings with :map/:abbr command.
            execute command
            " Save this mapping to `a:dict_map`.
            " Because Vim can't look up lhs with <SID> correctly by maparg().
            if !empty(a:dict_map)
                call call(a:dict_map.map, args, a:dict_map)
            endif
        catch
            call s:error('":'.command.'" throws an exception: ' . v:exception)
        endtry
    endfor
endfunction "}}}
function! s:do_unmap_command(cmdname, q_args, convert_lhs_fn, dict_map) "{{{
    try
        let map_info = s:parse_args(a:q_args)
    catch /^parse error:/
        call s:errorf("%s: %s", a:cmdname, v:exception)
        return
    endtry

    for m in s:get_each_modes(
    \   map_info.modes,
    \   map_info.pragmas,
    \   map_info.options
    \)
        let args = [
        \   m,
        \   map_info.options,
        \   {a:convert_lhs_fn}(m, map_info),
        \]
        if map_info.options.abbr
            let command = call(s:Mapping.get_unabbr_command, args, s:Mapping)
        else
            let command = call(s:Mapping.get_unmap_command, args, s:Mapping)
        endif
        try
            " Unregister mappings with :unmap/:unabbr command.
            execute command
            " Remove this mapping from `a:dict_map`.
            if !empty(a:dict_map)
                call call(a:dict_map.unmap, args, a:dict_map)
            endif
        catch
            call s:error('":'.command.'" throws an exception: ' . v:exception)
        endtry
    endfor
endfunction "}}}


" Parsing Ex commands' argument
function! s:parse_modes(q_args) "{{{
    let mode_arg = matchstr(a:q_args, '^\[[^\[\]]\+\]')
    let rest  = strpart(a:q_args, strlen(mode_arg))
    let modes = mode_arg[1:-2]
    if modes == ''
        throw s:parse_error("empty mode '[...]' argument")
    endif
    return [modes, rest]
endfunction "}}}

function! s:parse_options(q_args) "{{{
    let q_args = a:q_args
    let opt = s:get_default_options()

    let enable = {
    \   'expr': 'expr',
    \   'buffer': 'buffer',
    \   'silent': 'silent',
    \   'special': 'special',
    \   'script': 'script',
    \   'abbr': 'abbr',
    \}
    let disable = {
    \   'remap': 'noremap',
    \   'force': 'unique',
    \}

    while !empty(q_args)
        let [a, rest] = s:parse_one_arg_from_q_args(q_args)
        if a[0] !=# '-'
            break
        endif

        let q_args = rest
        let optname = a[1:]
        if has_key(enable, optname)
            let opt[enable[optname]] = 1
        elseif has_key(disable, optname)
            let opt[disable[optname]] = 0
        elseif optname ==# 'unique' && has('vim_starting')
            call s:warn("warning: -unique is enabled by default: Map ".a:q_args)
            if has('vim_starting')
                sleep 1
            endif
        else
            throw s:parse_error(printf("unknown option '%s'.", a))
        endif
    endwhile

    return [opt, q_args]
endfunction "}}}

function! s:get_default_options() "{{{
    " In emap, <unique> and noremap is default.
    return {
    \   'expr': 0,
    \   'buffer': 0,
    \   'silent': 0,
    \   'special': 0,
    \   'script': 0,
    \   'unique': has('vim_starting'),
    \
    \   'noremap': 1,
    \   'abbr': 0,
    \}
endfunction "}}}

function! s:parse_one_arg_from_q_args(q_args) "{{{
    let arg = s:skip_spaces(a:q_args)
    let head = matchstr(arg, '^.\{-}[^\\]\ze\([ \t]\|$\)')
    let rest = strpart(arg, strlen(head))
    return [head, rest]
endfunction "}}}

function! s:parse_lhs(q_args) "{{{
    let [lhs, q_args] = s:parse_one_arg_from_q_args(a:q_args)
    call s:validate_lhs(lhs)
    return [lhs, q_args]
endfunction "}}}

function! s:validate_lhs(lhs) "{{{
    if a:lhs == ''
        throw s:parse_error('empty lhs.')
    endif

    let illegal = matchstr(a:lhs, '^<\(expr\|buffer\|silent\|special\|script\|unique\)>'.'\C')
    if illegal != ''
        throw s:parse_error(printf("'%s' is :map's option. Please use -option style instead.", illegal))
    endif
endfunction "}}}

function! s:parse_rhs(q_args) "{{{
    " Ignore trailing whitespaces.
    return [substitute(a:q_args, '\s\+$', '', ''), '']
endfunction "}}}

function! s:parse_args(q_args) "{{{
    "     <options> <modes> <lhs> <rhs>
    " Map -buffer   [n]     j     gj

    let modes = ''
    let options = {}
    let lhs = ''
    let rhs = ''
    let create_instance = 'new'

    try
        let q_args = a:q_args
        let q_args = s:skip_spaces(q_args)

        " Allow no arguments `Map` to list all modes' mappings.
        if q_args == '' | throw create_instance | endif

        let [options  , q_args] = s:parse_options(q_args)
        let q_args = s:skip_spaces(q_args)
        " Allow no lhs `Map [n]` to list all modes' mappings.
        if q_args == '' | throw create_instance | endif

        let [modes    , q_args] = s:parse_modes(q_args)
        let q_args = s:skip_spaces(q_args)
        " Allow no options and lhs `Map [n]` to list all modes' mappings.
        if q_args == '' | throw create_instance | endif

        let [lhs, q_args] = s:parse_lhs(q_args)
        let q_args = s:skip_spaces(q_args)
        " Allow no rhs `Map [n] lhs` to list all modes' mappings.
        if q_args == '' | throw create_instance | endif

        let [rhs, q_args] = s:parse_rhs(q_args)

        " Assert q_args == ''
    catch /^new$/
        " Fall through.
    endtry
    return {
    \   'modes': modes,
    \   'options': options,
    \   'lhs': lhs,
    \   'rhs': rhs,
    \   'pragmas': s:pragmas,
    \}
endfunction "}}}


" Mapping
function! emap#compile_map(mode, map) "{{{
    " emap#compile_map() expands a:map to rhs.
    " This expands emap notation in a:map to Vim key-notation.
    "
    " NOTE: Pass {} as a:options to let s:has_pragma() return 0.
    return s:compile_map(a:mode, a:map, {})
endfunction "}}}

function! s:compile_map(mode, map, options, ...) "{{{
    let context = a:0 && type(a:1) is type({}) ?
    \               a:1 : {}
    if a:map == ''
        return ''
    endif
    let keys = s:split_to_keys(a:map)
    if s:has_pragma(s:pragmas, s:PRAGMA_IGNORE_SPACES, a:options)
        let whitespaces = '^[ \t]\+$'
        let keys = filter(keys, 'v:val !~# whitespaces')
    endif
    return join(map(keys, 's:eval_special_key(v:val, a:mode, context)'), '')
endfunction "}}}

function! s:split_to_keys(map)  "{{{
    " From arpeggio.vim
    "
    " Assumption: Special keys such as <C-u> are escaped with < and >, i.e.,
    "             a:lhs doesn't directly contain any escape sequences.
    return split(a:map, '\(<[^<>]\+>\|.\)\zs')
endfunction "}}}

function! s:eval_special_key(map, mode, context) "{{{
    if a:map =~# '^<[^<>]\+>$'
        let map_name = matchstr(a:map, '^<\zs[^<>]\+\ze>$')
        let named_map_rhs = s:named_map.maparg(s:get_snr_named_lhs(map_name), a:mode)
        let macro_map_rhs = s:macro_map.maparg(s:get_snr_macro_lhs(map_name), a:mode)

        " Assert map_name != ''

        " TODO Priority

        if a:map ==# '<SID>'
            return s:vimrc_snr_prefix()
        elseif a:map ==# '<lhs>'
        \   && has_key(a:context, 'lhs')
            return a:context.lhs
        elseif a:map ==# '<q-lhs>'
        \   && has_key(a:context, 'lhs')
            return string(a:context.lhs)
        elseif macro_map_rhs != ''
            " Found :DefMacroMap's mapping. Return rhs definition.
            return macro_map_rhs
        elseif named_map_rhs != ''
            " Found :DefMap's mapping. Return <SNR> named mapping.
            return s:get_snr_named_lhs(map_name)
        else
            " Built-in key notation (:help key-notation)
            "
            " Some keys are not changed despite built-in key notation.
            " ("\<EOL>" == "<EOL>")
            "
            " - <EOL>
            " - <Nop>
            return a:map
        endif
    else
        " Other character like 'a', 'b', ...
        return a:map
    endif
endfunction "}}}

function! s:get_macro_lhs(map) "{{{
    return '@' . a:map
endfunction "}}}

function! s:get_snr_macro_lhs(map) "{{{
    return s:EMAP_SNR . s:get_macro_lhs(a:map)
endfunction "}}}

function! s:get_named_lhs(map) "{{{
    return '$' . a:map
endfunction "}}}

function! s:get_snr_named_lhs(map) "{{{
    return s:EMAP_SNR . s:get_named_lhs(a:map)
endfunction "}}}

function! s:create_context_from_map_info(map_info) "{{{
    let context = {}
    if has_key(a:map_info, 'lhs')
        let context.lhs = a:map_info.lhs
    endif
    return context
endfunction "}}}


" Set SID to convert "<SID>" to "<SNR>...".
function! emap#set_sid(sid) "{{{
    let sid = a:sid + 0
    if sid ==# 0
        call s:error(s:argument_error("Invalid SID."))
        return
    endif
    let s:vimrc_sid = sid
endfunction "}}}

function! emap#set_sid_from_sfile(sfile) "{{{
    let sid = s:get_sid_from_sfile(a:sfile)
    if sid == ''
        let msg = printf("emap#set_sid_from_sfile(): '%s' is not loaded yet.", a:sfile)
        call s:error(s:argument_error(msg))
        return
    endif
    call emap#set_sid(sid)
endfunction "}}}

function! emap#set_sid_from_vimrc() "{{{
    return emap#set_sid_from_sfile($MYVIMRC)
endfunction "}}}

function! s:get_sid_from_sfile(sfile) "{{{
    " From `s:snr_prefix()` of `autoload/textobj/user.vim`.

    redir => result
        silent scriptnames
    redir END

    for line in split(result, '\n')
        let _ = matchlist(line, '^\s*\(\d\+\):\s*\(.*\)$')
        if a:sfile ==# expand(_[2])
            return _[1]
        endif
    endfor

    return ''
endfunction "}}}

function! s:vimrc_snr_prefix() "{{{
    if s:vimrc_sid ==# -1
        call s:error(
        \   "Your SID is not set.",
        \   "Please set by emap#set_sid()",
        \   "or emap#set_sid_from_sfile().",
        \)
        return ''
    endif
    return printf('<SNR>%d_', s:vimrc_sid)
endfunction "}}}


" Pragma
function! emap#available_pragmas() "{{{
    return keys(s:pragmas)
endfunction "}}}

function! emap#group_pragmas() "{{{
    return keys(s:GROUP_PRAGMAS)
endfunction "}}}

function! s:is_valid_pragmas(pragmas) "{{{
    return s:has_all_of(emap#available_pragmas(), a:pragmas)
endfunction "}}}

function! s:is_group_pragma(pragma) "{{{
    " NOTE: This receives one pragma, not List.
    return s:has_elem(emap#group_pragmas(), a:pragma)
endfunction "}}}

function! s:convert_pragmas(pragmas) "{{{
    " NOTE: This function ignores invalid pragmas.
    let pragmas = type(a:pragmas) == type([]) ? a:pragmas : [a:pragmas]
    let ret = []
    for p in pragmas
        if s:is_group_pragma(p)
            let ret += eval(s:GROUP_PRAGMAS[p])
        else
            let ret += [p]
        endif
    endfor
    return ret
endfunction "}}}

function! s:cmd_set_pragmas(f_args, bang) "{{{
    let fn = a:bang ? 'emap#unset_pragmas' : 'emap#set_pragmas'
    return {fn}(a:f_args)
endfunction "}}}

function! emap#set_pragmas(pragmas) "{{{
    let pragmas = s:convert_pragmas(a:pragmas)
    if !s:is_valid_pragmas(pragmas)
        call s:error(s:argument_error('emap#set_pragmas(): invalid pragmas'))
        return
    endif

    for i in pragmas
        let s:pragmas[i] = 1
    endfor
endfunction "}}}

function! emap#unset_pragmas(pragmas) "{{{
    let pragmas = s:convert_pragmas(a:pragmas)
    if !s:is_valid_pragmas(pragmas)
        call s:error(s:argument_error('emap#unset_pragmas(): invalid pragmas'))
        return
    endif

    for i in pragmas
        let s:pragmas[i] = 0
    endfor
endfunction "}}}

function! s:has_pragma(pragmas, name, options) "{{{
    if a:name ==# s:PRAGMA_IGNORE_SPACES
        " Do not apply `ignore-spaces` when -`expr` is specified.
        return get(a:pragmas, a:name, 0)
        \   && !get(a:options, 'expr', 0)
    else
        return get(a:pragmas, a:name, 0)
    endif
endfunction "}}}

" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
