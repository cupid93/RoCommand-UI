local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

-- // character ref, kept fresh on respawn
local LocalChar = LocalPlayer.Character

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

-- // shared target state (mirrors testfile states.target / target_part)
local State = {
    target = nil,
    target_part = nil,
    target_position = nil,
    server_cf = nil,
    blocking = {},
}

local function GetPing()
    local ping = Stats.Network.ServerStatsItem:FindFirstChild("Ping")
    return (ping and ping.Value or 0) / 1000
end

--[[
    WallCheck (from testfile targeting_state.wallcheck)
]]
local WallCheckCache = {}
local WallCheckTTL = 0.15
local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
RaycastParams.IgnoreWater = true
RaycastParams.FilterDescendantsInstances = { LocalChar }

LocalPlayer.CharacterAdded:Connect(function(char)
    LocalChar = char
    RaycastParams.FilterDescendantsInstances = { char }
end)

local function WallCheck(character, part)
    if not Toggles.SilentWallCheck then
        return true
    end

    local char_cache = WallCheckCache[character]
    if not char_cache then
        char_cache = {}
        WallCheckCache[character] = char_cache
    end

    local now = os.clock()
    local cached = char_cache[part]
    if cached and (now - cached.time) < WallCheckTTL then
        return cached.value
    end

    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, RaycastParams)
    local passed = not result or result.Instance:IsDescendantOf(character)

    char_cache[part] = {
        time = now,
        value = passed,
    }

    return passed
end

--[[
    FindBestTarget (from testfile: TeamID check, include parts, max distance,
    FOV gate, weighted screen+world score, wallcheck)
]]
local WeightRatio = 0.7

local function FindBestTarget()
    local origin = Camera.CFrame.Position
    local center = Camera.ViewportSize / 2
    local fov_radius = Options.SilentFOV or 150
    local max_distance = Options.SilentMaxDistance or 150
    local include_parts = { Options.SilentPart or "Head" }
    local target_group = "FOV"

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

        if Toggles.SilentTeamCheck then
            local their_team = player:GetAttribute("TeamID")
            if their_team and their_team == LocalPlayer:GetAttribute("TeamID") then
                continue
            end
        end

        if State.blocking[player.Name] then
            continue
        end

        local root_dist = (root.Position - origin).Magnitude
        if root_dist > (max_distance + 6) then
            continue
        end

        local closest_part = nil
        local closest = math.huge

        for _, part_name in ipairs(include_parts) do
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
            local radius_sq = fov_radius * fov_radius

            if target_group == "FOV" and screen_dist > radius_sq then
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

        if not WallCheck(character, closest_part) then
            continue
        end

        best_distance = closest
        best_player = player
        best_part = closest_part
    end

    return best_player, best_part
end

--[[
    Target tracking (from testfile: pending/current with reaction + forget time)
]]
local ReactionTime = 0
local ForgetTime = 1
local TargetScanInterval = 0.03

local PendingPlayer, PendingPart, PendingTime
local CurrentPlayer, CurrentPart, CurrentLostTime
local NextSearch = 0

local function ClearTarget()
    CurrentPlayer = nil
    CurrentPart = nil
    CurrentLostTime = 0
    State.target = nil
    State.target_part = nil
    State.target_position = nil
end

-- // prediction support on top of the testfile pipeline
local function UpdateTargetPosition()
    local part = State.target_part
    if not part then
        State.target_position = nil
        return
    end

    local pos = part.Position
    if Toggles.SilentPrediction and part.Velocity then
        pos = pos + part.Velocity * GetPing()
    end

    State.target_position = pos
end

--[[
    FindValidPosition / GetCachedValidPosition (manipulation offsets)
]]
local Candidates = {
    Vector3.new(5, 3, 5),
    Vector3.new(-5, 3, 5),
    Vector3.new(5, 3, -5),
    Vector3.new(-5, 3, -5),

    Vector3.new(0, 5, 8),
    Vector3.new(0, 5, -8),
}

local OverlapParams = OverlapParams.new()
OverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function FindValidPosition(target)
    OverlapParams.FilterDescendantsInstances = { LocalChar }
    RayParams.FilterDescendantsInstances = { LocalChar }

    local target_pos = target.Position
    local target_model = target.Parent

    for i = 1, #Candidates do
        local offset = Candidates[i]
        local pos = target_pos + offset

        local result = workspace:Raycast(pos, target_pos - pos, RayParams)
        if not result or result.Instance:IsDescendantOf(target_model) then
            local parts = workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(3, 6, 3), OverlapParams)

            local blocked = false
            for j = 1, #parts do
                if parts[j].CanCollide then
                    blocked = true
                    break
                end
            end

            if not blocked then
                return offset
            end
        end
    end

    return nil
end

local ValidPositionCache = {}
local ValidPositionTTL = 0.5

local function GetCachedValidPosition(target)
    if not target or not target.Parent then
        return nil
    end

    local now = os.clock()
    local entry = ValidPositionCache[target]
    if entry and now - entry.time < ValidPositionTTL then
        return entry.value
    end

    local value = FindValidPosition(target)
    ValidPositionCache[target] = {
        value = value,
        time = now,
    }

    return value
end

--[[
    Server CF backbone (from testfile): PostSimulation captures the real CFrame,
    then pins the (fake) server_cf; a RenderStep restores the real CFrame so the
    physics engine doesn't fight the desync. Used by manipulation.
]]
local ServerCFSync = true
local RealCF
local RealLinVel
local RealAngVel
local RenderStepName = tostring(math.random(100000, 999999))
local ServerCFBound = false

local function EnableServerCF()
    if ServerCFBound then return end
    ServerCFBound = true

    RunService:BindToRenderStep(RenderStepName, 0, function()
        local root = LocalChar and LocalChar.PrimaryPart
        if not root or not root.Parent or not RealCF then
            return
        end
        root.AssemblyLinearVelocity = RealLinVel or Vector3.zero
        root.AssemblyAngularVelocity = RealAngVel or Vector3.zero
        root.CFrame = RealCF
    end)
end

table.insert(Connections, RunService.PostSimulation:Connect(function()
    local root = LocalChar and LocalChar.PrimaryPart
    if not root or not root.Parent then
        return
    end

    RealCF = root.CFrame
    RealLinVel = root.AssemblyLinearVelocity
    RealAngVel = root.AssemblyAngularVelocity

    if ServerCFSync then
        State.server_cf = RealCF
    end

    root.CFrame = State.server_cf or RealCF
end))

--[[
    Manipulation (from testfile): fake origin CFrame applied during the shot,
    stopped on mouse release.
]]
local ManipCF
local ManipConn
local Manipulating = false
local ManipVisualizer = nil
local ManipVisualizerConns = {}
local LastManipUpdate = 0
local ManipUpdateInterval = 0.02

local function DestroyManipVisualizer()
    if ManipVisualizer then
        ManipVisualizer:Destroy()
        ManipVisualizer = nil
    end
    for _, conn in ipairs(ManipVisualizerConns) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(ManipVisualizerConns)
end

local function CreateManipVisualizer()
    if ManipVisualizer then return end

    local root = LocalChar and LocalChar.PrimaryPart
    if not root then return end

    ManipVisualizer = Instance.new("Part")
    ManipVisualizer.Name = "LumiaManip"
    ManipVisualizer.Material = Enum.Material.Neon
    ManipVisualizer.Size = root.Size
    ManipVisualizer.Color = Color3.fromRGB(0, 255, 255)
    ManipVisualizer.CanCollide = false
    ManipVisualizer.CanQuery = false
    ManipVisualizer.CanTouch = false
    ManipVisualizer.CFrame = ManipCF or root.CFrame
    ManipVisualizer.Parent = workspace

    table.insert(ManipVisualizerConns, root.Destroying:Connect(function()
        if ManipVisualizer then
            ManipVisualizer:Destroy()
            ManipVisualizer = nil
        end
    end))

    table.insert(ManipVisualizerConns, root.AncestryChanged:Connect(function(_, parent)
        if not parent and ManipVisualizer then
            ManipVisualizer:Destroy()
            ManipVisualizer = nil
        end
    end))
end

local function EnsureManipVisualizer()
    if not Toggles.SilentVisualize then
        DestroyManipVisualizer()
        return
    end

    if not ManipVisualizer then
        CreateManipVisualizer()
    elseif ManipCF then
        ManipVisualizer.CFrame = ManipCF
    end
end

local function ApplyManipulation()
    if not Manipulating or not ManipCF then
        return
    end

    local root = LocalChar and LocalChar.PrimaryPart
    if root and root.Parent then
        root.CFrame = ManipCF
    end

    State.server_cf = ManipCF
end

local StartManipulation = Instance.new("BindableEvent")
StartManipulation.Parent = nil

StartManipulation.Event:Connect(function(cf)
    ServerCFSync = false

    ManipCF = cf
    Manipulating = true
    LastManipUpdate = 0

    ApplyManipulation()

    if not ManipConn then
        ManipConn = RunService.RenderStepped:Connect(function()
            if not Manipulating or not ManipCF then
                return
            end

            if not Toggles.SilentManipulation then
                StopManipulation()
                return
            end

            local now = os.clock()
            if now - LastManipUpdate < ManipUpdateInterval then
                return
            end
            LastManipUpdate = now

            ApplyManipulation()
            EnsureManipVisualizer()
        end)
    end

    EnsureManipVisualizer()
end)

local function StopManipulation()
    Manipulating = false
    ManipCF = nil
    LastManipUpdate = 0

    if ManipConn then
        ManipConn:Disconnect()
        ManipConn = nil
    end

    DestroyManipVisualizer()
    ServerCFSync = true
end

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if Manipulating and input.UserInputType == Enum.UserInputType.MouseButton1 then
        StopManipulation()
    end
end))

--[[
    StartShooting hook (from testfile): rewrite the shot payload to the target.
]]
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

local function TryInstall()
    if Installed then return true end

    pcall(function()
        Modules = require(ReplicatedStorage:WaitForChild("Modules"))
    end)

    if not Modules or type(Modules.Gun) ~= "table" or type(Modules.Gun.StartShooting) ~= "function" then
        print("[SilentAim] Gun module not found, retrying while enabled")
        return false
    end

    EnableServerCF()

    OriginalStartShooting = Modules.Gun.StartShooting
    Modules.Gun.StartShooting = function(self, ...)
        local ok, results = pcall(function()
            if not self or not self.ClientFighter or not self.ClientFighter.IsLocalPlayer then
                return nil
            end

            local part = State.target_part
            if not part or not part.Parent then
                return nil
            end

            local shot_results = {OriginalStartShooting(self, ...)}
            if shot_results[1] ~= true or shot_results[2] ~= "StartShooting" then
                return shot_results
            end

            if not Toggles.SilentAim then
                return shot_results
            end

            local root = LocalChar and LocalChar.PrimaryPart
            if not root then
                return shot_results
            end

            local hit_chance = Options.SilentHitChance or 100
            if math.random(1, 100) > hit_chance then
                return shot_results
            end

            local origin = root.Position
            local target = State.target_position or part.Position

            if Toggles.SilentManipulation then
                local offset = GetCachedValidPosition(part) or Vector3.new(0, 5, 5)
                local fake_cf = part.CFrame * CFrame.new(offset)
                StartManipulation:Fire(fake_cf)
                origin = fake_cf.Position
            end

            local payload = BuildShotPayload(origin, target, part)
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
    local now = os.clock()

    if not (Toggles.SilentAim or Toggles.ShowSilentFOV) then
        if CurrentPlayer then
            ClearTarget()
        end
        FOVCircle.Visible = false
        return
    end

    FOVCircle.Position = Camera.ViewportSize / 2
    FOVCircle.Radius = Options.SilentFOV or 150
    FOVCircle.Color = Options.SilentFOVColor or Color3.fromRGB(33, 150, 243)
    FOVCircle.Thickness = Options.SilentFOVThickness or 1
    FOVCircle.Transparency = 0
    FOVCircle.Visible = Toggles.ShowSilentFOV

    if State.target_part and State.target_part.Parent then
        UpdateTargetPosition()
    else
        State.target_part = nil
        State.target_position = nil
    end

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
                State.target = best_player
                State.target_part = best_part
                State.target_position = nil
            end
        end

        return
    end

    if not CurrentPlayer then
        CurrentLostTime = 0
        return
    end

    if ForgetTime <= 0 then
        ClearTarget()
        return
    end

    if CurrentLostTime == 0 then
        CurrentLostTime = now
        return
    end

    if now - CurrentLostTime >= ForgetTime then
        ClearTarget()
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
            StopManipulation()
        end)

        pcall(function()
            RunService:UnbindFromRenderStep(RenderStepName)
        end)

        pcall(function()
            if LocalChar and LocalChar.PrimaryPart then
                LocalChar.PrimaryPart.CFrame = RealCF or State.server_cf or LocalChar.PrimaryPart.CFrame
            end
        end)

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
