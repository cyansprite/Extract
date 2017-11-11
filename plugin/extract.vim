" Setup {{{
if exists("g:extract_loaded")
  finish
endif

let g:extract_loaded = 1

if !has_key(g:,"extract_clipCheck")
    let g:extract_clipCheck = &updatetime * 2
endif

" let timer = timer_start(g:extract_clipCheck, 'extract#checkClip', {'repeat': -1})

" }}}

" Script vars {{{
func! extract#clear()
    let s:all = []
    let s:allType = []
    let s:extractAllDex = 0
    let s:currentType = ''
    let s:allCount = 0
    let s:changenr = -1
    let s:currentReg = ""
    let s:currentRegType = ""
    let s:initcomplete = 0
    let s:visual = 0
    let s:pinned = []
endfun

call extract#clear()
" end local vars}}}

" Vars users can pick {{{
if !has_key(g:,"extract_maxCount")
    let g:extract_maxCount = 5
endif

if !has_key(g:,"extract_defaultRegister")
    let g:extract_defaultRegister = '0'
endif

if !has_key(g:,"extract_ignoreRegisters")
    let g:extract_ignoreRegisters = ['a', '.']
endif

if !has_key(g:,"extract_useDefaultMappings")
    let g:extract_useDefaultMappings = 1
endif

if !has_key(g:,"extract_ignoreJustSpaces")
    let g:extract_ignoreJustSpaces = 1
endif

" end vars}}}

" Yanked, extract it out {{{
augroup Extract
    autocmd!
    autocmd TextYankPost * call extract#YankHappened(deepcopy(v:event))
augroup END

func! extract#YankHappened(event)
    if count(g:extract_ignoreRegisters,  split(a:event['regname'])) > 0
        return
    endif

    call s:addToList(a:event, 0)
endfunc

func! s:addToList(event, ignore)
    if g:extract_ignoreJustSpaces && match(a:event['regcontents'], "\\S") == -1
        return
    endif

    " remove if already exist unless ignored ( i.e. timer or something so rtn)
    if count(s:all, (a:event['regcontents'])) > 0
        if a:ignore == 1
            return
        endif
        let l:index = index(s:all, a:event['regcontents'])
        call remove(s:all, l:index)
        call remove(s:allType, l:index)
        let s:allCount = s:allCount - 1
    endif

    let s:all = add(s:all, (a:event['regcontents']))
    let s:allType = add(s:allType, (a:event['regtype']))

    if !empty(s:pinned)
        if a:ignore != 2 && count(s:pinned, (a:event['regcontents'])) == 0
            let s:all = add(s:all, remove(s:all, len(s:all) - 2))
            let s:allType = add(s:allType, remove(s:allType, len(s:allType) - 2))
        endif
    endif

    if s:allCount > (g:extract_maxCount - 1)
        call remove(s:all, 0)
        call remove(s:allType, 0)
    else
        let s:allCount = s:allCount + 1
        if !s:visual
            let s:extractAllDex = s:allCount - 1
        endif
    endif
endfunc

" end yank and add }}}

" Pin {{{
func! extract#pin()
    call extract#echo()
    echohl NONE
endfunc

func! extract#unpin()
    let s:pinned = []
endfunc

func! extract#echo()
    let l:ind = len(s:all) - 1
    let words = []
    echohl Title
    echom "Index        Type        Lines       |Register Contents"
    echom repeat("=", winwidth(".") - 10)
    echohl NONE
    echom ""
    let all = reverse(copy(s:all))
    for x in l:all
        echohl Number
        echon l:ind . '            ' . repeat(' ', (len(s:all) / 10 - l:ind / 10))
        echohl Type
        echon s:allType[l:ind] . '           '
        echohl StorageClass
        echon len(s:all[l:ind]) .'           |'
        echohl String
        echon strpart(join(s:all[l:ind]), 0, winwidth('.') / 3)
        echohl NONE
        echom ''
        let l:ind = l:ind - 1
    endfor
    echom ""
    echom ""
    echohl Question
    let answer = input("Index To Pin (ctrl-c cancels) >>> ")
    echohl None

    let l:answer = str2nr(l:answer)

    if l:answer > len(s:all) - 1 || l:answer < 0
        echohl ErrorMsg
        echom "You need to make it in range of the list!"
        echohl NONE
        return
    else
        let s:extractAllDex -= 1
        let s:allCount -= 1
        let s:pinned = {"regcontents": remove(s:all, l:answer),
                      \ "regtype"    : remove(s:allType, l:answer)}
        call s:addToList(s:pinned, 2)
    endif
endfun

" }}}

func! s:saveReg(reg) "{{{
    let s:lastUsedReg = a:reg
    let s:currentRegType = getregtype(g:extract_defaultRegister)
    let s:currentReg     = getreg(g:extract_defaultRegister, 1, 1)
    let s:lastType       = getregtype(g:extract_defaultRegister)
    if s:currentRegType !=? 'v'
        let s:specialType = s:currentRegType
    else
        let s:specialType = ''
    endif
endfun "}}}

func! extract#regPut(cmd, reg) "{{{
    " save cmd used
    let s:currentCmd = a:cmd
    call extract#checkClip()
    call s:addToList({'regcontents': getreg(a:reg, 1, 1), 'regtype' : getregtype(a:reg)}, 0)

    call s:saveReg(s:all[s:extractAllDex])

    call setreg(g:extract_defaultRegister, s:all[s:extractAllDex], s:allType[s:extractAllDex])

    call extract#put()
endfun "}}}

func! extract#put() "{{{
    " put from our reg
    try
        exe "norm! ". (s:visual ? "gv" : "") ."\"". g:extract_defaultRegister . s:currentCmd
    catch E353
        echohl ErrorMsg
        echom "reg empty"
        echohl None
    endtry

    " restore reg
    call setreg(g:extract_defaultRegister, s:currentReg, s:currentRegType)

    " save new change
    let s:changenr = changenr()
    let s:visual = 0
endfunc "}}}

func! extract#cycle(inc) "{{{
    if s:allCount < 2 || s:changenr != changenr()
        return
    endif

    " Update index, loop if neg or count
    let s:extractAllDex = s:extractAllDex + a:inc

    if s:extractAllDex < 0
        let s:extractAllDex = s:allCount - 1
    elseif s:extractAllDex > s:allCount - 1
        let s:extractAllDex = 0
    endif

    call s:saveReg(s:all[s:extractAllDex])
    call setreg(g:extract_defaultRegister, s:all[s:extractAllDex], s:allType[s:extractAllDex])

    silent! undo

    call extract#put()
endfunc "}}}

func! extract#cyclePasteType() "{{{
    if s:changenr != changenr()
        return
    endif

    if s:lastType ==# 'v'
        let s:lastType = 'V'
    elseif s:lastType ==# 'V'
        let s:lastType = s:specialType
    else
        let s:lastType = 'v'
    endif

    call setreg(g:extract_defaultRegister, s:lastUsedReg, s:lastType)

    silent! undo

    call extract#put()

endfun "}}}

func! extract#complete(cmd, isRegisterComplete) " {{{
    " with words, complete at current positon, init complete for autocmd, and
    " return '' so we don't insert anything.
    let s:currentCmd = a:cmd
    let s:initcomplete = 1
    let s:doDelete = 0
    let s:isRegisterCompleteType = a:isRegisterComplete
    call extract#checkClip()

    if a:isRegisterComplete
        call complete(col('.'), extract#getRegisterCompletions())
    else
        call complete(col('.'), extract#getListCompletions())
    endif
    return ''
endfun

func! extract#getListCompletions()
    let l:ind = -1
    let words = []
    " loop and add items with index
    for x in s:all
        let l:ind = l:ind + 1
        call add(words, {'empty': 1, 'kind': l:ind, 'menu': '['.s:allType[l:ind]. ' '. len(s:all[l:ind]) .']', 'word': strpart(join(s:all[l:ind]),0, winwidth('.')/2)})
    endfor
    let words = reverse(words)
    return l:words
endfunc

func! extract#getRegisterCompletions()
    let words = []

    " get the contents
    redir => s:com
    silent! reg
    redir END
    let lol = split(s:com, "\n")
    let l:ind = -1
    " ignore first line, the rest parse
    for s in lol
        let l:ind = l:ind + 1
        if l:ind == 0
            continue
        endif
        let kind = strpart(s, 1, 2)
        let type = getregtype(kind)
        if count(g:extract_ignoreRegisters,  split(kind)) > 0
            continue
        endif
        let word = getreg(kind, 1, 1)
        let i2 = -1

        " remove extra whitespace for multiple lines
        let finalwords = []

        for w in word
            let i2 = i2 + 1
            if i2 == 0
                call add(finalwords,w)
                continue
            endif
            call add(finalwords,substitute(w, '^\s\+\|\s\+$', "@", "g"))
        endfor
        " finally add to words for completion
        call add(words,{'empty': 1, 'menu': '['. getregtype(kind) . ' '. len(finalwords) .' ]', 'kind' : kind, 'word' : strpart((join(finalwords, '')), 0, winwidth('.') / 2 )})
    endfor

    " FIXME
    let s:currentCmd = 'gP'
    let s:isRegisterCompleteType = 1
    let s:initcomplete = 1
    return words
endfunc

"}}}

func! extract#all() " for deoplete {{{
    call extract#checkClip()
    return s:all
endfunc " }}}

func! extract#UnComplete() "{{{
    " if we aren't init we didn't do the complete bail
    if !s:initcomplete
        return
    endif

    " if we did do the complete let us know not to do this again
    " init put with cmd and reg name
    try
        let k = v:completed_item['kind']
        if match(v:completed_item['menu'], '\cv \d') == -1
            return
        endif
    catch /.*/
        return
    endtry

    let k = v:completed_item['kind']
    let s:initcomplete = 0

    " if we are characther wise there and we only have 1 line, just do as is.
    if strpart(v:completed_item['menu'],1,1) ==# 'v' && strpart(v:completed_item['menu'],3,1) ==# '1'
        call s:addToList({'regcontents': getreg(l:k, 1, 1), 'regtype' : getregtype(l:k)}, 0)
        return
    endif

    " undo the complete...
    if match(v:completed_item['menu'], 'register') == -1
        silent! undo
    else
        call setline('.', substitute(getline('.'), v:completed_item["word"], "",""))
        " This weird way of breaking undo... I don't know an easier way so, yay
        norm! iu
    endif

    " if we are registers use them, if we are the list, use index
    if s:isRegisterCompleteType
        call extract#regPut(s:currentCmd, k)
    else
        call s:saveReg(s:all[str2nr(k)])
        call setreg(g:extract_defaultRegister, s:all[str2nr(k)], s:allType[str2nr(k)])
        call extract#put()
    endif

endfun

autocmd CompleteDone * :call extract#UnComplete() "}}}

func! extract#checkClip() " {{{
    call s:addToList({'regcontents': getreg('"', 1, 1), 'regtype' : getregtype('"')}, 1)
    call s:addToList({'regcontents': getreg('0', 1, 1), 'regtype' : getregtype('0')}, 1)

    try
        call s:addToList({'regcontents': getreg('+', 1, 1), 'regtype' : getregtype('+')}, 1)
        call s:addToList({'regcontents': getreg('*', 1, 1), 'regtype' : getregtype('*')}, 1)
    catch /.*/
        echom 'weird clip error, dw bout it, E5677'
    endtry
endfunc
"}}}

func! s:replace(type, ...) "{{{
    if g:extract_ignoreJustSpaces &&
     \ match(getreg(g:extract_op_func_register, 1, 1), "\\S") == -1
        echohl ErrorMsg
        echom "reg empty"
        echohl None
        return ''
    endif

    let sel_save = &selection
    let &selection = "inclusive"
    let reg_save = @@
    let savepos = getcurpos()

    if a:0  " Invoked from Visual mode, use `< `>
        silent normal! `<
        silent normal! v
        silent normal! `>
    else    " Invoked from Normal mode, use `[ `]
        silent normal! `[
        silent normal! v
        silent normal! `]
    endif

    call s:saveReg(g:extract_op_func_register)
    exec 'silent normal! "'.g:extract_op_func_register.'x'
    let del = getreg(g:extract_op_func_register)
    let lchar = strcharpart(l:del, match(l:del, '\>') - 1)
    let lword = match(getline('.'), '\S')

    call setreg(g:extract_op_func_register, s:currentReg, s:currentRegType)

    if col('.') == col('$') - 1
        if len(l:del) != 1 && len(lchar) <= 1 && lword != -1
            norm! h
        endif
        call extract#regPut('p', g:extract_op_func_register)
    else
        call extract#regPut('P', g:extract_op_func_register)
    endif

    let &selection = sel_save
    let @@ = reg_save
endfunction
"}}}

" Commands and mapping {{{
" helpers
com! -nargs=1 ExtractPut let s:visual = 0 | call extract#regPut(<q-args>[0], v:register)
com! -range -nargs=1 VisExtractPut let s:visual = 1 | call extract#regPut(<q-args>[0], v:register)
com! -nargs=1 ExtractSycle call extract#cycle(<q-args>)
com! -nargs=0 ExtractCycle call extract#cyclePasteType()
com! -nargs=0 ExtractClear call extract#clear()
com! -nargs=0 ExtractPin call extract#pin()
com! -nargs=0 ExtractUnPin call extract#unpin()

nnoremap <expr><Plug>(extract-put) ':ExtractPut p<cr>'
nnoremap <expr><Plug>(extract-Put) ':ExtractPut P<cr>'
vnoremap <expr><Plug>(extract-put) ':VisExtractPut p<cr>'
vnoremap <expr><Plug>(extract-Put) ':VisExtractPut P<cr>'

noremap <expr><Plug>(extract-sycle) ':ExtractSycle 1<cr>'
noremap <expr><Plug>(extract-Sycle) ':ExtractSycle -1<cr>'
noremap <expr><Plug>(extract-cycle) ':ExtractCycle<cr>'

" completion put and cycle if use mess up
inoremap <Plug>(extract-completeReg) <c-g>u<C-R>=extract#complete('gP',1)<cr>
inoremap <Plug>(extract-completeList) <c-g>u<C-R>=extract#complete('gP',0)<cr>
inoremap <Plug>(extract-sycle) <esc>:ExtractSycle -1<cr>a
inoremap <Plug>(extract-Sycle) <esc>:ExtractSycle 1<cr>a
inoremap <Plug>(extract-cycle) <esc>:ExtractCycle<cr>a

nnoremap <Plug>(extract-replace-normal) :let g:extract_op_func_register=v:register \| set opfunc=<SID>replace<cr>g@
vnoremap <Plug>(extract-replace-visual) :<c-u> let g:extract_op_func_register=v:register \| call <SID>replace(visualmode(), 1)<cr>

" Default mappings {{{
if g:extract_useDefaultMappings
    " mappings for putting
    nmap p <Plug>(extract-put)
    nmap P <Plug>(extract-Put)

    nmap <leader>p :ExtractPin<cr>
    nmap <leader>P :ExtractUnPin<cr>

    " mappings for cycling
    map <m-s> <Plug>(extract-sycle)
    map <m-S> <Plug>(extract-Sycle)
    map <c-s> <Plug>(extract-cycle)

    " mappings for visual
    vmap p <Plug>(extract-put)
    vmap P <Plug>(extract-Put)

    " mappings for insert
    imap <m-v> <Plug>(extract-completeReg)
    imap <c-v> <Plug>(extract-completeList)
    imap <c-s> <Plug>(extract-cycle)
    imap <m-s> <Plug>(extract-sycle)
    imap <m-S> <Plug>(extract-Sycle)

    " mappings for replace
    nmap <silent> s <Plug>(extract-replace-normal)
    nmap <silent> S <Plug>(extract-replace-normal)$
    vmap <silent> s <Plug>(extract-replace-visual)
endif "}}}

"end Commands and Mapping }}}
