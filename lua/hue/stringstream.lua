local M = {}
local states = {
    begin = 0,
    codepointmultibyte = 1,
    codepointfinished = 2,
    finished = 3,
    err = 4
}

function M.new()
    local state = states.begin
    local codepointbuilder = {}
    local bytecache = nil
    local prevcr = false
    local codepoint
    local partiallydone = true

    return function(str)
        if not partiallydone then
            error "must iterate previous string completely before adding the next one"
        end
        if state == states.finished then error "stream is finished" end
        partiallydone = false
        if str == nil then
            return function()
                ::continue::
                if state == states.begin then
                    partiallydone = true
                    state = states.finished
                    return
                elseif state == states.codepointfinished then
                    if codepoint == "\r" then
                        if prevcr then
                            prevcr = false
                            return "\n"
                        else
                            prevcr = true
                            partiallydone = true
                            state = states.finished
                            return
                        end
                    else
                        if prevcr then
                            prevcr = false
                            if codepoint == "\n" then
                                partiallydone = true
                                state = states.finished
                            end
                            return "\n"
                        else
                            prevcr = false
                            state = states.finished
                            partiallydone = true
                            return codepoint
                        end
                    end
                elseif state == states.codepointmultibyte then
                    if #codepointbuilder < 2 or #codepointbuilder > 4 then
                        error("invalid utf8 sequence")
                    end
                    codepoint = table.concat(codepointbuilder)
                    state = states.codepointfinished
                    goto continue
                elseif state == states.finished then
                    return
                elseif state == states.err then
                    error "error state"
                end
            end
        else
            local index, max = 0, #str

            local nc = function()
                if bytecache then
                    local ret = bytecache
                    bytecache = nil
                    return ret
                end
                if index < max then
                    index = index + 1
                    return str:sub(index, index)
                else
                    partiallydone = true
                end
            end

            return function()
                ::continue::
                if state == states.begin then
                    local c = nc()
                    if not c then return end
                    local byte = string.byte(c)
                    if byte >= 0 and byte <= 127 then
                        codepoint = c
                        state = states.codepointfinished
                        goto continue
                    elseif byte >= 194 and byte <= 244 then
                        table.insert(codepointbuilder, c)
                        state = states.codepointmultibyte
                        goto continue
                    else
                        error("invalid byte in utf8 string")
                    end
                elseif state == states.codepointmultibyte then
                    local c = nc()
                    if not c then return end
                    local byte = string.byte(c)
                    if byte >= 128 and byte <= 191 then
                        table.insert(codepointbuilder, c)
                        goto continue
                    else
                        if #codepointbuilder < 2 or #codepointbuilder > 4 then
                            error("invalid utf8 sequence")
                        end
                        bytecache = c
                        codepoint = table.concat(codepointbuilder)
                        codepointbuilder = {}
                        state = states.codepointfinished
                        goto continue
                    end
                elseif state == states.codepointfinished then
                    if codepoint == "\r" then
                        if prevcr then
                            prevcr = false
                            return "\n"
                        else
                            prevcr = true
                            state = states.begin
                            goto continue
                        end
                    else
                        if prevcr then
                            prevcr = false
                            if codepoint == "\n" then
                                state = states.begin
                            end
                            return "\n"
                        else
                            prevcr = false
                            state = states.begin
                            return codepoint
                        end
                    end
                elseif state == states.err then
                    error("error state")
                elseif state == states.finished then
                    return
                end
            end
        end
    end
end
return M
