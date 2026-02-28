-- VERSION CHECKER
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        function checkVersion(error, latestVersion, headers)
            local currentVersion = Config['Version']
            local name = "[^4nek_chopshop^7]"
            Citizen.Wait(2000)

            if tonumber(currentVersion) < tonumber(latestVersion) then
                print(name ..
                    " ^1is outdated.\nCurrent version: ^8" ..
                    currentVersion ..
                    "\nNewest version: ^2" ..
                    latestVersion .. "\n^3Update^7: https://github.com/TtvNekix/nek_chopshop")
            else
                print(name .. " is updated.")
            end
        end

        function checkUpdates(error2, update, headers2)
            local updates = update
            local name = "[^4nek_chopshop^7]"
            Citizen.Wait(2000)

            if update then
                print(name .. " Last Updates \n[\n" .. tostring(updates) .. "]")
            end
        end

        PerformHttpRequest("https://raw.githubusercontent.com/TtvNekix/nek_chopshopChecker/main/version", checkVersion,
        "GET")
        PerformHttpRequest("https://raw.githubusercontent.com/TtvNekix/nek_chopshopChecker/main/last-updates", checkUpdates,
            "GET")
    end
end)