local M = {}
local event = require 'huev2.eventloop'

function M.start()
    return event.start()
end

function M.stop()
    return event.stop()
end

return M
