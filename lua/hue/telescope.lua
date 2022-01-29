local M = {}
local a = require 'toolshed.async'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local hue = require 'huev1'

local function response_handler(o, s)
    return function(response, err)
        if not response then
            print(vim.inspect(err))
            vim.notify('Failed to communicate with hue bridge', 'error', { title = 'Philips Hue' })
            return
        end
        local state_string
        if s.on then
            state_string = 'on'
        else
            state_string = 'off'
        end
        vim.notify('Turned ' .. state_string .. ' ' .. o.data.name, 'info', { title = 'Philips Hue' })
    end
end

function M.toggle_lights(opts)
    opts = opts or require('telescope.themes').get_dropdown {}
    return a.sync(function()
        local lights, err = a.wait(hue.lights.get_async())
        if not lights then
            vim.notify('Failed to communicate with bridge\n\n' .. tostring(err), 'error', { title = 'Philips Hue' })
            return nil, err
        end
        local results = {}
        for _, v in pairs(lights) do
            table.insert(results, v)
        end
        table.sort(results, function(x, y)
            return x.data.name < y.data.name
        end)
        opts = opts or {}
        pickers.new(opts, {
            prompt_title = 'Toggle individual lights',
            finder = finders.new_table {
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = function(tbl)
                            local ret = tbl.value.data.state.on
                            if ret then
                                ret = 'ON:  '
                            else
                                ret = 'OFF: '
                            end
                            return ret .. entry.data.name
                        end,
                        ordinal = entry.data.name,
                    }
                end,
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local light = action_state.get_selected_entry().value
                    local s = { on = not light.data.state.on }
                    if s.on then
                        s.bri, s.ct = 254, 153
                    end
                    light.state_async(s)(response_handler(light, s))
                end)
                return true
            end,
        }):find()
    end)
end

function M.toggle_groups(opts)
    opts = opts or require('telescope.themes').get_dropdown {}
    return a.sync(function()
        local groups, err = a.wait(hue.groups.get_async())
        if not groups then
            vim.notify('Failed to communicate with bridge\n\n' .. tostring(err), 'error', { title = 'Philips Hue' })
            return nil, err
        end
        local results = {}
        for _, v in pairs(groups) do
            if v.data.type == 'Room' then
                table.insert(results, v)
            end
        end
        table.sort(results, function(x, y)
            return x.data.name < y.data.name
        end)
        opts = opts or {}
        pickers.new(opts, {
            prompt_title = 'Toggle room lights',
            finder = finders.new_table {
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = function(tbl)
                            local ret = tbl.value.data.state.any_on
                            if ret then
                                ret = 'ON:  '
                            else
                                ret = 'OFF: '
                            end
                            return ret .. entry.data.name
                        end,
                        ordinal = entry.data.name,
                    }
                end,
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local group = action_state.get_selected_entry().value
                    local s = { on = not group.data.state.any_on }
                    if s.on then
                        s.bri, s.ct = 254, 153
                    end
                    group.action_async(s)(response_handler(group, s))
                end)
                return true
            end,
        }):find()
    end)
end
return M
