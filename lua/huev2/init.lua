local eventloop = require 'huev2.eventloop'
local event = require 'huev2.event'
local inventory = require 'huev2.inventory'
local notify = require 'huev2.notify'

local M = {
    start = eventloop.start,
    stop = eventloop.stop,
    subscribe = event.subscribe,
    unsubscribe = event.unsubscribe,
    inventory = inventory.inventory,
    log = notify.log,
    logerr = notify.logerr,
    logwarn = notify.logwarn,
    get = inventory.get,
    statusline = require 'huev2.statusline',
}

return M
