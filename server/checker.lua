-- VERSION CHECKER
local RESOURCE_TAG = "[^4nek_chopshop^7]"
local VERSION_URL = "https://raw.githubusercontent.com/TtvNekix/nek_chopshopChecker/main/version"
local UPDATES_URL = "https://raw.githubusercontent.com/TtvNekix/nek_chopshopChecker/main/last-updates"

-- Splits "1.10.2" into { 1, 10, 2 } so versions compare numerically per segment
-- (plain tonumber() would treat "1.10" as lower than "1.9").
local function parseVersion(version)
    local parts = {}
    for number in tostring(version or ''):gmatch('%d+') do
        parts[#parts + 1] = tonumber(number)
    end
    return parts
end

local function isOutdated(current, latest)
    local a, b = parseVersion(current), parseVersion(latest)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y end
    end
    return false
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    PerformHttpRequest(VERSION_URL, function(status, latestVersion)
        if status ~= 200 or not latestVersion then
            print(RESOURCE_TAG .. " ^3Could not check for updates.^7")
            return
        end

        latestVersion = latestVersion:gsub('%s+', '')
        local currentVersion = Config.Version

        if isOutdated(currentVersion, latestVersion) then
            print(RESOURCE_TAG .. " ^1is outdated.\nCurrent version: ^8" .. currentVersion ..
                "\nNewest version: ^2" .. latestVersion .. "\n^3Update^7: https://github.com/TtvNekix/nek_chopshop")
        else
            print(RESOURCE_TAG .. " is updated.")
        end
    end, "GET")

    PerformHttpRequest(UPDATES_URL, function(status, updates)
        if status == 200 and updates then
            print(RESOURCE_TAG .. " Last Updates \n[\n" .. tostring(updates) .. "]")
        end
    end, "GET")
end)
