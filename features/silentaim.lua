local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local IsVisible
local GetClosestTarget

local function IsVisible(part)
    local char = LocalPlayer.Character
    if not char then return true end
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local result = workspace:Raycast(origin, part.Position - origin, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
end

local function GetClosestTarget()
    if not Toggles.SilentAim then return nil end
    local lpChar = LocalPlayer.Character
    local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
    if not lpRoot then return nil end

    local center = Camera.ViewportSize / 2
    local fov = Options.SilentFOV or 90
    local maxDist = Options.SilentDistance or 500
    local targetPart = Options.SilentPart or "Head"

    local best, bestDist = nil, fov

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Toggles.SilentTeamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
            continue
        end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = char:FindFirstChild(targetPart) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local dist = (part.Position - lpRoot.Position).Magnitude
        if dist > maxDist then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if screenDist <= fov and screenDist < bestDist then
            bestDist = screenDist
            best = part
        end
    end

    if not best then return nil end
    if Toggles.SilentWallCheck and not IsVisible(best) then return nil end
    return best
end

local function IsOurCall()
    if not checkcaller then return false end
    local ok, res = pcall(checkcaller)
    return ok and res == true
end

-- // Rivals shoots through the client Utility module:
-- // Utility.Raycast(origin, target, distance, filter, ...)
-- // weapon raycasts use distance 999 or 400 -> redirect the endpoint.
local oldRaycast = nil
local hooking = false
local Utility
pcall(function()
    Utility = require(ReplicatedStorage.Modules.Utility)
end)

if Utility and typeof(Utility.Raycast) == "function" and hookfunction then
    oldRaycast = Utility.Raycast
    hookfunction(Utility.Raycast, function(self, origin, target, distance, filter, ...)
        if Toggles.SilentAim
            and not IsOurCall()
            and (distance == 999 or distance == 400)
        then
            local chance = Options.SilentChance or 100
            if chance >= 100 or math.random(1, 100) <= chance then
                local hit = GetClosestTarget()
                if hit then
                    target = hit.Position
                end
            end
        end
        return oldRaycast(self, origin, target, distance, filter, ...)
    end)
    hooking = true
end

-- // fallback for executors without hookfunction/checkcaller:
-- // snap the camera to the target for one frame on click.
if not hooking then
    local function OnFire()
        local target = GetClosestTarget()
        if not target then return end
        local saved = Camera.CFrame
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        task.spawn(function()
            task.wait()
            Camera.CFrame = saved
        end)
    end
    table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            OnFire()
        end
    end))
end

local module = {}
module.Unload = function()
    Toggles.SilentAim = false
    if hooking and Utility and oldRaycast then
        pcall(function()
            hookfunction(Utility.Raycast, oldRaycast)
        end)
    end
end

return module
