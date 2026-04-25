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

local function OpenCategoryMenu(targetId)
    print("[DjonStNix-Vehiclegiver] Triggering server callback: GetVehicleList")
    Core.Functions.TriggerCallback('djonstnix-vehiclegiver:server:GetVehicleList', function(vehicles)
        print("[DjonStNix-Vehiclegiver] Received vehicle list from server")
        if not vehicles or next(vehicles) == nil then
            Core.Notify("No vehicles found in database.", "error")
            return
        end

        local options = {}
        local categories = {}
        for cat, _ in pairs(vehicles) do table.insert(categories, cat) end
        table.sort(categories)

        if Config.UseOxLib then
            for _, cat in ipairs(categories) do
                table.insert(options, {
                    title = cat,
                    onSelect = function()
                        TriggerEvent('djonstnix-vehiclegiver:client:BrowseVehicles', { 
                            category = cat, 
                            targetId = targetId,
                            vehicleList = vehicles[cat] -- Pass the specific list
                        })
                    end
                })
            end
            lib.registerContext({
                id = 'vehicle_category_menu',
                title = 'Select Category',
                menu = 'vehicle_setup_menu',
                onExit = function() CleanupPreview() end,
                options = options
            })
            lib.showContext('vehicle_category_menu')
        else
            table.insert(options, { header = "Select Category", isMenuHeader = true })
            for _, cat in ipairs(categories) do
                table.insert(options, {
                    header = cat,
                    params = {
                        event = "djonstnix-vehiclegiver:client:BrowseVehicles",
                        args = { 
                            category = cat, 
                            targetId = targetId,
                            vehicleList = vehicles[cat]
                        }
                    }
                })
            end
            exports['qb-menu']:openMenu(options)
        end
    end)
end

RegisterNetEvent('djonstnix-vehiclegiver:client:BrowseVehicles', function(data)
    local cat = data.category
    local targetId = data.targetId
    local vehicles = data.vehicleList
    local options = {}

    if Config.UseOxLib then
        for _, veh in ipairs(vehicles) do
            table.insert(options, {
                title = veh.label,
                description = "Model: " .. veh.model,
                onSelect = function()
                    vehicleData.model = veh.model
                    vehicleData.targetId = targetId
                    local success = SpawnPreviewVehicle(veh.model)
                    if success then OpenCustomizationMenu() end
                end
            })
        end
        lib.registerContext({
            id = 'vehicle_selection_menu',
            title = 'Browse: ' .. cat,
            menu = 'vehicle_category_menu',
            onExit = function() CleanupPreview() end,
            options = options
        })
        lib.showContext('vehicle_selection_menu')
    else
        table.insert(options, { header = "Browse: " .. cat, isMenuHeader = true })
        for _, veh in ipairs(vehicles) do
            table.insert(options, {
                header = veh.label,
                txt = "Model: " .. veh.model,
                params = {
                    isServer = false,
                    event = "djonstnix-vehiclegiver:client:SelectBrowsedVehicle",
                    args = { model = veh.model, targetId = targetId }
                }
            })
        end
        exports['qb-menu']:openMenu(options)
    end
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:SelectBrowsedVehicle', function(data)
    vehicleData.model = data.model
    vehicleData.targetId = data.targetId
    local success = SpawnPreviewVehicle(data.model)
    if success then OpenCustomizationMenu() end
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:InputModel', function()
    local targetId = nil
    
    -- First, get the Target ID
    if Config.UseOxLib then
        local dialog = lib.inputDialog('Target Setup', {
            {type = 'number', label = 'Target Server ID', required = true}
        })
        if dialog and dialog[1] then 
            targetId = tonumber(dialog[1])
        end
    else
        local dialog = exports['qb-input']:ShowInput({
            header = "Target Setup",
            submitText = "Continue",
            inputs = {
                {
                    text = "Target Server ID",
                    name = "targetId",
                    type = "number",
                    isRequired = true
                }
            }
        })
        if dialog and dialog.targetId then 
            targetId = tonumber(dialog.targetId)
        end
    end

    if not targetId then CleanupPreview() return end

    -- Now ask how they want to select the vehicle
    if Config.UseOxLib then
        lib.registerContext({
            id = 'vehicle_setup_menu',
            title = 'Vehicle Selection',
            onExit = function() CleanupPreview() end,
            options = {
                {
                    title = 'Manual Input',
                    description = 'Type the model name manually',
                    onSelect = function()
                        local dialog = lib.inputDialog('Manual Input', {
                            {type = 'input', label = 'Model Name', required = true}
                        })
                        if dialog and dialog[1] then
                            vehicleData.model = dialog[1]:lower()
                            vehicleData.targetId = targetId
                            if SpawnPreviewVehicle(vehicleData.model) then OpenCustomizationMenu() end
                        end
                    end
                },
                {
                    title = 'Browse Categories',
                    description = 'Select from pre-configured list',
                    onSelect = function()
                        OpenCategoryMenu(targetId)
                    end
                }
            }
        })
        lib.showContext('vehicle_setup_menu')
    else
        local menu = {
            { header = "Vehicle Selection", isMenuHeader = true },
            {
                header = "Manual Input",
                txt = "Type the model name manually",
                params = {
                    event = "djonstnix-vehiclegiver:client:ManualInput",
                    args = { targetId = targetId }
                }
            },
            {
                header = "Browse Categories",
                txt = "Select from pre-configured list",
                params = {
                    event = "djonstnix-vehiclegiver:client:BrowseCategories",
                    args = { targetId = targetId }
                }
            }
        }
        exports['qb-menu']:openMenu(menu)
    end
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:ManualInput', function(data)
    local targetId = data.targetId
    local dialog = exports['qb-input']:ShowInput({
        header = "Manual Input",
        submitText = "Spawn Preview",
        inputs = {
            {
                text = "Model Name",
                name = "model",
                type = "text",
                isRequired = true
            }
        }
    })
    if dialog and dialog.model then
        vehicleData.model = dialog.model:lower()
        vehicleData.targetId = targetId
        if SpawnPreviewVehicle(vehicleData.model) then OpenCustomizationMenu() end
    end
end)

RegisterNetEvent('djonstnix-vehiclegiver:client:BrowseCategories', function(data)
    OpenCategoryMenu(data.targetId)
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
