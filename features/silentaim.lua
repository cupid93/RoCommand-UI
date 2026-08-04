local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local IsVisible
local GetTargetPart
local ShouldRedirect

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

local function GetTargetPart()
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

local function ShouldRedirect()
    local chance = Options.SilentChance or 100
    if chance >= 100 then return true end
    return math.random(1, 100) <= chance
end

local function IsOurCall()
    if not checkcaller then return false end
    local ok, res = pcall(checkcaller)
    return ok and res == true
end

-- // find the client Utility module (may be at a different path after updates)
local function ResolveUtilityScript()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local u = modules:FindFirstChild("Utility")
        if u then return u end
    end
    local stack = {}
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Configuration") then
            table.insert(stack, child)
        end
    end
    while #stack > 0 do
        local parent = table.remove(stack)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "Utility" and child:IsA("ModuleScript") then
                return child
            end
            if child:IsA("Folder") or child:IsA("Configuration") then
                table.insert(stack, child)
            end
        end
    end
end

local installed = false
local HookedModule
local oldRaycast
local oldNamecall

-- // Layer 1: redirect the game's Utility.Raycast (Rivals fires weapon
-- // hitscan through this module with distance 999 or 400). Uses
-- // hookfunction when the executor has it, otherwise reassigns the
-- // module field directly (works on every executor).
local function InstallModuleHook()
    local script = ResolveUtilityScript()
    if not script then return false end
    local okReq, m = pcall(require, script)
    if not okReq or type(m) ~= "table" or type(m.Raycast) ~= "function" then
        return false
    end
    HookedModule = m

    local function Redirect(self, origin, target, distance, filter, ...)
        if Toggles.SilentAim
            and (distance == 999 or distance == 400)
            and ShouldRedirect()
        then
            local part = GetTargetPart()
            if part then
                target = part.Position
            end
        end
        return oldRaycast(self, origin, target, distance, filter, ...)
    end

    if hookfunction and checkcaller then
        oldRaycast = m.Raycast
        local okHook = pcall(hookfunction, m.Raycast, function(self, origin, target, distance, filter, ...)
            if Toggles.SilentAim
                and not IsOurCall()
                and (distance == 999 or distance == 400)
                and ShouldRedirect()
            then
                local part = GetTargetPart()
                if part then
                    target = part.Position
                end
            end
            return oldRaycast(self, origin, target, distance, filter, ...)
        end)
        if okHook then
            installed = true
            return true
        end
    end

    oldRaycast = m.Raycast
    local okSet = pcall(function()
        m.Raycast = Redirect
    end)
    if okSet then
        installed = true
        return true
    end
    return false
end

-- // Layer 2: if the module hook could not be installed, redirect
-- // workspace:Raycast calls made while firing (universal method).
local function InstallNamecall()
    if not hookmetamethod or not getnamecallmethod then return false end
    local ok, nm = pcall(hookmetamethod, game, "__namecall", function(...)
        local args = {...}
        local self = args[1]
        local method = getnamecallmethod()
        if self == workspace
            and method == "Raycast"
            and not IsOurCall()
            and Toggles.SilentAim
            and IsFiring()
            and ShouldRedirect()
        then
            local part = GetTargetPart()
            if part and type(args[2]) == "Vector3" then
                args[3] = (part.Position - args[2]).Unit * 1000
            end
        end
        return nm(...)
    end)
    if ok then
        oldNamecall = nm
        installed = true
        return true
    end
    return false
end

-- // firing state for the namecall layer
local LastClick = 0
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        LastClick = os.clock()
    end
end))

local function IsFiring()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return true
    end
    return os.clock() - LastClick <= 0.15
end

-- // Layer 3: last resort camera snap on click
if not InstallModuleHook() then
    if not InstallNamecall() then
        local function OnFire()
            local target = GetTargetPart()
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
end

local module = {}
module.Unload = function()
    Toggles.SilentAim = false
    if installed then
        pcall(function()
            if oldRaycast and HookedModule then
                HookedModule.Raycast = oldRaycast
            end
        end)
        pcall(function()
            if oldNamecall then
                hookmetamethod(game, "__namecall", oldNamecall)
            end
        end)
    end
end

return module
