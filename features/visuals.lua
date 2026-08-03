local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Toggles = getgenv().Toggles
local Options = getgenv().Options

local ESP = {}
local ESPObjects = {}

local function GetCamera()
    local camera = workspace.CurrentCamera
    if camera and camera.Parent then
        return camera
    end
    return nil
end

local function CreateESP(player)
    local obj = {
        Box = Drawing.new("Square"),
        HealthbarBG = Drawing.new("Square"),
        Healthbar = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Tool = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        Distance = Drawing.new("Text"),
    }

    obj.Box.Visible = false
    obj.Box.Color = Options.BoxColor
    obj.Box.Thickness = Options.BoxThickness
    obj.Box.Transparency = 1
    obj.Box.ZIndex = 50

    obj.HealthbarBG.Visible = false
    obj.HealthbarBG.Color = Color3.fromRGB(0, 0, 0)
    obj.HealthbarBG.Thickness = 1
    obj.HealthbarBG.Transparency = 1
    obj.HealthbarBG.ZIndex = 49

    obj.Healthbar.Visible = false
    obj.Healthbar.Color = Color3.fromRGB(0, 255, 0)
    obj.Healthbar.Thickness = 1
    obj.Healthbar.Transparency = 1
    obj.Healthbar.ZIndex = 48

    obj.Name.Visible = false
    obj.Name.Color = Options.NameColor
    obj.Name.Size = 13
    obj.Name.Center = true
    obj.Name.Outline = true
    obj.Name.OutlineColor = Color3.fromRGB(0, 0, 0)
    obj.Name.Font = Drawing.Fonts.UI
    obj.Name.ZIndex = 47

    obj.Tool.Visible = false
    obj.Tool.Color = Color3.fromRGB(255, 255, 255)
    obj.Tool.Size = 12
    obj.Tool.Center = true
    obj.Tool.Outline = true
    obj.Tool.OutlineColor = Color3.fromRGB(0, 0, 0)
    obj.Tool.Font = Drawing.Fonts.UI
    obj.Tool.ZIndex = 46

    obj.Tracer.Visible = false
    obj.Tracer.Color = Options.TracerColor
    obj.Tracer.Thickness = 1
    obj.Tracer.Transparency = 1
    obj.Tracer.ZIndex = 45

    obj.Distance.Visible = false
    obj.Distance.Color = Color3.fromRGB(255, 255, 255)
    obj.Distance.Size = 12
    obj.Distance.Center = true
    obj.Distance.Outline = true
    obj.Distance.OutlineColor = Color3.fromRGB(0, 0, 0)
    obj.Distance.Font = Drawing.Fonts.UI
    obj.Distance.ZIndex = 44

    ESPObjects[player] = obj
end

local function RemoveESP(player)
    local obj = ESPObjects[player]
    if not obj then return end

    for _, drawing in pairs(obj) do
        if type(drawing) == "table" and drawing.Remove then
            drawing:Remove()
        end
    end

    ESPObjects[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end)

Players.PlayerRemoving:Connect(RemoveESP)

local function GetBounds(char)
    local camera = GetCamera()
    if not camera then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")

    local topPos = (head and head.Position) or root.Position + Vector3.new(0, 3, 0)
    local bottomPos = root.Position - Vector3.new(0, 3, 0)

    local top, topOnScreen = camera:WorldToViewportPoint(topPos)
    local bottom, bottomOnScreen = camera:WorldToViewportPoint(bottomPos)

    if not topOnScreen and not bottomOnScreen then return end

    local height = (Vector2.new(top.X, top.Y) - Vector2.new(bottom.X, bottom.Y)).Magnitude
    local width = height * 0.6

    local center = Vector2.new(bottom.X, bottom.Y)

    return {
        TopLeft = Vector2.new(center.X - width / 2, center.Y - height),
        Size = Vector2.new(width, height),
        Bottom = Vector2.new(center.X, center.Y),
    }
end

RunService.RenderStepped:Connect(function()
    local camera = GetCamera()

    for _, obj in pairs(ESPObjects) do
        obj.Box.Visible = false
        obj.HealthbarBG.Visible = false
        obj.Healthbar.Visible = false
        obj.Name.Visible = false
        obj.Tool.Visible = false
        obj.Tracer.Visible = false
        obj.Distance.Visible = false
    end

    if not Toggles.ESPEnabled then return end
    if not camera then return end

    for player, obj in pairs(ESPObjects) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hum or not root then continue end
        if hum.Health <= 0 or hum.MaxHealth <= 0 then continue end

        if Toggles.TeamCheck then
            if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                continue
            end
        end

        local bounds = GetBounds(char)
        if not bounds then continue end

        local distance = math.round((root.Position - camera.CFrame.Position).Magnitude)

        if Toggles.Box then
            obj.Box.Color = Options.BoxColor
            obj.Box.Thickness = Options.BoxThickness
            obj.Box.Position = bounds.TopLeft
            obj.Box.Size = bounds.Size
            obj.Box.Visible = true
        end

        if Toggles.Healthbar then
            local health = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local healthColor = Color3.fromRGB(
                math.clamp(255 * (1 - health) * 2, 0, 255),
                math.clamp(255 * health * 2, 0, 255),
                0
            )

            obj.HealthbarBG.Color = Color3.fromRGB(0, 0, 0)
            obj.HealthbarBG.Position = Vector2.new(bounds.TopLeft.X - 6, bounds.TopLeft.Y)
            obj.HealthbarBG.Size = Vector2.new(4, bounds.Size.Y)
            obj.HealthbarBG.Visible = true

            obj.Healthbar.Color = healthColor
            obj.Healthbar.Position = Vector2.new(bounds.TopLeft.X - 6, bounds.TopLeft.Y + bounds.Size.Y * (1 - health))
            obj.Healthbar.Size = Vector2.new(4, bounds.Size.Y * health)
            obj.Healthbar.Visible = true
        end

        if Toggles.NameTags then
            obj.Name.Color = Options.NameColor
            obj.Name.Position = Vector2.new(bounds.TopLeft.X + bounds.Size.X / 2, bounds.TopLeft.Y - 16)
            obj.Name.Text = player.DisplayName
            obj.Name.Visible = true
        end

        if Toggles.Tool then
            local tool = char:FindFirstChildOfClass("Tool")
            obj.Tool.Position = Vector2.new(bounds.TopLeft.X + bounds.Size.X / 2, bounds.TopLeft.Y - 4)
            obj.Tool.Text = tool and tool.Name or "No Tool"
            obj.Tool.Visible = true
        end

        if Toggles.Tracers then
            obj.Tracer.Color = Options.TracerColor
            obj.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            obj.Tracer.To = bounds.Bottom
            obj.Tracer.Visible = true
        end

        if Toggles.Distance then
            obj.Distance.Position = Vector2.new(bounds.TopLeft.X + bounds.Size.X / 2, bounds.Bottom.Y + 4)
            obj.Distance.Text = tostring(distance) .. " studs"
            obj.Distance.Visible = true
        end
    end
end)

return ESP
