" Symlink-proof way to resolve the plugin's path
let g:snippets_plugin_path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

" User should tune these options
let g:snippets_directory = "/opt/pabsan-0/snippets/"
let g:snippets_file_extension = '.fc'

" These need mindful tuning, keys need to be changed somewhere else too
let s:snippets_fzf_keys = 'tab,ctrl-a,ctrl-t,ctrl-l,ctrl-s'
let s:snippets_fzf_hint = 'fzf/rg <tab>, add new <C-a>, on tab <C-t>/<C-l>, on winsplit <C-s>'
let s:snippets_echom_prefix = '[snippets.vim] '

" Pre-checks: fzf installed && user-configured paths exist
if match(&runtimepath, 'fzf.vim') == -1
    echom s:snippets_echom_prefix . "fzf.vim not found! Loading anyway, do expect issues." 
endif

if !isdirectory(g:snippets_directory)
    echom s:snippets_echom_prefix . "Could not find snippets directory set in g:snippets_directory: " . g:snippets_directory
endif


" Main calls to FZF and Rg
" Within functions to enable tab-switching without code duplication
function! s:snippets_call_rg(query)
    call fzf#vim#grep(
        \ "rg --column --color=always --smart-case " .. shellescape(a:query), 
        \ 1, 
        \ fzf#vim#with_preview({'dir': g:snippets_directory, 
        \   'options': [
        \      '--expect=' .. s:snippets_fzf_keys,
        \      '--header=' .. s:snippets_fzf_hint,
        \      '--query', a:query
        \   ], 
        \  'sink*': function('s:snippets_cb_rg')
        \ }), 0)
endfunction

function! s:snippets_call_fzf(query)
    call fzf#vim#files(g:snippets_directory, fzf#vim#with_preview({
        \   'options': [
        \      '--expect=' .. s:snippets_fzf_keys,
        \      '--header=' .. s:snippets_fzf_hint,
        \      '--query', a:query
        \   ], 
        \   'sink*': function('s:snippets_cb_fzf')
        \ }), 0)
endfunction


" Create a snippet, either empty or drawing from visual selection
function! s:snippets_create()
    let l:newfile = input('Enter file path: ', g:snippets_directory, 'file')
    execute 'tabnew ' .. fnameescape(l:newfile)
endfunction

function! s:snippets_create_visual()
    let l:selected_text = getline("'<", "'>")
    call s:snippets_create()
    call setline(1, l:selected_text)
endfunction


" User interfaces to the functions above
command! -bang -nargs=* SnippetsFzf
    \ call s:snippets_call_fzf(<q-args>)

command! -bang -nargs=* SnippetsRg
    \ call s:snippets_call_rg(<q-args>)

command! -bang -nargs=* SnippetsCreate
    \ call s:snippets_create()

command! -bang -nargs=* SnippetsCreateVisual
    \ call s:snippets_create_visual()


" This function switches FZF<->RG while keeping the current buffered text
" - Can only keep text if g:fzf_history_dir is configured, else discards it
" - Not perfect: won't usually crash everything but shows weird behavior
function! s:snippets_mode_switch(current_mode)

    if a:current_mode == 'fzf'

        if get(g:, 'fzf_history_dir', 'NONE') == 'NONE'
            call s:snippets_call_rg('')
        else
            let l:history = readfile(expand(g:fzf_history_dir) .. "/files", '', -1)
            let l:last = l:history[0]
            call s:snippets_call_rg(l:last)
        endif

    elseif a:current_mode == 'rg'
        
        if get(g:, 'fzf_history_dir', 'NONE') == 'NONE'
            call s:snippets_call_fzf('')
        else
            let l:history = readfile(expand(g:fzf_history_dir) .. "/rg", '', -1)
            let l:last = l:history[0]
            call s:snippets_call_fzf(l:last)
        endif
    else
        echom s:snippets_echom_prefix .. 'Wrong current mode argument.'
    endif

endfunction


" Three fzf.vim callbacks: 2 specific + 1 common one
" This is to know current mode towards switching FZF<->RG
" After this check is made, the whole logic off the fzf menu begins
function! s:snippets_cb_rg(lines)
    call s:snippets_cb(a:lines, "rg")
endfunction

function! s:snippets_cb_fzf(lines)
    call s:snippets_cb(a:lines, "fzf")
endfunction

function! s:snippets_cb(lines, current_mode)
    
    " If there is a match, lines will have [key, match]
    " Else, it is just [key]
    if len(a:lines) < 2
        let l:key = a:lines[0]
        let l:file = 'NONE'
    else
        let [l:key, l:fileline_str] = a:lines
        let l:file = split(l:fileline_str, ':', 2)[0]
    endif

    " Actions that require no match
	if l:key == 'tab'         " Perform mode switching based on the key
        call s:snippets_mode_switch(a:current_mode)
        return
    elseif l:key == 'ctrl-a'    " Edit and Add a new snippet
        call s:snippets_create()
        return
    endif

    " Actions that require match. Ensure sane input before that
    if l:file == 'NONE' " Beware! In some versions of vim 'any_str'==0 yields true
        echom s:snippets_echom_prefix .. 'Empty line selected. No FZF match.'
        return
    endif

    if l:key == 'ctrl-t'        " Open snippet in a new Tab 
        execute 'tabedit' g:snippets_directory .. file
        return

    elseif l:key == 'ctrl-l'    " Open snippet in a new tab for Later
        execute 'tabedit' g:snippets_directory .. file
		execute 'tabp'
        return

    elseif l:key == 'ctrl-s'    " Open snippet in new Window
        echo "Specify window split direction: s/v or [c]ancel"
        let l:window_split_char = getchar()

        if l:window_split_char ==# 's'
            execute 'split ' .. file
        elseif l:window_split_char ==# 'v'
            execute 'vsplit ' .. file
        elseif l:window_split_char ==# 'c'  
        elseif l:window_split_char == 27  "escape
            " do nothing
        else
            " default but explicit keys in source code
            execute 'vsplit ' .. file
        endif
        return 

    else
       " Default behavior: do nothing 
       " This is mainly a visualization app
    endif

endfunction

" Key mapping to invoke an entrypoint, only if not being used already
if mapcheck("<leader>s", "I") == "" 
    nnoremap <leader>s :SnippetsRg <CR>
endif

if mapcheck("<leader>s", "v") == "" 
    vnoremap <leader>s :<C-u>SnippetsCreateVisual<CR>
endif

