local eventloop = require 'huev2.eventloop'
local event = require 'huev2.event'

local M = {
    start = eventloop.start,
    stop = eventloop.stop,
    subscribe = event.subscribe,
    unsubscribe = event.unsubscribe,
}

return M
