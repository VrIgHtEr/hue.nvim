local event = {}
local hue = require 'hue'
local a = require 'toolshed.async'
local polling = false
local poll_timer = vim.loop.new_timer()
local notify = require 'notify'
local pgroups = {}

local function fire_change_event(group)
    local str
    if group.data.state.any_on then
        str = "on"
    else
        str = "off"
    end
    notify(group.data.name .. " has been turned " .. str, "info",
           {title = "Philips Hue"})
end

local function diff_group(prev, new)
    if new.data.type ~= "Room" then return end
    if prev.data.state.any_on ~= new.data.state.any_on then
        fire_change_event(new)
    end
end

local function poll()
    a.run(function()
        local groups = hue.groups.get_a()
        if groups then
            for id, group in pairs(groups) do
                local pgroup = pgroups[id]
                if pgroup then diff_group(pgroup, group) end
            end
            pgroups = groups
        end
        if polling then poll_timer:start(2500, 0, function() poll() end) end
    end)
end

function event.poll_start()
    if polling then return end
    polling = true
    poll()
end

function event.poll_stop()
    if not polling then return end
    polling = false
end

return event
