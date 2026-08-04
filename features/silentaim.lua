local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local IsVisible, GetTargetPart, ShouldRedirect, IsOurCall, IsFiring

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

-- // firing state: active while MouseButton1 is held or ~0.15s after a click
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

-- // Layer 1 (primary): hook engine raycasts via __namecall.
-- // This catches Utility.Raycast (which calls workspace:Raycast internally)
-- // without requiring any game module, so it can't trip the module honeypot.
local installed = false
local oldNamecall
local InHook = false

if hookmetamethod and getnamecallmethod then
    local ok, nm = pcall(hookmetamethod, game, "__namecall", function(...)
        local args = {...}
        local self = args[1]
        local method = getnamecallmethod()

        if self == workspace
            and not InHook
            and not IsOurCall()
            and Toggles.SilentAim
            and IsFiring()
            and ShouldRedirect()
        then
            local isRaycast = method == "Raycast"
            local isRay = method == "FindPartOnRay"
                or method == "FindPartOnRayWithIgnoreList"
                or method == "FindPartOnRayWithWhitelist"

            if isRaycast or isRay then
                InHook = true
                local part = GetTargetPart()
                InHook = false

                if part then
                    if isRaycast and type(args[2]) == "Vector3" then
                        args[3] = (part.Position - args[2]).Unit * 1000
                    elseif isRay and typeof(args[2]) == "Ray" then
                        args[2] = Ray.new(args[2].Origin, (part.Position - args[2].Origin).Unit * 1000)
                    end
                end
            end
        end

        return nm(...)
    end)

    if ok then
        oldNamecall = nm
        installed = true
    end
end

-- // Layer 2 (fallback): camera snap on click for executors without
-- // hookmetamethod support.
if not installed then
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

local module = {}
module.Unload = function()
    Toggles.SilentAim = false
    if installed and oldNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", oldNamecall)
        end)
    end
end

return module
