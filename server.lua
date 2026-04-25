local Core = exports['DjonStNix-Bridge']:GetCore()
local AuthorizedPlayers = {} -- Temporary in-game authorizations

-- Main Builder Command
RegisterCommand(Config.CommandName, function(source, args)
    local isAuthorized = false
    if source == 0 then 
        isAuthorized = true 
    else
        local identifier = Core.Player.GetIdentifier(source)
        if Core.Player.IsAdmin(source) or AuthorizedPlayers[identifier] then
            isAuthorized = true
        end
    end

    if not isAuthorized then
        Core.Notify(source, "You do not have access to the vehicle builder.", "error")
        return
    end

    TriggerClientEvent("djonstnix-vehiclegiver:client:OpenMenu", source)
end, false)

-- Grant/Revoke Access in-game
RegisterCommand("gva", function(source, args)
    if source ~= 0 and not Core.Player.IsAdmin(source) then
        Core.Notify(source, "Only admins can manage gv access.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        Core.Notify(source, "Usage: /gva [ID]", "primary")
        return
    end

    local Target = Core.Player.GetPlayer(targetId)
    if not Target then
        Core.Notify(source, "Player not found.", "error")
        return
    end

    local identifier = Core.Player.GetIdentifier(targetId)
    if AuthorizedPlayers[identifier] then
        AuthorizedPlayers[identifier] = nil
        Core.Notify(source, ("Revoked gv access from %s"):format(GetPlayerName(targetId)), "error")
        Core.Notify(targetId, "Your vehicle builder access has been revoked.", "error")
    else
        AuthorizedPlayers[identifier] = true
        Core.Notify(source, ("Granted gv access to %s"):format(GetPlayerName(targetId)), "success")
        Core.Notify(targetId, "You have been granted access to the vehicle builder! Use /" .. Config.CommandName, "success")
    end
end, false)

-- Helper to safely clone table without ref
local function GenerateUniquePlate(basePlate)
    -- This function ensures 8 character max and uniqueness in database
    local plate = string.upper(basePlate):sub(1, 8)
    local framework = exports['DjonStNix-Bridge']:GetFramework()
    local dbTable = (framework == 'esx') and 'owned_vehicles' or 'player_vehicles'
    
    local exists = MySQL.query.await(('SELECT plate FROM %s WHERE plate = ? LIMIT 1'):format(dbTable), { plate })
    if not exists or #exists == 0 then 
        return plate 
    end
    
    -- If exists, loop until valid using a random suffix appended
    while true do
        local randomString = tostring(math.random(111, 999))
        local trimLen = 8 - string.len(randomString) - 1
        -- Truncate base plate to make room for random digits and space
        local newPlate = string.sub(plate, 1, trimLen) .. " " .. randomString
        
        local check = MySQL.query.await(('SELECT plate FROM %s WHERE plate = ? LIMIT 1'):format(dbTable), { newPlate })
        if not check or #check == 0 then 
            return newPlate 
        end
        Wait(50)
    end
end

RegisterNetEvent('djonstnix-vehiclegiver:server:ConfirmSpawn', function(data)
    local src = source
    local Admin = Core.Player.GetPlayer(src)
    
    if not Admin then return end

    -- Hard Security: Authorization Check (admin must be the one triggering this)
    if not Core.Player.IsAdmin(src) then
        Core.Notify(src, "Unauthorized attempt to build vehicle.", "error")
        print(("[DjonStNix-Vehiclegiver] CRITICAL THREAT: %s attempted to exploit spawn event!"):format(GetPlayerName(src)))
        return
    end

    -- Server-side validation of incoming payload
    if type(data) ~= 'table' then return end

    -- Validate targetId
    local targetId = tonumber(data.targetId)
    if not targetId then
        Core.Notify(src, "Invalid target player ID.", "error")
        return
    end

    local Target = Core.Player.GetPlayer(targetId)
    if not Target then
        Core.Notify(src, "Target player (ID: " .. targetId .. ") is not online.", "error")
        return
    end

    -- Validate model string
    local model = type(data.model) == "string" and string.lower(data.model) or nil
    if not model or model == "" then
        Core.Notify(src, "Invalid vehicle model provided.", "error")
        return
    end

    -- Typecast & clamp logic for Colors 0-160
    local primaryColor = tonumber(data.primary) or 0
    local secondaryColor = tonumber(data.secondary) or 0
    if primaryColor < 0 or primaryColor > 160 then primaryColor = 0 end
    if secondaryColor < 0 or secondaryColor > 160 then secondaryColor = 0 end

    -- Extract & Secure Plate
    local rawPlate = type(data.plate) == "string" and data.plate or "BUILT"
    local uniquePlate = GenerateUniquePlate(rawPlate)
    local plateIndex = tonumber(data.plateIndex) or 0
    if plateIndex < 0 or plateIndex > 5 then plateIndex = 0 end

    local hash = GetHashKey(model)
    local coords = data.coords

    if type(coords) ~= "vector4" then return end

    -- Prepare core JSON mods payload for DB
    local modsData = {
        color1 = primaryColor,
        color2 = secondaryColor,
        plate = uniquePlate,
        plateIndex = plateIndex
    }

    -- Log before logic insertion
    if Config.EnableLogs then
        local adminIdentifier = Core.Player.GetIdentifier(src)
        local targetIdentifier = Core.Player.GetIdentifier(targetId)
        print(("[DjonStNix-Vehiclegiver] Admin %s (%s) giving %s to Player %s (%s). Plate: '%s' | C:[%s, %s]"):format(
            GetPlayerName(src), adminIdentifier,
            model,
            GetPlayerName(targetId), targetIdentifier,
            uniquePlate, primaryColor, secondaryColor
        ))
    end

    -- DB Insert based on Framework
    local framework = exports['DjonStNix-Bridge']:GetFramework()
    local success = false
    local targetIdentifier = Core.Player.GetIdentifier(targetId)
    local targetName = GetPlayerName(targetId) or "Unknown Player"

    if framework == 'esx' then
        -- Standard ESX Vehicle Properties blob
        local vehicleProps = {
            model = model,
            plate = uniquePlate,
            plateIndex = plateIndex,
            color1 = primaryColor,
            color2 = secondaryColor,
            engineHealth = 1000.0,
            bodyHealth = 1000.0,
            fuelLevel = 100.0
        }

        -- ESX Format: owner, plate, vehicle (mods)
        -- Attempting common columns (stored/state) for broader compatibility
        success = MySQL.insert.await([[
            INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE vehicle = VALUES(vehicle)
        ]], {
            targetIdentifier,
            uniquePlate,
            json.encode(vehicleProps),
            'car',
            1
        })

        -- Fallback: If your ESX uses 'state' instead of 'stored', we try to update it
        if success then
            MySQL.update('UPDATE owned_vehicles SET state = 1 WHERE plate = ?', { uniquePlate })
        end
    else
        -- QBCore Format: license, citizenid, vehicle, hash, mods, plate, garage, state
        local targetData = Core.Player.GetPlayerData(targetId)
        local license = targetData and (targetData.license or Core.Player.GetIdentifier(targetId)) or "Unknown"
        
        success = MySQL.insert.await([[
            INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            license,
            targetIdentifier,
            model,
            hash,
            json.encode(modsData),
            uniquePlate,
            Config.DefaultGarage,
            0
        })
    end

    if success then
        -- Spawn networked vehicle near the target player
        local targetPed = GetPlayerPed(targetId)
        local spawnCoords = GetEntityCoords(targetPed)
        local spawnHeading = GetEntityHeading(targetPed)

        local vehEntity = CreateVehicle(hash, spawnCoords.x + 3.0, spawnCoords.y, spawnCoords.z, spawnHeading, true, true)
        
        while not DoesEntityExist(vehEntity) do Wait(10) end
        
        local netId = NetworkGetNetworkIdFromEntity(vehEntity)
        SetEntityDistanceCullingRadius(vehEntity, 1000.0)

        -- Notify admin of success
        Core.Notify(src, ("Vehicle '%s' given to %s!"):format(model, targetName), "success")

        -- Fire FinalizeSpawn on the TARGET player's client, passing colors and plate index
        TriggerClientEvent('djonstnix-vehiclegiver:client:FinalizeSpawn', targetId, netId, uniquePlate, primaryColor, secondaryColor, plateIndex)
    else
        Core.Notify(src, "Server failed to save the vehicle to the database.", "error")
        print("[DjonStNix-Vehiclegiver] CRITICAL ERROR: Unable to save vehicle to database table.")
    end
end)

-- Fetch categorized vehicle list from DB/Framework
Core.Functions.CreateCallback('djonstnix-vehiclegiver:server:GetVehicleList', function(source, cb)
    print("[DjonStNix-Vehiclegiver] Server received request for vehicle list from ID: " .. source)
    local framework = exports['DjonStNix-Bridge']:GetFramework()
    local vehicles = {}

    if framework == 'qb' then
        -- Use QBCore Shared Table
        local QBCore = exports['qb-core']:GetCoreObject()
        for model, data in pairs(QBCore.Shared.Vehicles) do
            local category = data.category or "Uncategorized"
            if not vehicles[category] then vehicles[category] = {} end
            table.insert(vehicles[category], {
                label = data.name or model,
                model = model
            })
        end
    elseif framework == 'esx' then
        -- Query ESX Vehicles Table
        local results = MySQL.query.await('SELECT name, model, category FROM vehicles')
        if results then
            for _, data in ipairs(results) do
                local category = data.category or "Uncategorized"
                if not vehicles[category] then vehicles[category] = {} end
                table.insert(vehicles[category], {
                    label = data.name or data.model,
                    model = data.model
                })
            end
        end
    end

    -- Sort categories and internal lists
    for cat, list in pairs(vehicles) do
        table.sort(list, function(a, b) return a.label < b.label end)
    end

    cb(vehicles)
end)
