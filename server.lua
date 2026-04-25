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
        Core.Notify(source, "Usage: /gvauth [ID]", "primary")
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
    local table = (framework == 'esx') and 'owned_vehicles' or 'player_vehicles'
    
    local exists = MySQL.query.await(('SELECT plate FROM %s WHERE plate = ? LIMIT 1'):format(table), { plate })
    if not exists or #exists == 0 then 
        return plate 
    end
    
    -- If exists, loop until valid using a random suffix appended
    while true do
        local randomString = tostring(math.random(111, 999))
        local trimLen = 8 - string.len(randomString) - 1
        -- Truncate base plate to make room for random digits and space
        local newPlate = string.sub(plate, 1, trimLen) .. " " .. randomString
        
        local check = MySQL.query.await(('SELECT plate FROM %s WHERE plate = ? LIMIT 1'):format(table), { newPlate })
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

    local hash = GetHashKey(model)
    local coords = data.coords

    if type(coords) ~= "vector4" then return end

    -- Prepare core JSON mods payload for DB
    local modsData = {
        color1 = primaryColor,
        color2 = secondaryColor,
        plate = uniquePlate
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

    if framework == 'esx' then
        -- ESX Format: owner, plate, vehicle (mods)
        success = MySQL.insert.await([[
            INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            targetIdentifier,
            uniquePlate,
            json.encode(modsData),
            'car',
            1
        })
    else
        -- QBCore Format: license, citizenid, vehicle, hash, mods, plate, garage, state
        local targetData = Core.Player.GetPlayerData(targetId)
        success = MySQL.insert.await([[
            INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            targetData.license,
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
        Core.Notify(src, ("Vehicle '%s' given to %s!"):format(model, GetPlayerName(targetId)), "success")

        -- Fire FinalizeSpawn on the TARGET player's client, passing colors so vehicleData isn't needed
        TriggerClientEvent('djonstnix-vehiclegiver:client:FinalizeSpawn', targetId, netId, uniquePlate, primaryColor, secondaryColor)
    else
        Core.Notify(src, "Server failed to save the vehicle to the database.", "error")
        print("[DjonStNix-Vehiclegiver] CRITICAL ERROR: Unable to save vehicle to database table.")
    end
end)
