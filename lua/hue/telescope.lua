local M = {}
local a = require 'hue.async'
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local hue = require 'hue'

local function response_handler(name, powerstate)
    return function(response, err)
        if not response then
            print(vim.inspect(err))
            require 'notify'("Failed to communicate with hue bridge", "error",
                             {title = "Philips Hue"})
            return
        end
        local state_string
        if powerstate then
            state_string = "on"
        else
            state_string = "off"
        end
        require 'notify'("Turned " .. state_string .. " " .. name, "info",
                         {title = "Philips Hue"})
    end
end

function M.toggle_lights(opts)
    opts = opts or require("telescope.themes").get_dropdown {}
    return a.sync(function()
        local lights, err = hue.lights.get_a()
        if not lights then
            require 'notify'("Failed to communicate with bridge\n\n" ..
                                 tostring(err), "error", {title = "Philips Hue"})
            return nil, err
        end
        local results = {}
        for _, v in pairs(lights) do table.insert(results, v) end
        table.sort(results, function(x, y)
            return x.data.name < y.data.name
        end)
        opts = opts or {}
        pickers.new(opts, {
            prompt_title = "Toggle individual lights",
            finder = finders.new_table {
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = function(tbl)
                            local ret = tbl.value.data.state.on
                            if ret then
                                ret = "ON:  "
                            else
                                ret = "OFF: "
                            end
                            return ret .. entry.data.name
                        end,
                        ordinal = entry.data.name
                    }
                end
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local light = action_state.get_selected_entry().value
                    if light.data.state.on then
                        light.state_async {on = false}(response_handler(
                                                           light.data.name,
                                                           false))
                    else
                        light.state_async {on = true, bri = 255, ct = 153}(
                            response_handler(light.data.name, true))
                    end
                end)
                return true
            end
        }):find()
    end)
end

function M.toggle_groups(opts)
    opts = opts or require("telescope.themes").get_dropdown {}
    return a.sync(function()
        local groups, err = hue.groups.get_a()
        if not groups then
            require 'notify'("Failed to communicate with bridge\n\n" ..
                                 tostring(err), "error", {title = "Philips Hue"})
            return nil, err
        end
        local results = {}
        for _, v in pairs(groups) do
            if v.data.type == "Room" then table.insert(results, v) end
        end
        table.sort(results, function(x, y)
            return x.data.name < y.data.name
        end)
        opts = opts or {}
        pickers.new(opts, {
            prompt_title = "Toggle room lights",
            finder = finders.new_table {
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = function(tbl)
                            local ret = tbl.value.data.state.any_on
                            if ret then
                                ret = "ON:  "
                            else
                                ret = "OFF: "
                            end
                            return ret .. entry.data.name
                        end,
                        ordinal = entry.data.name
                    }
                end
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local group = action_state.get_selected_entry().value
                    if group.data.state.any_on then
                        group.action_async {on = false}(response_handler(
                                                            group.data.name,
                                                            false))
                    else
                        group.action_async {on = true, bri = 255, ct = 153}(
                            response_handler(group.data.name, true))
                    end
                end)
                return true
            end
        }):find()
    end)
end
return M
