ServerUtils = {}

function ServerUtils.SendDiscordLog(title, description, color)
    if Editable and Editable.Server and Editable.Server.SendDiscordLog then
        Editable.Server.SendDiscordLog(title, description, color)
    end
end

function ServerUtils.FormatItemsList(itemsMap)
    if not itemsMap then return "_N/A_" end
    local chunks = {}
    for k, v in pairs(itemsMap) do table.insert(chunks, ("%s x%d"):format(k, v)) end
    if #chunks == 0 then return "_N/A_" end
    return table.concat(chunks, ", ")
end
