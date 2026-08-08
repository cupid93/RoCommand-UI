local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local Mechanics = nil
local Fighter = nil
local GunClass = nil
local Installed = false
local Active = false
local LastShot = 0
local IsReloading = false
local OriginalStartReloading = nil

-- // target state
local TargetPart = nil
local NextSearch = 0
local PendingPlayer, PendingPart, PendingTime
local CurrentPlayer, CurrentPart, CurrentLostTime
local ReactionTime = 0
local ForgetTime = 1
local TargetScanInterval = 0.03

local ScopedWeapons = { "Sniper", "Crossbow" }

--[[
    FindBestTarget (from testfile targeting_state: include parts, max distance,
    FOV gate, weighted screen+world score)
]]
local WeightRatio = 0.7
local IncludeParts = { "Head", "UpperTorso" }

local function FindBestTarget()
    if not Camera then return nil end

    local origin = Camera.CFrame.Position
    local center = Camera.ViewportSize / 2
    local fov_radius = Options.TriggerbotFOV or 100
    local max_distance = Options.TriggerbotMaxDistance or 150

    local best_part
    local best_player
    local best_distance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end

        local character = player.Character
        if not character then
            continue
        end

        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then
            continue
        end

        if Toggles.TriggerbotTeamCheck then
            local their_team = player:GetAttribute("TeamID")
            if their_team and their_team == LocalPlayer:GetAttribute("TeamID") then
                continue
            end
        end

        local root_dist = (root.Position - origin).Magnitude
        if root_dist > (max_distance + 6) then
            continue
        end

        local closest_part = nil
        local closest = math.huge

        for _, part_name in ipairs(IncludeParts) do
            local part = character:FindFirstChild(part_name)
            if not part or not part:IsA("BasePart") then
                continue
            end

            local world_dist = (part.Position - origin).Magnitude
            if world_dist > max_distance then
                continue
            end

            local screen, visible = Camera:WorldToViewportPoint(part.Position)
            if not visible and screen.Z <= 0 then
                continue
            end

            local dx = screen.X - center.X
            local dy = screen.Y - center.Y
            local screen_dist = dx * dx + dy * dy

            if screen_dist > fov_radius * fov_radius then
                continue
            end

            local score = (screen_dist * WeightRatio) + (world_dist * (1 - WeightRatio))

            if score < closest then
                closest = score
                closest_part = part
            end
        end

        if not closest_part or closest >= best_distance then
            continue
        end

        best_distance = closest
        best_player = player
        best_part = closest_part
    end

    return best_player, best_part
end

--[[
    Install: resolve MechanicsController (EquippedItemInput), FighterController
    (GetFighter), and the Gun class (for the StartReloading hook) using the
    same dual-path resolution that weapons/silentaim use.
]]
local function TryInstall()
    if Installed then return true end

    local install_source = nil

    pcall(function()
        local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
        local controllers = PlayerScripts:FindFirstChild("Controllers")
        local pModules = PlayerScripts:FindFirstChild("Modules")

        local mc = controllers and controllers:FindFirstChild("MechanicsController")
        if mc then
            pcall(function()
                Mechanics = require(mc)
            end)
        end

        local fc = controllers and controllers:FindFirstChild("FighterController")
        if fc then
            pcall(function()
                Fighter = require(fc)
            end)
        end

        local Gun

        local itemTypes = pModules and pModules:FindFirstChild("ItemTypes")
        local gunMod = itemTypes and itemTypes:FindFirstChild("Gun")
        if gunMod then
            pcall(function()
                Gun = require(gunMod)
            end)
            if Gun and type(Gun.StartReloading) == "function" then
                install_source = "require(ItemTypes.Gun)"
            end
        end

        if (not Gun or type(Gun.StartReloading) ~= "function") and Fighter then
            pcall(function()
                local fighter = Fighter:GetFighter(LocalPlayer)
                local item = fighter and fighter.EquippedItem
                if item then
                    local cls = getmetatable(item)
                    local depth = 0
                    while type(cls) == "table" and cls.__index and depth < 8 do
                        local next_cls = cls.__index
                        cls = type(next_cls) == "table" and next_cls or nil
                        depth = depth + 1
                        if cls and type(cls.StartReloading) == "function" then
                            break
                        end
                    end
                    if cls and type(cls.StartReloading) == "function" then
                        Gun = cls
                        install_source = "equipped item class"
                    end
                end
            end)
        end

        if Gun and type(Gun.StartReloading) == "function" then
            GunClass = Gun
        end
    end)

    if not (Mechanics and type(Mechanics.EquippedItemInput) == "function") then
        print("[Triggerbot] MechanicsController not found, retrying while enabled")
        return false
    end

    if GunClass and type(GunClass.StartReloading) == "function" and not OriginalStartReloading then
        OriginalStartReloading = GunClass.StartReloading
        GunClass.StartReloading = function(self, ...)
            IsReloading = true
            local length = (self and self.Info and self.Info.ReloadLength) or 1.2
            task.delay(length + 0.1, function()
                IsReloading = false
            end)
            return OriginalStartReloading(self, ...)
        end
    end

    Installed = true
    print("[Triggerbot] installed via " .. tostring(install_source))
    return true
end

-- // target tracking
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not Camera then
        Camera = workspace.CurrentCamera
    end
    if not Camera then
        return
    end

    if not Toggles.Triggerbot then
        if CurrentPlayer then
            CurrentPlayer = nil
            CurrentPart = nil
            CurrentLostTime = 0
            TargetPart = nil
        end
        return
    end

    local now = os.clock()

    if now < NextSearch then
        return
    end
    NextSearch = now + math.max(ReactionTime / 1000, TargetScanInterval)

    local best_player, best_part = FindBestTarget()

    if best_player ~= PendingPlayer or best_part ~= PendingPart then
        PendingPlayer = best_player
        PendingPart = best_part
        PendingTime = now
        return
    end

    if best_player then
        CurrentLostTime = 0

        if CurrentPlayer ~= best_player or CurrentPart ~= best_part then
            if now - PendingTime >= ReactionTime / 1000 then
                CurrentPlayer = best_player
                CurrentPart = best_part
                TargetPart = best_part
            end
        end

        return
    end

    if not CurrentPlayer then
        CurrentLostTime = 0
        return
    end

    if CurrentLostTime == 0 then
        CurrentLostTime = now
        return
    end

    if now - CurrentLostTime >= ForgetTime then
        CurrentPlayer = nil
        CurrentPart = nil
        CurrentLostTime = 0
        TargetPart = nil
    end
end))

-- // fire loop (from testfile triggerbot: guards + shoot delay + EquippedItemInput)
local function FinishShooting()
    Active = false
    pcall(function()
        if Mechanics and Mechanics.EquippedItemInput then
            Mechanics:EquippedItemInput("FinishShooting")
        end
    end)
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not Installed then
        TryInstall()
    end

    if not Toggles.Triggerbot then
        if Active then
            FinishShooting()
        end
        return
    end

    local target = TargetPart
    if not target or not target.Parent then
        if Active then
            FinishShooting()
        end
        return
    end

    if IsReloading then
        if Active then
            FinishShooting()
        end
        return
    end

    local fighter = Fighter and Fighter:GetFighter(LocalPlayer)
    local item = fighter and fighter.EquippedItem
    if not item then
        if Active then
            FinishShooting()
        end
        return
    end

    if Toggles.TriggerbotScoped and table.find(ScopedWeapons, item.Name) then
        local aiming = item.IsFullyAiming and item:IsFullyAiming()
        if not aiming then
            if Active then
                FinishShooting()
            end
            return
        end
    end

    local now = os.clock()
    local shoot_delay = (Options.TriggerbotShootDelay or 100) / 1000
    if now - LastShot < shoot_delay then
        return
    end

    LastShot = now
    Active = true
    pcall(function()
        if Mechanics and Mechanics.EquippedItemInput then
            Mechanics:EquippedItemInput("StartShooting")
        end
    end)
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

        pcall(function()
            FinishShooting()
        end)

        if GunClass and OriginalStartReloading then
            pcall(function()
                GunClass.StartReloading = OriginalStartReloading
            end)
        end
    end
}
