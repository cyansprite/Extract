" Setup {{{
if exists("g:extract_loaded")
    finish
endif

let g:extract_loaded = 1
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
    let s:index = 0
endfun

func! extract#printList()
    echom string(s:all)
endfunc

call extract#clear()
" end local vars}}}

" Vars users can pick {{{
if !has_key(g:,"extract_autoCheckSystemClipboard")
    let g:extract_autoCheckSystemClipboard = 1
endif

if !has_key(g:,"extract_preview_colors")
    let g:extract_preview_colors = {
                \ 'Title':      'Special',
                \ 'CursorLine': 'CursorLine',
                \ 'Separator':  'Function',
                \ 'Index':      'Number',
                \ 'Type':       'Type',
                \ 'Lines':      'Boolean',
                \ 'Content':    'Statement'
                \ }
endif

if !has_key(g:,"extract_maxCount")
    let g:extract_maxCount = 5
endif

if !has_key(g:,"extract_loadDeoplete")
    let g:extract_loadDeoplete = 0
endif

if !has_key(g:,"extract_loadNCM")
    let g:extract_loadNCM = 0
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
    let s:index = 0
    if count(g:extract_ignoreRegisters,  split(a:event['regname'])) > 0
        return
    endif

    call extract#checkClip(0)

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
        let lines = len(s:all[l:ind])
        echon lines .repeat(' ', 12-len(string(lines))).'|'
        echohl String
        echon strpart(join(s:all[l:ind]), 0, winwidth('.') / 3)
        echohl NONE
        echom ''
        let l:ind = l:ind - 1
    endfor
    echom ""
    echom ""
    echohl Question
    let answer = input('Index To Pin (ctrl-c cancels) >>> ')
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
    call extract#checkClip(0)
    call s:addToList({'regcontents': getreg(a:reg, 1, 1), 'regtype' : getregtype(a:reg)}, 0)

    call s:saveReg(s:all[s:extractAllDex])

    call setreg(g:extract_defaultRegister, s:all[s:extractAllDex], s:allType[s:extractAllDex])

    call extract#put(1)
endfun "}}}

func! extract#put(indexBehaviour) "{{{
    " put from our reg
    if a:indexBehaviour
        let r = s:all[len(s:all) - s:index - 1]
        call setreg(g:extract_defaultRegister, l:r, s:currentRegType)
    endif
    try
        exe "norm! ". (s:visual ? "gv" : "") ."\"". g:extract_defaultRegister . s:currentCmd
    catch /^Vim\%((\a\+)\)\=:E353:/
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

    call extract#put(0)
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

    call extract#put(0)

endfun "}}}

func! extract#complete(cmd, isRegisterComplete) " {{{
    " with words, complete at current positon, init complete for autocmd, and
    " return '' so we don't insert anything.
    let s:currentCmd = a:cmd
    let s:initcomplete = 1
    let s:doDelete = 0
    let s:isRegisterCompleteType = a:isRegisterComplete
    call extract#checkClip(0)

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
        let parts = split(s)
        let kind = strpart(s, 1, 2)
        let reg = strpart(parts[1], 1, 2)
        let type = getregtype(s)
        if count(g:extract_ignoreRegisters,  reg) > 0
            continue
        endif
        let word = getreg(reg, 1, 1)
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
        call add(words,{'empty': 1, 'menu': '['. getregtype(kind) . ' '. len(finalwords) .' ]', 'kind' : kind . ' ' . reg, 'word' : strpart((join(finalwords, '')), 0, winwidth('.') / 2 )})
    endfor

    " FIXME
    let s:currentCmd = 'gP'
    let s:isRegisterCompleteType = 1
    let s:initcomplete = 1
    return words
endfunc

"}}}

func! extract#all() " for deoplete {{{
    call extract#checkClip(0)
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
    " yay for math
    let s:index = (k + 1 - len(s:all)) * -1
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
        call extract#put(1)
    endif

endfun

autocmd CompleteDone * :call extract#UnComplete() "}}}

func! extract#checkClip(force) " {{{
    call s:addToList({'regcontents': getreg('"', 1, 1), 'regtype' : getregtype('"')}, 1)
    call s:addToList({'regcontents': getreg('0', 1, 1), 'regtype' : getregtype('0')}, 1)

    if $SSH_CLIENT
        echo 'ignoring +* because ssh'
    else
        if g:extract_autoCheckSystemClipboard || a:force
            try
                call s:addToList({'regcontents': getreg('+', 1, 1), 'regtype' : getregtype('+')}, 1)
                call s:addToList({'regcontents': getreg('*', 1, 1), 'regtype' : getregtype('*')}, 1)
            catch /.*/
                echom 'weird clip error, dw bout it, E5677'
            endtry
        endif
    endif
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

func! extract#get_preview_text()
    let l:ind = len(s:all) - 1
    let words = []
    let r = "Index        Type         Lines        |Register Contents\n"
    let r .= repeat("=", &tw) . "\n"
    let s:pos = {}
    let r .= ""
    let all = reverse(copy(s:all))
    for x in l:all
        let a = (l:ind) . repeat(' ', 12) . repeat(' ', (len(s:all) / 10 - l:ind / 10))
        let b = s:allType[l:ind] . repeat(' ', 12)
        let lines = len(s:all[l:ind])
        let c = lines .repeat(' ', 13-len(string(lines))).'|'
        let d = trim(strpart(join(s:all[l:ind]), 0, winwidth('.') / 3))
        let r .= a.b.c.d."\n"
        let s:pos[l:ind] = [a,b,c,d]
        let l:ind = l:ind - 1
    endfor

    let r.= "\n"
    let r.= "\n"
    return r
endfunc

func! extract#single_index_inc(dir)
    if empty(s:all)
        return ''
    endif
    let s:index = ((s:index + a:dir) % (len(s:all)))
    if s:index < 0
        let s:index = len(s:all) - 1
    endif
    return string(s:all[len(s:all) - s:index - 1])
endfunc

let s:preview_win_id = -1
func! extract#show_preview(sin, dir)
    if s:preview_win_id != -1
        call extract#single_index_inc(a:dir)
        call nvim_win_set_cursor(s:preview_win_id, [s:index + 3, 1])
        call nvim_buf_clear_namespace(s:buf, s:cursor_ns, 0, -1)
        call nvim_buf_add_highlight(s:buf, s:cursor_ns, g:extract_preview_colors['CursorLine'], s:index + 2, 0, -1)
        return
    endif

    if a:sin
        let x = extract#single_index_inc(a:dir)
        if x == ''
            echom 'Nothing to preview or cycle yet'
            return
        endif
    endif
    let r = extract#get_preview_text()
    call extract#close_preview()

    let bufname = "Extract Preview"
    let s:buf = nvim_create_buf(v:false, v:true)
    let lines = split(r, "\n")

    let s:ns = nvim_create_namespace('')
    let s:cursor_ns = nvim_create_namespace('')
    call nvim_buf_set_name(s:buf, bufname)
    call nvim_buf_set_option(s:buf, 'buftype',   'nofile')
    call nvim_buf_set_option(s:buf, 'bufhidden', 'wipe')
    call nvim_buf_set_option(s:buf, 'buflisted', v:false)
    call nvim_buf_set_option(s:buf, 'swapfile',  v:false)
    call nvim_buf_set_lines(s:buf, 0, len(lines), v:false, lines)
    call nvim_buf_set_option(s:buf, 'modifiable',  v:false)
    call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Title'], 0, 0, -1)
    call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Separator'], 1, 0, -1)

    let l:ind = len(s:all) - 1
    let x = 0
    for l in lines
        let x = x + 1
        if x < 3 || l:ind < 0
            continue
        endif
        let al = len(s:pos[l:ind][0])
        let bl = len(s:pos[l:ind][1])
        let cl = len(s:pos[l:ind][2])
        let dl = len(s:pos[l:ind][3])
        call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Index'], x-1, 0, al)
        call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Type'], x-1, al, al+bl)
        call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Lines'], x-1, al+bl, al+bl+cl-1)
        call nvim_buf_add_highlight(s:buf, s:ns, g:extract_preview_colors['Content'], x-1, al+bl+cl-1, al+bl+cl+dl)
        call nvim_buf_clear_namespace(s:buf, s:cursor_ns, 0, -1)
        call nvim_buf_add_highlight(s:buf, s:cursor_ns, g:extract_preview_colors['CursorLine'], s:index + 2, 0, -1)
        let l:ind = l:ind - 1
    endfor

    let height = max([2, len(lines)])

    let s:preview_win_id = nvim_open_win(s:buf, v:false, {
                \ 'relative': 'cursor',
                \ 'row': 1,
                \ 'col': 0,
                \ 'width': &tw,
                \ 'height': height,
                \ 'style': 'minimal'
                \ })

    call nvim_win_set_option(s:preview_win_id, 'foldenable',  v:false)
    call nvim_win_set_cursor(s:preview_win_id, [s:index + 3, 1])
    nmap <c-u> <cmd>silent! call nvim_win_set_cursor(<sid>preview_win_id, [nvim_win_get_cursor(<sid>preview_win_id)[0] - nvim_win_get_height(<sid>preview_win_id) / 2, 0])<cr>
    nmap <c-d> <cmd>silent! call nvim_win_set_cursor(<sid>preview_win_id, [nvim_win_get_cursor(<sid>preview_win_id)[0] + nvim_win_get_height(<sid>preview_win_id) / 2, 0])<cr>

    autocmd CursorMoved <buffer> ++once call extract#close_preview()
endfunc

func! extract#close_preview()
    try
        silent! unmap <c-u>
        silent! unmap <c-d>

        if s:preview_win_id != -1
            execute win_id2win(s:preview_win_id).'wincmd c'
            let s:preview_win_id = -1
        endif
    catch /.*/
    endtry
endfunc

" Commands and mapping {{{
" helpers
com! -nargs=1 ExtractPut let s:visual = 0 | call extract#regPut(<q-args>[0], v:register)
com! -range -nargs=1 VisExtractPut let s:visual = 1 | call extract#regPut(<q-args>[0], v:register)
com! -nargs=1 ExtractSycle call extract#cycle(<q-args>)
com! -nargs=0 ExtractCycle call extract#cyclePasteType()
com! -nargs=0 ExtractClear call extract#clear()
com! -nargs=0 ExtractPin call extract#pin()
com! -nargs=0 ExtractUnPin call extract#unpin()
com! -nargs=0 ExtractRefreshClipboard call extract#checkClip(1)

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

" previews
nnoremap <Plug>(extract-preview) :call extract#show_preview(0,0)<CR>
nnoremap <Plug>(extract-sin-preview-inc) :call extract#show_preview(1,1)<CR>
nnoremap <Plug>(extract-sin-preview-dec) :call extract#show_preview(1,-1)<CR>

" Default mappings {{{
let g:extract_normal_mappings = {
            \ 'p'         : '<Plug>(extract-put)',
            \ 'P'         : '<Plug>(extract-Put)',
            \ '<leader>p' : ':ExtractPin<cr>A',
            \ '<leader>P' : ':ExtractUnPin<cr>A',
            \ 's '        : '<Plug>(extract-replace-normal)',
            \ 'S '        : '<Plug>(extract-replace-normal)$',
            \ 'ss'        : 'V<Plug>(extract-replace-visual)',
            \ '<leader>o' : '<Plug>(extract-preview)',
            \ '<down>'     : '<Plug>(extract-sin-preview-inc)',
            \ '<up>'     : '<Plug>(extract-sin-preview-dec)'
            \ }

let g:extract_global_mappings = {
            \ '<m-s>' : '<Plug>(extract-sycle)',
            \ '<m-S>' : '<Plug>(extract-Sycle)',
            \ '<c-s>' : '<Plug>(extract-cycle)'
            \ }

let g:extract_visual_mappings = {
            \ 'p' : '<Plug>(extract-put)',
            \ 'P' : '<Plug>(extract-Put)',
            \ 's' : '<Plug>(extract-replace-visual)'
            \ }

let g:extract_insert_mappings = {
            \ '<m-v>' :  '<Plug>(extract-completeReg)',
            \ '<c-v>' :  '<Plug>(extract-completeList)',
            \ '<c-s>' :  '<Plug>(extract-cycle)',
            \ '<m-s>' :  '<Plug>(extract-sycle)',
            \ '<m-S>' :  '<Plug>(extract-Sycle)'
            \ }

if g:extract_useDefaultMappings
    for key in keys(g:extract_normal_mappings)
        exec printf("nmap <silent> %s %s" , key, g:extract_normal_mappings[key])
    endfor
    for key in keys(g:extract_global_mappings)
        exec printf("map <silent> %s %s" , key, g:extract_global_mappings[key])
    endfor
    for key in keys(g:extract_visual_mappings)
        exec printf("xmap <silent> %s %s" , key, g:extract_visual_mappings[key])
    endfor
    for key in keys(g:extract_insert_mappings)
        exec printf("imap <silent> %s %s" , key, g:extract_insert_mappings[key])
    endfor
endif

"end Commands and Mapping }}}
