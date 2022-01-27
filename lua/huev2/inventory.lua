local M = {}

function M.populate_from_json(json) end

local rest = require 'huev2.rest'
local hue = require 'huev2'
local a = require 'toolshed.async'

a.run(function()
    local ret = a.wait(rest.request_async(hue.url_api))
end)

return M
