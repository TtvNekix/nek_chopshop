Editable = Editable or {}
Editable.Server = {}

-- Webhook Configuration (Moved here for security/editability)
Editable.Webhook =
""

-- Discord Log
function Editable.Server.SendDiscordLog(title, description, color)
    local webhook = Editable.Webhook
    if not webhook or webhook == "" then
        return
    end

    local embed = { {
        title = title,
        description = description,
        type = "rich",
        color = color or (Config.Discord.Color and Config.Discord.Color.warn or 16761858),
        footer = { text = os.date("%Y-%m-%d %H:%M:%S") }
    } }

    local payload = {
        username = Config.Discord.Username or "ChopShop Logs",
        avatar_url = (Config.Discord.AvatarUrl ~= "" and Config.Discord.AvatarUrl) or nil,
        embeds = embed
    }

    PerformHttpRequest(webhook, function(err)
        if err ~= 204 and err ~= 200 then
            print(("[ChopShop] Error webhook: %s"):format(tostring(err)))
        end
    end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end

-- Custom Reward Logic (Called when finishing job)
-- Can be used to give experience, crypto, items etc.
function Editable.Server.CustomReward(source)
    -- Example:
    -- local xPlayer = ESX.GetPlayerFromId(source)
    -- xPlayer.addAccountMoney('crypto', 10)
end
