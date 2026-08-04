local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Toggles = getgenv().Toggles
local Options = getgenv().Options

local EnemyDots = {}
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local RadarBG = Drawing.new("Circle")
RadarBG.Thickness = 2
RadarBG.NumSides = 64
RadarBG.Filled = true
RadarBG.Transparency = 0.4
RadarBG.Color = Color3.fromRGB(25, 25, 30)
RadarBG.Visible = false
RadarBG.ZIndex = 60

local RadarRing = Drawing.new("Circle")
RadarRing.Thickness = 2
RadarRing.NumSides = 64
RadarRing.Filled = false
RadarRing.Color = Color3.fromRGB(255, 255, 255)
RadarRing.Visible = false
RadarRing.ZIndex = 61

local CrossV = Drawing.new("Line")
CrossV.Thickness = 1
CrossV.Color = Color3.fromRGB(110, 110, 110)
CrossV.Transparency = 1
CrossV.Visible = false
CrossV.ZIndex = 60

local CrossH = Drawing.new("Line")
CrossH.Thickness = 1
CrossH.Color = Color3.fromRGB(110, 110, 110)
CrossH.Transparency = 1
CrossH.Visible = false
CrossH.ZIndex = 60

local CenterDot = Drawing.new("Square")
CenterDot.Size = Vector2.new(8, 8)
CenterDot.Filled = true
CenterDot.Transparency = 1
CenterDot.Color = Color3.fromRGB(255, 255, 255)
CenterDot.Visible = false
CenterDot.ZIndex = 62

local FacingLine = Drawing.new("Line")
FacingLine.Thickness = 2
FacingLine.Color = Color3.fromRGB(120, 200, 255)
FacingLine.Transparency = 1
FacingLine.Visible = false
FacingLine.ZIndex = 61

local RadarLabel = Drawing.new("Text")
RadarLabel.Text = "RADAR"
RadarLabel.Size = 11
RadarLabel.Center = true
RadarLabel.Outline = true
RadarLabel.Color = Color3.fromRGB(255, 255, 255)
RadarLabel.Visible = false
RadarLabel.ZIndex = 62

local function GetCamera()
    local camera = workspace.CurrentCamera
    if camera and camera.Parent then return camera end
    return nil
end

local function GetRoot(character)
    if not character or not character.Parent then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

local function CreateDot(player)
    local dot = Drawing.new("Square")
    dot.Size = Vector2.new(7, 7)
    dot.Filled = true
    dot.Transparency = 1
    dot.Color = Options.RadarDotColor
    dot.Visible = false
    dot.ZIndex = 62
    EnemyDots[player] = dot
end

local function RemoveDot(player)
    local dot = EnemyDots[player]
    if dot then
        pcall(function()
            dot.Visible = false
            dot:Remove()
        end)
        EnemyDots[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateDot(player)
    end
end

table.insert(Connections, Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        CreateDot(player)
    end
end))

table.insert(Connections, Players.PlayerRemoving:Connect(RemoveDot))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    RadarBG.Visible = false
    RadarRing.Visible = false
    CrossV.Visible = false
    CrossH.Visible = false
    CenterDot.Visible = false
    FacingLine.Visible = false
    RadarLabel.Visible = false
    for _, dot in pairs(EnemyDots) do
        dot.Visible = false
    end

    if not Toggles.Radar then return end

    pcall(function()
        local camera = GetCamera()
        if not camera then return end

        local size = Options.RadarSize
        local range = Options.RadarRange
        local cx = size + 50
        local cy = camera.ViewportSize.Y - size - 50

        RadarBG.Position = Vector2.new(cx, cy)
        RadarBG.Radius = size
        RadarBG.Visible = true

        RadarRing.Position = Vector2.new(cx, cy)
        RadarRing.Radius = size
        RadarRing.Visible = true

        CrossV.From = Vector2.new(cx, cy - size)
        CrossV.To = Vector2.new(cx, cy + size)
        CrossV.Visible = true

        CrossH.From = Vector2.new(cx - size, cy)
        CrossH.To = Vector2.new(cx + size, cy)
        CrossH.Visible = true

        CenterDot.Position = Vector2.new(cx - 4, cy - 4)
        CenterDot.Visible = true

        local lpRoot = GetRoot(LocalPlayer.Character)
        if lpRoot then
            local look = lpRoot.CFrame.LookVector
            FacingLine.From = Vector2.new(cx, cy)
            FacingLine.To = Vector2.new(cx + look.X * size * 0.35, cy - look.Z * size * 0.35)
            FacingLine.Visible = true
        else
            FacingLine.Visible = false
        end

        RadarLabel.Position = Vector2.new(cx, cy + size + 14)
        RadarLabel.Visible = true

        local scale = (size - 10) / range
        local lpPos = lpRoot and lpRoot.Position
        local lpTeam = LocalPlayer.Team

        for player, dot in pairs(EnemyDots) do
            if not lpPos then continue end

            local root = GetRoot(player.Character)
            if not root then continue end

            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then continue end

            if Toggles.RadarTeamCheck then
                if lpTeam and player.Team and lpTeam == player.Team then
                    continue
                end
            end

            local delta = root.Position - lpPos
            if delta.Magnitude > range then continue end

            dot.Position = Vector2.new(cx + delta.X * scale - 3.5, cy - delta.Z * scale - 3.5)
            dot.Color = Options.RadarDotColor
            dot.Visible = true
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
        for _, dot in pairs(EnemyDots) do
            pcall(function()
                dot.Visible = false
                dot:Remove()
            end)
        end
        for k in pairs(EnemyDots) do
            EnemyDots[k] = nil
        end
        pcall(function()
            RadarBG:Remove()
            RadarRing:Remove()
            CrossV:Remove()
            CrossH:Remove()
            CenterDot:Remove()
            FacingLine:Remove()
            RadarLabel:Remove()
        end)
    end
}
