" very simple message localization library.

let s:save_cpo = &cpo
set cpo&vim

function! s:new(path)
  let obj = copy(s:Message)
  let obj.path = a:path =~# '%s' ? a:path : 'message/' . a:path . '/%s.txt'
  return obj
endfunction

function! s:get_lang()
  return v:lang ==# 'C' ? 'en' : v:lang[: 1]
endfunction

let s:Message = {}
function! s:Message.get(text)
  if !has_key(self, 'lang')
    call self.load(s:get_lang())
  endif
  if has_key(self.data, a:text)
    return self.data[a:text]
  endif
  let text = self.missing(a:text)
  return type(text) == type('') ? text : a:text
endfunction
function! s:Message.load(lang)
  let pattern = printf(self.path, a:lang)
  let file = get(split(globpath(&runtimepath, pattern), "\n"), 0)
  if !filereadable(file)
    let self.lang = ''
    let self.data = {}
    return
  endif
  let self.lang = a:lang
  let lines = filter(readfile(file), 'v:val !~# "^\\s*#"')
  sandbox let self.data = eval(iconv(join(lines, ''), 'utf-8', &encoding))
endfunction
let s:Message._ = s:Message.get
function! s:Message.missing(text)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
