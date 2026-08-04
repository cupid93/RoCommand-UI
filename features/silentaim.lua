local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

-- // FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.ZIndex = 999
FOVCircle.Transparency = 0

local Modules = nil
local Installed = false
local OriginalStartShooting = nil
local CurrentTarget = nil

local function GetPing()
    local ping = Stats.Network.ServerStatsItem:FindFirstChild("Ping")
    return (ping and ping.Value or 0) / 1000
end

local function GetTarget()
    if not Toggles.SilentAim then return nil end

    local center = Camera.ViewportSize / 2
    local fov = Options.SilentFOV or 150
    local best, bestDist = nil, fov

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Toggles.SilentTeamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
            continue
        end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local part = character:FindFirstChild(Options.SilentPart or "Head") or character:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local pos = part.Position
        if Toggles.SilentPrediction and part.Velocity then
            pos = pos + part.Velocity * GetPing()
        end

        local screen, onScreen = Camera:WorldToViewportPoint(pos)
        if onScreen then
            local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = { Part = part, Position = pos }
            end
        end
    end

    return best
end

-- // RIVALS: rewrite the shot's aim CFrame inside the fired payload
local function BuildShotPayload(origin, target, part)
    if not Modules or not Modules.Utility or type(Modules.Utility.EncodeCFrame) ~= "function" then
        return nil
    end

    local shot_offset_cf = Modules.Utility:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42))
    local aim_cf = Modules.Utility:EncodeCFrame(CFrame.new(origin, target))

    return {
        [utf8.char(0)] = aim_cf,
        [utf8.char(1)] = aim_cf,
        [utf8.char(2)] = part,
        [utf8.char(3)] = shot_offset_cf,
    }
end

-- // hook the game's own Gun.StartShooting so shots redirect to the target.
-- // Resolved lazily, retried while enabled.
local function TryInstall()
    if Installed then return true end

    pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        Modules = require(ReplicatedStorage:WaitForChild("Modules"))
    end)

    if not Modules or type(Modules.Gun) ~= "table" or type(Modules.Gun.StartShooting) ~= "function" then
        print("[SilentAim] Gun module not found, retrying while enabled")
        return false
    end

    OriginalStartShooting = Modules.Gun.StartShooting
    Modules.Gun.StartShooting = function(self, ...)
        local ok, results = pcall(function()
            if not self or not self.ClientFighter or not self.ClientFighter.IsLocalPlayer then
                return nil
            end

            local target = CurrentTarget
            if not target or not target.Part or not target.Part.Parent then
                return nil
            end

            local shot_results = {OriginalStartShooting(self, ...)}
            if shot_results[1] ~= true or shot_results[2] ~= "StartShooting" then
                return shot_results
            end

            local root = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
            if not root then
                return shot_results
            end

            local payload = BuildShotPayload(root.Position, target.Position, target.Part)
            if not payload then
                return shot_results
            end

            shot_results[3] = payload
            return shot_results
        end)

        if ok and type(results) == "table" then
            return table.unpack(results)
        end
        return OriginalStartShooting(self, ...)
    end

    Installed = true
    print("[SilentAim] Gun.StartShooting hooked")
    return true
end

-- // install on enable, retry periodically if the module wasn't ready
local PrevEnabled = nil
local RetryCount = 0
table.insert(Connections, RunService.Heartbeat:Connect(function()
    local enabled = Toggles.SilentAim
    if enabled ~= PrevEnabled then
        PrevEnabled = enabled
        RetryCount = 0
        if enabled then
            task.spawn(TryInstall)
        end
    end
    if enabled then
        RetryCount = RetryCount + 1
        if not Installed and RetryCount % 120 == 0 then
            task.spawn(TryInstall)
        end
    end
end))

-- // target tracking + FOV circle
table.insert(Connections, RunService.RenderStepped:Connect(function()
    pcall(function()
        if Toggles.SilentAim then
            CurrentTarget = GetTarget()
        else
            CurrentTarget = nil
        end

        if Toggles.SilentAim and Toggles.ShowSilentFOV and CurrentTarget then
            FOVCircle.Position = Camera.ViewportSize / 2
            FOVCircle.Radius = Options.SilentFOV or 150
            FOVCircle.Color = Options.SilentFOVColor or Color3.fromRGB(33, 150, 243)
            FOVCircle.Thickness = Options.SilentFOVThickness or 1
            FOVCircle.Transparency = 0
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
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
            FOVCircle.Visible = false
            FOVCircle:Remove()
        end)
        if Installed and Modules and Modules.Gun and OriginalStartShooting then
            pcall(function()
                Modules.Gun.StartShooting = OriginalStartShooting
            end)
        end
    end
}
