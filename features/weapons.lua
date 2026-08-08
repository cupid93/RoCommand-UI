local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Toggles = getgenv().Toggles
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local Modules = nil
local Installed = false
local Originals = {}

local function RestoreWeaponInfo(info, original)
    if not info or not original then return end
    info.ShootRecoil = original.ShootRecoil
    info.ShootAccuracy = original.ShootAccuracy
    info.ShootSpread = original.ShootSpread
    info.QuickShotSpread = original.QuickShotSpread
    info.ShootSpreadConsistent = original.ShootSpreadConsistent
    info.AimSpreadMultiplier = original.AimSpreadMultiplier
    if info.InputSpammingEnabled and original.StartShooting ~= nil then
        info.InputSpammingEnabled.StartShooting = original.StartShooting
    end
    info.ShootCooldown = original.ShootCooldown
end

local function TryInstall()
    if Installed then return true end

    pcall(function()
        local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
        local controllers = PlayerScripts:FindFirstChild("Controllers")
        local fc = controllers and controllers:FindFirstChild("FighterController")
        if fc then
            Modules = require(fc)
        end
    end)

    if not Modules or type(Modules.GetFighter) ~= "function" then
        print("[Weapons] FighterController not found, retrying while enabled")
        return false
    end

    Installed = true
    return true
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not Installed then
        TryInstall()
        if not Installed then return end
    end

    local fighter = Modules:GetFighter(LocalPlayer)
    if not fighter then return end

    local item = fighter.EquippedItem
    if not item or not item.Info then return end
    local info = item.Info

    local enabled = Toggles.NoRecoil or Toggles.NoSpread or Toggles.FullAuto
    if not enabled then
        if Originals[item] then
            RestoreWeaponInfo(info, Originals[item])
        end
        return
    end

    if not Originals[item] then
        Originals[item] = {
            ShootRecoil = info.ShootRecoil,
            ShootAccuracy = info.ShootAccuracy,
            ShootSpread = info.ShootSpread,
            QuickShotSpread = info.QuickShotSpread,
            ShootSpreadConsistent = info.ShootSpreadConsistent,
            AimSpreadMultiplier = info.AimSpreadMultiplier,
            StartShooting = info.InputSpammingEnabled and info.InputSpammingEnabled.StartShooting,
            ShootCooldown = info.ShootCooldown,
        }
    end

    local original = Originals[item]

    if Toggles.NoRecoil then
        info.ShootRecoil = 0
    else
        info.ShootRecoil = original.ShootRecoil
    end

    if Toggles.NoSpread then
        info.ShootAccuracy = 0
        info.ShootSpread = 0
        info.QuickShotSpread = 0
        info.ShootSpreadConsistent = true
        info.AimSpreadMultiplier = 0
    else
        info.ShootAccuracy = original.ShootAccuracy
        info.ShootSpread = original.ShootSpread
        info.QuickShotSpread = original.QuickShotSpread
        info.ShootSpreadConsistent = original.ShootSpreadConsistent
        info.AimSpreadMultiplier = original.AimSpreadMultiplier
    end

    if Toggles.FullAuto and info.InputSpammingEnabled then
        info.InputSpammingEnabled.StartShooting = 0
    elseif info.InputSpammingEnabled and original.StartShooting ~= nil then
        info.InputSpammingEnabled.StartShooting = original.StartShooting
    end
end))

return {
    Unload = function()
        for _, con in ipairs(Connections) do
            pcall(function()
                if con and con.Disconnect then
                    con:Disconnect()
                end
            end)
        end
        for i = #Connections, 1, -1 do
            Connections[i] = nil
        end
        if Installed then
            pcall(function()
    local fighter = Modules:GetFighter(LocalPlayer)
                if fighter and fighter.EquippedItem then
                    local item = fighter.EquippedItem
                    if item.Info and Originals[item] then
                        RestoreWeaponInfo(item.Info, Originals[item])
                    end
                end
            end)
        end
    end
}
