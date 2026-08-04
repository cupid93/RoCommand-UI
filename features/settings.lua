-- // settings.lua - runs in main.lua scope (Window, Sections, UnloadScript available)
local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Defaults = getgenv().Defaults

local Menu = Sections.Settings.Menu
local Config = Sections.Settings.Config

-- // make sure the config folder exists
local ConfigFolder = "Lumia/"
if isfolder and makefolder then
    pcall(function()
        if not isfolder(ConfigFolder) then
            makefolder(ConfigFolder)
        end
    end)
end

local function NormalizeKey(k)
    if typeof(k) == "table" then
        if k[1] and k[2] then
            return Enum[k[1]][k[2]]
        end
        return nil
    end
    return k
end

-- // UI Toggle Keybind
Menu:keybind({
    name = "UI Keybind",
    def = Window.key or Enum.KeyCode.RightShift,
    pointer = "UIKeybind",
    callback = function(k)
        Window:setkey(NormalizeKey(k))
    end
})

-- // Accent color (menu theme)
local AccentPicker = Menu:colorpicker({
    name = "Accent Color",
    def = Window.theme.accent,
    pointer = "AccentColor",
    callback = function(c)
        Window:settheme("accent", c)
    end
})

-- // Theme presets
local Themes = {
    Default = Color3.fromRGB(255, 58, 81),
    Red     = Color3.fromRGB(255, 58, 81),
    Blue    = Color3.fromRGB(66, 135, 245),
    Green   = Color3.fromRGB(70, 200, 120),
    Purple  = Color3.fromRGB(168, 52, 235),
    Orange  = Color3.fromRGB(255, 140, 40),
    White   = Color3.fromRGB(230, 230, 230),
}

Menu:dropdown({
    name = "Theme",
    def = "Default",
    options = {"Default", "Red", "Blue", "Green", "Purple", "Orange", "White"},
    callback = function(option)
        local color = Themes[option]
        if color then
            Window:settheme("accent", color)
            if AccentPicker and AccentPicker.set then
                AccentPicker:set(color)
            end
        end
    end
})

-- // Watermark
local Watermark = Window:watermark()
Watermark:toggle(false)

Menu:toggle({
    name = "Watermark",
    def = false,
    pointer = "Watermark",
    callback = function(v)
        Watermark:toggle(v)
        if v then
            Watermark:update({ ["Lumia"] = "rocommand.tech" })
        end
    end
})

-- // Unload
Menu:button({
    name = "Unload Script",
    callback = function()
        UnloadScript()
    end
})

-- // Reset config back to defaults
local function ResetConfig()
    local D = getgenv().Defaults
    if not D then return end

    for k, v in pairs(D.Toggles) do
        getgenv().Toggles[k] = v
    end
    for k, v in pairs(D.Options) do
        getgenv().Options[k] = v
    end

    -- // sync the UI elements back to their defaults
    for _, page in pairs(Window.pointers) do
        for _, section in pairs(page) do
            for name, element in pairs(section) do
                if element and type(element.set) == "function" then
                    local val = D.Toggles[name]
                    if val == nil then val = D.Options[name] end
                    if val ~= nil then
                        pcall(element.set, element, val)
                    end
                end
            end
        end
    end
end

-- // Config section
Config:configloader({
    folder = ConfigFolder
})

Config:button({
    name = "Reset Config",
    callback = function()
        ResetConfig()
    end
})
