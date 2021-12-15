local a = {}
local vimlock = false

----------------------------------------------------------------------------------
-- async base implementation
----------------------------------------------------------------------------------
function a.wrap(f)
    local factory = function(...)
        local params = {...}
        local thunk = function(step)
            table.insert(params, step)
            return f(unpack(params))
        end
        return thunk
    end
    return factory
end

function a.run(func, callback)
    local thread = coroutine.create(func)
    local step = nil
    step = function(...)
        local r = {coroutine.resume(thread, ...)}
        assert(r[1], r[2])
        if coroutine.status(thread) == "dead" then
            if callback then
                table.remove(r, 1)
                return callback(unpack(r))
            end
        else
            return r[2](step)
        end
    end
    return step()
end

a.sync = a.wrap(a.run)
function a.wait(defer) return coroutine.yield(defer) end
function a.wait_all(defer) return coroutine.yield(a.join(defer)) end
function a.main_loop()
    return a.wait(function(step) return vim.schedule(step) end)
end

function a.join(thunks)
    local len = #thunks
    local done = 0
    local acc = {}
    local thunk = function(step)
        if len == 0 then return step() end
        for i, tk in ipairs(thunks) do
            local callback = function(...)
                acc[i] = {...}
                done = done + 1
                if done == len then return step(unpack(acc)) end
            end
            tk(callback)
        end
    end
    return thunk
end

a.syncwrap = function(func)
    return function(...)
        local args = {...}
        return a.sync(function() return func(unpack(args)) end)
    end
end

----------------------------------------------------------------------------------
-- vim api async wrapping
----------------------------------------------------------------------------------
local wrapvimapi = function(api)
    local ret = {}
    for k, v in pairs(api) do
        if type(v) == "function" then
            ret[k] = function(...)
                if vimlock then
                    a.main_loop()
                    vimlock = false
                end
                return v(...)
            end
        end
    end
    return ret
end

a.vim = {api = wrapvimapi(vim.api)}

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- vim.loop async wrapping
----------------------------------------------------------------------------------
local function uvcallback(func)
    return function(...)
        vimlock = true
        return func(...)
    end
end
--
----------------------------------------------------------------------------------
-- libuv process functions
----------------------------------------------------------------------------------

function a.spawn_lines_async(var, callback)
    local builder = {}
    local function emit()
        if callback then callback(table.concat(builder)) end
        builder = {}
    end
    local finished = false
    local stream = require'hue.stringstream'.new()
    local processChar = function(c)
        if c == "\n" then
            emit()
        else
            table.insert(builder, c)
        end
    end
    var.stdout = function(err, data)
        if finished or err then return end
        if data then
            for c in stream(data) do processChar(c) end
        else
            for c in stream() do processChar(c) end
            finished = true
            if #builder > 0 then emit() end
        end
    end
    return a.spawn_async(var)
end

function a.spawn_async(var)
    local handle, err
    local cmd
    local args = {}
    local cwd = nil
    local cbout = nil
    local cberr = nil

    if type(var) == "string" then
        cmd = var
    elseif type(var) == 'table' then
        local len = #var
        if len < 1 then error "command must be supplied" end
        cmd = tostring(var[1])
        for i = 2, len do args[i - 1] = tostring(var[i]) end
        if var.cwd ~= nil then cwd = tostring(var.cwd) end
        if var.stdout ~= nil then
            if type(var.stdout) ~= "function" then
                error "stdout callback must be a function"
            end
            cbout = uvcallback(var.stdout)
        end
        if var.stderr ~= nil then
            if type(var.stderr) ~= "function" then
                error "stderr callback must be a function"
            end
            cberr = uvcallback(var.stderr)
        end
    else
        error "invalid argument"
    end

    return function(step)
        local opts = {args = args}
        if cwd ~= nil then opts.cwd = cwd end
        local stdout, stderr = nil, nil
        if cbout then stdout = vim.loop.new_pipe(false) end
        if cberr then stderr = vim.loop.new_pipe(false) end
        opts.stdio = {nil, stdout, stderr}
        handle, err = vim.loop.spawn(cmd, opts, uvcallback(function(...)
            handle:close()
            if cberr then
                stderr:read_stop()
                stderr:close()
            end
            if cbout then
                stdout:read_stop()
                stdout:close()
            end
            step(...)
        end))
        if handle then
            if cbout then vim.loop.read_start(stdout, cbout) end
            if cberr then vim.loop.read_start(stderr, cberr) end
        else
            if cbout then stdout:close() end
            if cberr then stderr:close() end
            step(nil, err)
        end
    end
end

----------------------------------------------------------------------------------
-- libuv fs functions
----------------------------------------------------------------------------------
for _, x in ipairs({
    'fs_access', 'fs_chmod', 'fs_chown', 'fs_close', 'fs_closedir',
    'fs_copyfile', 'fs_fchmod', 'fs_fchown', 'fs_fdatasync', 'fs_fstat',
    'fs_fsync', 'fs_ftruncate', 'fs_futime', 'fs_lchown', 'fs_link', 'fs_lstat',
    'fs_lutime', 'fs_mkdir', 'fs_mkdtemp', 'fs_mkstemp', 'fs_open', 'fs_read',
    'fs_readdir', 'fs_readlink', 'fs_realpath', 'fs_rename', 'fs_rmdir',
    'fs_sendfile', 'fs_stat', 'fs_symlink', 'fs_unlink', 'fs_utime', 'fs_write'
}) do
    if vim.loop[x] then
        local func = vim.loop[x]
        a[x .. '_async'] = function(...)
            local args = {...}
            return function(step)
                table.insert(args, uvcallback(function(...)
                    local ret = {...}
                    if ret[1] then return step(nil, ret[1]) end
                    table.remove(ret, 1)
                    return step(unpack(ret))
                end))
                return func(unpack(args))
            end
        end
    end
end

----------------------------------------------------------------------------------
-- libuv networking functions
----------------------------------------------------------------------------------
function a.getaddrinfo_async(host, service, hints)
    return function(step)
        local ret = vim.loop.getaddrinfo(host, service, hints,
                                         function(err, addresses)
            if err then
                step(nil, err)
            else
                step(addresses)
            end
        end)
        if not ret then return step(nil, ret) end
    end
end
a.close_async = a.wrap(vim.loop.close)

function a.tcp_connect_async(tcp, host, port)
    return function(step)
        local ret = vim.loop.tcp_connect(tcp, host, port, function(err)
            step(err == nil, err)
        end)
        if not ret then return step(false, ret) end
    end
end

a.shutdown_async = function(tcp)
    return function(step)
        local ret = vim.loop.shutdown(tcp, function(err)
            if err then
                step(nil, err)
            else
                step()
            end
        end)
        if not ret then step(nil, ret) end
    end
end

a.write_async = function(tcp, data)
    return function(step)
        local ret = vim.loop.write(tcp, data, function(err)
            if err then
                step(nil, err)
            else
                step(true)
            end
        end)
        if not ret then step(nil, ret) end
    end
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- create wait wrappers around all provided async functions
----------------------------------------------------------------------------------
function a.create_await_wrappers(tbl)
    assert(type(tbl) == "table", "tbl must be a table")
    for k, v in pairs(tbl) do
        if type(k) == "string" then
            if #k > 6 and k:sub(#k - 5, #k) == "_async" then
                tbl[k:sub(1, #k - 4)] = function(...)
                    return a.wait(v(...))
                end
            end
        end
        if type(v) == "table" then a.create_await_wrappers(v) end
    end
    return tbl
end
a.create_await_wrappers(a)

return a
