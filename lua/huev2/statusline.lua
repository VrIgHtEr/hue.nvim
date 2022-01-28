require 'toolshed.util.string.global'
local hue = require 'huev2'
return function()
    local inventory = hue.inventory()
    if inventory.light then
        local g = {}
        for k, v in pairs(inventory.light) do
            local name = v.owner.metadata.name
            local added = false
            for x, y in pairs(g) do
                if x:distance(name) == 1 then
                    added = true
                    table.insert(y, { name = name, id = 'light/' .. k })
                    break
                end
            end
            if not added then
                g[name] = { { name = name, id = 'light/' .. k } }
            end
        end
        local groups = {}
        for _, v in pairs(g) do
            table.insert(groups, v)
            table.sort(v, function(x, y)
                return x.name < y.name
            end)
        end
        table.sort(groups, function(x, y)
            local X, Y = #x, #y
            if X < Y then
                return true
            elseif X > Y then
                return false
            end
            return x[1].name:upper() < y[1].name:upper()
        end)
        local ret = {}
        local first = true
        for _, v in ipairs(groups) do
            if first then
                first = false
            else
                table.insert(ret, ' | ')
            end
            for _, x in ipairs(v) do
                local char
                if hue.get(x.id).on.on then
                    char = 'X'
                else
                    char = 'O'
                end
                table.insert(ret, char)
            end
        end

        ret = table.concat(ret)
        return ret
    end
end
