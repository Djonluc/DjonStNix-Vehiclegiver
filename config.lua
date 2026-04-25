Config = {}

-- ==============================================================================
-- 👑 DJONSTNIX BRANDING
-- ==============================================================================
-- DEVELOPED BY: DjonStNix
-- MODULE: DjonStNix-Vehiclegiver
-- ==============================================================================

-- General Settings
Config.EnableLogs = true -- Enable server-side console logging for vehicle creations
Config.CommandName = "gv"
Config.AdminGroup = "admin" -- Group required to use the command (Supports QB/ESX via Bridge)
Config.DefaultGarage = "pillboxgarage" -- Default garage (QBCore) or stored state (ESX)

-- Interaction & Spawning Options
Config.UseOxLib = true -- Set to true if you prefer ox_lib for UI, otherwise uses qb-menu & qb-input natively

-- Framework / Keys Settings
-- This event is triggered on the client to give keys to the player
-- QBCore: "vehiclekeys:client:SetOwner"
-- ESX (Wasabi): "wasabi_carlock:giveKey"
-- ESX (Okok): "okokVehicleLock:giveKeys"
Config.GiveKeysEvent = "vehiclekeys:client:SetOwner" 

-- Note: Vehicle list is now dynamically fetched from your database/shared vehicles!


