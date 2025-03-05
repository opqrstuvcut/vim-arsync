" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

function! LoadConf() abort
    let l:conf_dict = {}
    let l:file_exists = filereadable('.vim-arsync')

    if l:file_exists > 0
        let l:conf_options = readfile('.vim-arsync')
        for i in l:conf_options
            let l:var_name = substitute(i[0:stridx(i, ' ')], '^\s*\(.\{-}\)\s*$', '\1', '')
            if l:var_name == 'ignore_path'
                let l:var_value = eval(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''))
            elseif l:var_name == 'remote_passwd'
                let l:var_value = substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', '')
            else
                let l:var_value = escape(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''), '%#!')
            endif
            let l:conf_dict[l:var_name] = l:var_value
        endfor
    endif
    if !has_key(l:conf_dict, "local_path")
        let l:conf_dict['local_path'] = getcwd()
    endif
    if !has_key(l:conf_dict, "remote_port")
        let l:conf_dict['remote_port'] = 22
    endif
    if !has_key(l:conf_dict, "remote_or_local")
        let l:conf_dict['remote_or_local'] = "remote"
    endif
    if !has_key(l:conf_dict, "local_options")
        let l:conf_dict['local_options'] = "-var"
    endif
    if !has_key(l:conf_dict, "remote_options")
        let l:conf_dict['remote_options'] = "-vazre"
    endif
    return l:conf_dict
endfunction

function! JobHandler(job_id, data, event_type) abort
    if a:event_type == 'stdout' || a:event_type == 'stderr'
        if has_key(getqflist({'id' : g:qfid}), 'id')
            call setqflist([], 'a', {'id' : g:qfid, 'lines' : a:data})
        endif
    elseif a:event_type == 'exit'
        if a:data != 0
            copen
        endif
        if a:data == 0
            echo "vim-arsync success."
        endif
    endif
endfunction

function! ShowConf() abort
    let l:conf_dict = LoadConf()
    echo l:conf_dict
    echom string(getqflist())
endfunction

function! ARsync(direction, ...) abort
    let l:conf_dict = LoadConf()
    let l:remote_file = (a:0 > 0 ? a:1 : '')

    if has_key(l:conf_dict, 'remote_host')
        let l:user_passwd = ''
        if has_key(l:conf_dict, 'remote_user')
            let l:user_passwd = l:conf_dict['remote_user'] . '@'
            if has_key(l:conf_dict, 'remote_passwd')
                if !executable('sshpass')
                    echoerr 'You need to install sshpass to use plain text password, otherwise please use ssh-key auth.'
                    return
                endif
                let sshpass_passwd = l:conf_dict['remote_passwd']
            endif
        endif
        if l:conf_dict['remote_or_local'] == 'remote'
            if a:direction == 'down'
                if l:remote_file != ''
                    let l:source = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/' . l:remote_file
                    let l:destination = l:conf_dict['local_path'] . '/' . l:remote_file
                else
                    let l:source = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/'
                    let l:destination = l:conf_dict['local_path'] . '/'
                endif
                let l:cmd = [ 'rsync', l:conf_dict['remote_options'], 'ssh -p ' . l:conf_dict['remote_port'], l:source, l:destination ]
            elseif a:direction == 'up'
                if l:remote_file != ''
                    let l:source = l:conf_dict['local_path'] . '/' . l:remote_file
                    let l:destination = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/' . l:remote_file
                else
                    let l:source = l:conf_dict['local_path'] . '/'
                    let l:destination = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/'
                endif
                let l:cmd = [ 'rsync', l:conf_dict['remote_options'], 'ssh -p ' . l:conf_dict['remote_port'], l:source, l:destination ]
            else " updelete
                if l:remote_file != ''
                    let l:source = l:conf_dict['local_path'] . '/' . l:remote_file
                    let l:destination = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/' . l:remote_file
                    let l:cmd = [ 'rsync', l:conf_dict['remote_options'], 'ssh -p ' . l:conf_dict['remote_port'], l:source, l:destination ]
                else
                    let l:source = l:conf_dict['local_path'] . '/'
                    let l:destination = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/'
                    let l:cmd = [ 'rsync', l:conf_dict['remote_options'], 'ssh -p ' . l:conf_dict['remote_port'], l:source, l:destination, '--delete' ]
                endif
            endif
        elseif l:conf_dict['remote_or_local'] == 'local'
            if a:direction == 'down'
                if l:remote_file != ''
                    let l:source = l:conf_dict['remote_path'] . '/' . l:remote_file
                    let l:destination = l:conf_dict['local_path'] . '/' . l:remote_file
                else
                    let l:source = l:conf_dict['remote_path']
                    let l:destination = l:conf_dict['local_path']
                endif
                let l:cmd = [ 'rsync', l:conf_dict['local_options'], l:source, l:destination ]
            elseif a:direction == 'up'
                if l:remote_file != ''
                    let l:source = l:conf_dict['local_path'] . '/' . l:remote_file
                    let l:destination = l:conf_dict['remote_path'] . '/' . l:remote_file
                else
                    let l:source = l:conf_dict['local_path']
                    let l:destination = l:conf_dict['remote_path']
                endif
                let l:cmd = [ 'rsync', l:conf_dict['local_options'], l:source, l:destination ]
            else " updelete
                if l:remote_file != ''
                    let l:source = l:conf_dict['local_path'] . '/' . l:remote_file
                    let l:destination = l:conf_dict['remote_path'] . '/' . l:remote_file
                    let l:cmd = [ 'rsync', l:conf_dict['local_options'], l:source, l:destination ]
                else
                    let l:source = l:conf_dict['local_path']
                    let l:destination = l:conf_dict['remote_path'] . '/'
                    let l:cmd = [ 'rsync', l:conf_dict['local_options'], l:source, l:destination, '--delete' ]
                endif
            endif
        endif

        if has_key(l:conf_dict, 'ignore_path')
            for file in l:conf_dict['ignore_path']
                let l:cmd = l:cmd + ['--exclude', file]
            endfor
        endif
        if has_key(l:conf_dict, 'ignore_dotfiles')
            if l:conf_dict['ignore_dotfiles'] == 1
                let l:cmd = l:cmd + ['--exclude', '.*']
            endif
        endif
        if has_key(l:conf_dict, 'remote_passwd')
            let l:cmd = ['sshpass', '-p', sshpass_passwd] + l:cmd
        endif

        call setqflist([], ' ', {'title' : 'vim-arsync'})
        let g:qfid = getqflist({'id' : 0}).id
        let l:job_id = async#job#start(l:cmd, {
                    \ 'on_stdout': function('JobHandler'),
                    \ 'on_stderr': function('JobHandler'),
                    \ 'on_exit': function('JobHandler'),
                    \ })
    else
        echoerr 'Could not locate a .vim-arsync configuration file. Aborting...'
    endif
endfunction

function! AutoSync() abort
    let l:conf_dict = LoadConf()
    augroup vimarsync_sync
        autocmd!
        if has_key(l:conf_dict, 'auto_sync_up') && l:conf_dict['auto_sync_up'] == 1
            if has_key(l:conf_dict, 'sleep_before_sync')
                let g:sleep_time = l:conf_dict['sleep_before_sync'] * 1000
                autocmd BufWritePost,FileWritePost * call timer_start(g:sleep_time, { -> execute("call ARsync('up')", "")})
            else
                autocmd BufWritePost,FileWritePost * ARsyncUp
            endif
            echom "vim-arsync auto sync enabled."
        else
            echom "vim-arsync auto sync disabled."
        endif
    augroup END
endfunction

function! ReloadARSyncConf() abort
    call AutoSync()
    echom "vim-arsync configuration reloaded."
endfunction

if !executable('rsync')
    echoerr 'You need to install rsync to be able to use the vim-arsync plugin'
    finish
endif

command! ARsyncUp call ARsync('up')
command! ARsyncUpDelete call ARsync('upDelete')
command! ARsyncDown call ARsync('down')
command! -nargs=1 ARsyncDownFile call ARsync('down', <f-args>)
command! ARshowConf call ShowConf()
command! ARsyncReload call ReloadARSyncConf()

augroup vimarsync
    autocmd!
    autocmd VimEnter * call AutoSync()
    autocmd DirChanged * call AutoSync()
augroup END

augroup vimarsyncreload
    autocmd!
    autocmd BufWritePost .vim-arsync call ReloadARSyncConf()
augroup END
