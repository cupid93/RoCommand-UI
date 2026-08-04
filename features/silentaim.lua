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

local Utility = nil
local OriginalRaycast = nil
local Installed = false

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

-- // hook the game's own Utility.Raycast so bullets redirect without touching
-- // workspace:Raycast (avoids the module honeypot). Resolved lazily.
local function TryInstall()
    if Installed then return true end

    pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        Utility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"))
    end)

    if not Utility or type(Utility.Raycast) ~= "function" then
        print("[SilentAim] Utility module not found, retrying while enabled")
        return false
    end

    OriginalRaycast = Utility.Raycast
    Utility.Raycast = function(...)
        local ok, result = pcall(function()
            local args = { ... }
            local ray = args[1]
            local origin, length

            if typeof(ray) == "Ray" then
                origin = ray.Origin
                length = ray.Direction.Magnitude
            elseif typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                origin = args[1]
                length = args[2].Magnitude
            else
                return nil
            end

            if Toggles.SilentAim then
                local target = GetTarget()
                if target then
                    local direction = (target.Position - origin).Unit * length
                    if typeof(ray) == "Ray" then
                        return OriginalRaycast(Ray.new(origin, direction), table.unpack(args, 2))
                    end
                    args[2] = direction
                    return OriginalRaycast(table.unpack(args))
                end
            end
            return nil
        end)

        if ok and result then
            return result
        end
        return OriginalRaycast(...)
    end

    Installed = true
    print("[SilentAim] Utility.Raycast hooked")
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

-- // FOV circle
table.insert(Connections, RunService.RenderStepped:Connect(function()
    pcall(function()
        if Toggles.SilentAim and Toggles.ShowSilentFOV then
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
        if Installed and Utility and OriginalRaycast then
            pcall(function()
                Utility.Raycast = OriginalRaycast
            end)
        end
    end
}
