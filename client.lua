local Core = exports['DjonStNix-Bridge']:GetCore()

local previewVehicle = 0
local builderCam = 0
local vehicleData = {
    model = "",
    targetId = nil,
    primary = 0,
    secondary = 0,
    plate = ""
}

-- Utilities
local function CleanupPreview()
    if DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = 0

    if DoesCamExist(builderCam) then
        RenderScriptCams(false, true, 500, true, true)
        SetCamActive(builderCam, false)
        DestroyCam(builderCam, true)
    end
    builderCam = 0
    ClearFocus()
end

local function SpawnPreviewVehicle(modelName)
    local hash = GetHashKey(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        Core.Notify("Invalid vehicle model.", "error")
        return false
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    CleanupPreview() -- Clean up just in case

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
    local heading = GetEntityHeading(ped) + 90.0

    -- Spawn absolute local, non-networked vehicle
    previewVehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, false, false)
    
    SetEntityCollision(previewVehicle, false, false)
    SetEntityInvincible(previewVehicle, true)
    SetEntityAlpha(previewVehicle, 150, false)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleColours(previewVehicle, vehicleData.primary, vehicleData.secondary)
    SetVehicleNumberPlateText(previewVehicle, vehicleData.plate)
    SetVehicleDirtLevel(previewVehicle, 0.0)

    SetModelAsNoLongerNeeded(hash)

    -- Setup Camera
    builderCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(builderCam, coords.x + 3.5, coords.y + 3.5, coords.z + 1.5)
    PointCamAtEntity(builderCam, previewVehicle, 0.0, 0.0, 0.0, true)
    SetCamActive(builderCam, true)
    RenderScriptCams(true, true, 1000, true, true)

    return true
end

-- UI Menus
local function OpenCustomizationMenu()
    if not DoesEntityExist(previewVehicle) then return end

    if Config.UseOxLib then
        lib.registerContext({
            id = 'vehicle_builder_menu',
            title = 'Vehicle Builder',
            options = {
                {
                    title = 'Primary Color',
                    description = 'Current: ' .. vehicleData.primary,
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:InputColor', { type = 'primary' })
                    end
                },
                {
                    title = 'Secondary Color',
                    description = 'Current: ' .. vehicleData.secondary,
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:InputColor', { type = 'secondary' })
                    end
                },
                {
                    title = 'Plate Text',
                    description = 'Current: ' .. (vehicleData.plate == "" and "NONE" or vehicleData.plate),
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:InputPlate')
                    end
                },
                {
                    title = 'Change Vehicle Model',
                    description = 'Current: ' .. string.upper(vehicleData.model),
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:InputModel')
                    end
                },
                {
                    title = '✅ Confirm & Spawn',
                    description = 'Finish and save vehicle to database.',
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:ConfirmSpawn')
                    end
                },
                {
                    title = '❌ Cancel & Exit',
                    description = 'Destroy preview and close menu.',
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:CancelBuilder')
                    end
                }
            }
        })
        lib.showContext('vehicle_builder_menu')
        return
    end

    local menu = {
        {
            header = "Vehicle Builder",
            isMenuHeader = true
        },
        {
            header = "Primary Color",
            txt = "Current: " .. vehicleData.primary,
            params = {
                event = "djonstnix-vehiclegiver:client:InputColor",
                args = { type = "primary" }
            }
        },
        {
            header = "Secondary Color",
            txt = "Current: " .. vehicleData.secondary,
            params = {
                event = "djonstnix-vehiclegiver:client:InputColor",
                args = { type = "secondary" }
            }
        },
        {
            header = "Plate Text",
            txt = "Current: " .. (vehicleData.plate == "" and "NONE" or vehicleData.plate),
            params = {
                event = "djonstnix-vehiclegiver:client:InputPlate"
            }
        },
        {
            header = "Change Vehicle Model",
            txt = "Current: " .. string.upper(vehicleData.model),
            params = {
                event = "djonstnix-vehiclegiver:client:InputModel"
            }
        },
        {
            header = "✅ Confirm & Spawn",
            txt = "Finish and save vehicle to database.",
            params = {
                event = "djonstnix-vehiclegiver:client:ConfirmSpawn"
            }
        },
        {
            header = "❌ Cancel & Exit",
            txt = "Destroy preview and close menu.",
            params = {
                event = "djonstnix-vehiclegiver:client:CancelBuilder"
            }
        }
    }

    exports['qb-menu']:openMenu(menu)
end

-- Events
RegisterNetEvent('djonstnix-vehiclegiver:client:OpenMenu', function()
    -- Reset default state
    vehicleData = { model = "", targetId = nil, primary = 0, secondary = 0, plate = "" }
    TriggerEvent('djonstnix-vehiclegiver:client:InputModel')
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:InputModel', function()
    local inputModel = nil
    local inputTarget = nil
    
    if Config.UseOxLib then
        local dialog = lib.inputDialog('Vehicle & Target Setup', {
            {type = 'input', label = 'Model Name (e.g. sultan)', required = true},
            {type = 'number', label = 'Target Server ID', required = true}
        })
        if dialog and dialog[1] and dialog[2] then 
            inputModel = dialog[1] 
            inputTarget = tonumber(dialog[2])
        end
    else
        local dialog = exports['qb-input']:ShowInput({
            header = "Vehicle & Target Setup",
            submitText = "Spawn Preview",
            inputs = {
                {
                    text = "Model Name (e.g. sultan)",
                    name = "model",
                    type = "text",
                    isRequired = true
                },
                {
                    text = "Target Server ID",
                    name = "targetId",
                    type = "number",
                    isRequired = true
                }
            }
        })
        if dialog and dialog.model and dialog.targetId then 
            inputModel = dialog.model 
            inputTarget = tonumber(dialog.targetId)
        end
    end

    if inputModel and inputTarget then
        local model = inputModel:lower()
        vehicleData.model = model
        vehicleData.targetId = inputTarget
        local success = SpawnPreviewVehicle(model)
        if success then
            OpenCustomizationMenu()
        else
            CleanupPreview()
        end
    else
        CleanupPreview()
    end
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:InputColor', function(data)
    local type = data.type
    local inputColor = nil

    if Config.UseOxLib then
        local dialog = lib.inputDialog("Set " .. (type == "primary" and "Primary" or "Secondary") .. " Color", {
            {type = 'number', label = 'Color ID (0 - 160)', required = true, min = 0, max = 160}
        })
        if dialog and dialog[1] then inputColor = dialog[1] end
    else
        local dialog = exports['qb-input']:ShowInput({
            header = "Set " .. (type == "primary" and "Primary" or "Secondary") .. " Color",
            submitText = "Apply",
            inputs = {
                {
                    text = "Color ID (0 - 160)",
                    name = "color",
                    type = "number",
                    isRequired = true
                }
            }
        })
        if dialog and dialog.color then inputColor = dialog.color end
    end

    if inputColor then
        local colorVal = tonumber(inputColor)
        if colorVal and colorVal >= 0 and colorVal <= 160 then
            if type == "primary" then
                vehicleData.primary = colorVal
            else
                vehicleData.secondary = colorVal
            end

            -- Live update the preview vehicle
            if DoesEntityExist(previewVehicle) then
                SetVehicleColours(previewVehicle, vehicleData.primary, vehicleData.secondary)
            end
        else
            Core.Notify("Color must be between 0 and 160.", "error")
        end
    end

    -- Reopen menu
    OpenCustomizationMenu()
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:InputPlate', function()
    local inputPlate = nil

    if Config.UseOxLib then
        local dialog = lib.inputDialog('Set Plate Text', {
            {type = 'input', label = 'Max 8 Chars', required = true}
        })
        if dialog and dialog[1] then inputPlate = dialog[1] end
    else
        local dialog = exports['qb-input']:ShowInput({
            header = "Set Plate Text",
            submitText = "Apply",
            inputs = {
                {
                    text = "Max 8 Chars",
                    name = "plate",
                    type = "text",
                    isRequired = true
                }
            }
        })
        if dialog and dialog.plate then inputPlate = dialog.plate end
    end

    if inputPlate then
        local text = string.upper(tostring(inputPlate):sub(1, 8))
        vehicleData.plate = text
        
        -- Live update the plate preview
        if DoesEntityExist(previewVehicle) then
            SetVehicleNumberPlateText(previewVehicle, vehicleData.plate)
        end
    end

    -- Reopen menu
    OpenCustomizationMenu()
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:ConfirmSpawn', function()
    if not DoesEntityExist(previewVehicle) then
        Core.Notify("Preview vehicle does not exist. Cannot confirm.", "error")
        return
    end

    -- Validate fields client side before sending
    if vehicleData.model == "" then return end
    if not vehicleData.targetId then
        Core.Notify("No target player specified.", "error")
        return
    end
    if vehicleData.plate == "" then
        -- Auto generate a basic random plate if none entered
        vehicleData.plate = string.upper(tostring(math.random(11111111, 99999999)))
    end

    local finalCoords = GetEntityCoords(previewVehicle)
    local finalHeading = GetEntityHeading(previewVehicle)

    local payload = {
        model = vehicleData.model,
        targetId = vehicleData.targetId,
        primary = vehicleData.primary,
        secondary = vehicleData.secondary,
        plate = vehicleData.plate,
        coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, finalHeading)
    }

    -- Trigger heavily validated payload
    TriggerServerEvent("djonstnix-vehiclegiver:server:ConfirmSpawn", payload)
    
    CleanupPreview()
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:CancelBuilder', function()
    CleanupPreview()
    Core.Notify("Vehicle preview cancelled.", "info")
end)

-- Fired on the TARGET player's client to seat them and give them keys
RegisterNetEvent('djonstnix-vehiclegiver:client:FinalizeSpawn', function(netId, plateExtracted, primary, secondary)
    local ped = PlayerPedId()
    
    if NetworkDoesNetworkIdExist(netId) then
        local veh = NetToVeh(netId)
        
        -- Wait for entity control
        local timer = 0
        while not NetworkHasControlOfEntity(veh) and timer < 50 do
            NetworkRequestControlOfEntity(veh)
            Wait(10)
            timer = timer + 1
        end

        SetVehicleNumberPlateText(veh, plateExtracted)
        SetVehicleColours(veh, primary, secondary)
        SetVehicleEngineOn(veh, true, true, false)
        
        TaskWarpPedIntoVehicle(ped, veh, -1) -- Driver seat
        
        -- Standard Give Keys events
        TriggerEvent(Config.GiveKeysEvent, plateExtracted)
        Core.Notify("A vehicle has been granted to you!", "success")
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        CleanupPreview()
    end
end)
