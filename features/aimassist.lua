local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Toggles = getgenv().Toggles
local Options = getgenv().Options
-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.ZIndex = 999
FOVCircle.Transparency = 1

local CurrentTarget = nil
local HoldingKey = false
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

-- Keybind hold detection
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Options.AimKey then
        HoldingKey = true
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Options.AimKey then
        HoldingKey = false
        if not Toggles.StickyAim then
            CurrentTarget = nil
        end
    end
end))

local function IsVisible(part, character)
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, character}
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(character)
end

local function IsSameTeam(player)
    if not Toggles.TeamCheck then return false end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

local function GetClosestPlayer()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local fov = Options.FOV
    local stickyFov = fov * Options.StickyMulti

    -- Sticky
    if Toggles.StickyAim and CurrentTarget then
        local char = CurrentTarget.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local part = char and char:FindFirstChild(Options.AimPart)

        if char and hum and hum.Health > 0 and part then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist <= stickyFov and (not Toggles.WallCheck or IsVisible(part, char)) then
                    return CurrentTarget, part
                end
            end
        end
        CurrentTarget = nil
    end

    local closest, closestPart, shortest = nil, nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if IsSameTeam(player) then continue end

        local char = player.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        local part = char:FindFirstChild(Options.AimPart) or root

        if not hum or not root or not part or hum.Health <= 0 then continue end
        if (root.Position - Camera.CFrame.Position).Magnitude > Options.MaxDistance then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < shortest and dist <= fov then
            if not Toggles.WallCheck or IsVisible(part, char) then
                shortest = dist
                closest = player
                closestPart = part
            end
        end
    end

    if closest then
        CurrentTarget = closest
    end

    return closest, closestPart
end

local function AimAt(part, dt)
    local screenPos = Camera:WorldToViewportPoint(part.Position)
    local mouse = UserInputService:GetMouseLocation()

    local deltaX = screenPos.X - mouse.X
    local deltaY = screenPos.Y - mouse.Y

    local alpha = math.clamp(1 / Options.Smoothness, 0.01, 1)

    if mousemoverel then
        mousemoverel(deltaX * alpha, deltaY * alpha)
    else
        -- fallback camera lerp
        local goal = CFrame.lookAt(Camera.CFrame.Position, part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(goal, alpha * 0.9)
    end
end

-- Main loop
table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    -- FOV Circle
    if Toggles.AimEnabled and Toggles.ShowFOV then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Options.FOV
        FOVCircle.Color = Options.FOVColor
        FOVCircle.Thickness = Options.FOVThickness
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    if not Toggles.AimEnabled then
        CurrentTarget = nil
        return
    end

    if not HoldingKey then
        if not Toggles.StickyAim then
            CurrentTarget = nil
        end
        return
    end

    local target, part = GetClosestPlayer()
    if target and part then
        AimAt(part, dt)
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
        pcall(function()
            FOVCircle.Visible = false
            FOVCircle:Remove()
        end)
        CurrentTarget = nil
        HoldingKey = false
    end
}
