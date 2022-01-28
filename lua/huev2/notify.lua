local M = {}
local function notify(message, level)
    if type(message) ~= 'string' then
        message = ''
    end
    if type(level) ~= 'string' or (level ~= 'info' and level ~= 'error' and level ~= 'warn') then
        level = 'info'
    end
    vim.schedule(function()
        vim.notify(message, level, { title = 'Philips Hue' })
    end)
end

function M.log(message)
    notify(message)
end
function M.logerr(message)
    notify(message, 'error')
end
function M.logwarn(message)
    notify(message, 'warn')
end
return M
