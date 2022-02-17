local M = {}
local a = require("toolshed.async")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local HUE = require("huev1")
local hue = require("hue")

function M.get_rooms()
	local rooms = {}
	local lights = {}
	local inv = hue.inventory()
	if inv.room then
		for _, room in pairs(inv.room) do
			local room_lights = {}
			if room.services then
				for _, service in ipairs(room.services) do
					if service.type == "grouped_light" then
						rooms[room.metadata.name] = service
						lights[room.metadata.name] = room_lights
					elseif service.type == "light" then
						table.insert(room_lights, service)
					end
				end
			end
		end
	end
	return rooms, lights
end

local rest = require("toolshet.util.net")
local json = require("toolshed.util.json")

function M.toggle_groups(opts)
	opts = opts or require("telescope.themes").get_dropdown({})
	return a.sync(function()
		local rooms = M.get_rooms()
		local results = {}
		for name, room in pairs(rooms) do
			table.insert(results, { data = { name = name, on = room.on.on, group = room } })
		end
		table.sort(results, function(x, y)
			return x.data.name < y.data.name
		end)
		opts = opts or {}
		pickers.new(opts, {
			prompt_title = "Toggle room lights",
			finder = finders.new_table({
				results = results,
				entry_maker = function(entry)
					return {
						value = entry,
						display = function(tbl)
							local ret = tbl.value.data.on
							if ret then
								ret = "ON:  "
							else
								ret = "OFF: "
							end
							return ret .. tbl.value.data.name
						end,
						ordinal = entry.data.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local group = action_state.get_selected_entry().value
					rest.http_async(hue.constants.url_resources.grouped_light .. "/" .. group.data.group.id, {
						method = "PUT",
						headers = {
							["hue-application-key"] = hue.constants.appkey,
							["Content-Type"] = "application/json",
						},
						body = json.encode({ on = { on = not group.data.group.on.on } }),
					})()
				end)
				return true
			end,
		}):find()
	end)
end

local function response_handler(o, s)
	return function(response, err)
		if not response then
			print(vim.inspect(err))
			vim.notify("Failed to communicate with hue bridge", "error", { title = "Philips Hue" })
			return
		end
		local state_string
		if s.on then
			state_string = "on"
		else
			state_string = "off"
		end
		vim.notify("Turned " .. state_string .. " " .. o.data.name, "info", { title = "Philips Hue" })
	end
end

function M.toggle_lights(opts)
	opts = opts or require("telescope.themes").get_dropdown({})
	return a.sync(function()
		local lights, err = a.wait(HUE.lights.get_async())
		if not lights then
			vim.notify("Failed to communicate with bridge\n\n" .. tostring(err), "error", { title = "Philips Hue" })
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
			prompt_title = "Toggle individual lights",
			finder = finders.new_table({
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
						ordinal = entry.data.name,
					}
				end,
			}),
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

return M
