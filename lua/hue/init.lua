local eventloop = require 'hue.eventloop'
local event = require 'hue.event'
local inventory = require 'hue.inventory'
local notify = require 'hue.notify'

local M = {
    start = eventloop.start,
    stop = eventloop.stop,
    subscribe = event.subscribe,
    unsubscribe = event.unsubscribe,
    unsubscribe_all = event.unsubscribe_all,
    inventory = inventory.inventory,
    log = notify.log,
    logerr = notify.logerr,
    logwarn = notify.logwarn,
    get = inventory.get,
}

return M
