local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

-- ═══════════════════════════════════════════════
-- SKIN LISTS
-- ═══════════════════════════════════════════════
local SkinLists = {
    ["Assault Rifle"] = {"Default", "AK-47", "AUG", "Tommy Gun", "Boneclaw Rifle", "Gingerbread AUG", "AKEY-47", "100K Visits", "10 Billion Visits", "Phoenix Rifle"},
    ["Bow"] = {"Default", "Compound Bow", "Raven Bow", "Dream Bow", "Bat Bow", "Frostbite Bow", "Beloved Bow", "Balloon Bow", "Glorious Bow", "Key Bow", "Arch Bow"},
    ["Burst Rifle"] = {"Default", "Electro Burst", "Aqua Burst", "FAMAS", "Spectral Burst", "Pine Burst"},
    ["Crossbow"] = {"Default", "Pixel Crossbow", "Harpoon Crossbow", "Violin Crossbow", "Crossbone", "Frostbite Crossbow", "Arch Crossbow", "Glorious Crossbow"},
    ["Distortion"] = {"Default", "Plasma Distortion", "Magma Distortion", "Cyber Distortion", "Expirement D15", "Sleighstortion"},
    ["Energy Rifle"] = {"Default", "Hacker Rifle", "Hydro Rifle", "Void Rifle", "Soul Rifle", "New Years Energy Rifle"},
    ["Flamethrower"] = {"Default", "Pixel Flamethrower", "Lamethrower", "Glitterthrower", "Jack O' Thrower", "Snowblower", "Keythrower", "Rainbowthrower"},
    ["Grenade Launcher"] = {"Default", "Swashbuckler", "Uranium Launcher", "Gearnade Launcher", "Skull Grenade Launcher", "Snowball Launcher"},
    ["Gunblade"] = {"Default", "Hyper Gunblade", "Crude Gunblade", "Gunsaw", "Boneblade", "Elf's Gunblade"},
    ["Minigun"] = {"Default", "Lasergun 3000", "Pixel Minigun", "Fighter Jet", "Pumpkin Minigun", "Wrapped Minigun"},
    ["Paintball Gun"] = {"Default", "Slime Gun", "Boba Gun", "Ketchup Gun", "Brain Gun", "Snowball Gun"},
    ["RPG"] = {"Default", "Nuke Launcher", "Spaceship Launcher", "Squid Launcher", "Pumpkin Launcher", "Firework Launcher"},
    ["Shotgun"] = {"Default", "Balloon Shotgun", "Hyper Shotgun", "Cactus Shotgun", "Broomstick", "Wrapped Shotgun"},
    ["Sniper"] = {"Default", "Pixel Sniper", "Hyper Sniper", "Event Horizon", "Eyething Sniper", "Gingerbread Sniper", "Keyper", "Glorious Sniper"},
    ["Daggers"] = {"Default", "Aces", "Paper Planes", "Shurikens", "Bat Daggers", "Cookies", "Crystal Daggers", "Keynais"},
    ["Energy Pistols"] = {"Default", "Void Pistols", "Hydro Pistols", "Soul Pistols", "New Years Energy Pistols"},
    ["Exogun"] = {"Default", "Singularity", "Raygun", "Repulsor", "Exogourd", "Midnight Festive Exogun"},
    ["Flare Gun"] = {"Default", "Firework Gun", "Dynamite Gun", "Banana Flare", "Vexed Flare Gun", "Wrapped Flare Gun"},
    ["Handgun"] = {"Default", "Blaster", "Hand Gun", "Gumball Handgun", "Pumpkin Handgun", "Gingerbread Handgun"},
    ["Revolver"] = {"Default", "Desert Eagle", "Sheriff", "Peppergun", "Boneclaw Revolver", "Peppermint Sheriff"},
    ["Shorty"] = {"Default", "Not So Shorty", "Lovely Shorty", "Balloon Shorty", "Demon Shorty", "Wrapped Shorty"},
    ["Slingshot"] = {"Default", "Stick", "Goal Post", "Harp", "Boneshot", "Reindeer Slingshot", "Lucky Horseshoe"},
    ["Spray"] = {"Default", "Lovely Spray", "Nail Gun", "Bottle Spray", "Boneclaw Spray", "Pine Spray", "Key Spray"},
    ["Uzi"] = {"Default", "Water Uzi", "Electro Uzi", "Money Gun", "Demon Uzi", "Pine Uzi"},
    ["Warper"] = {"Default", "Glitter Warper", "Arcane Warper", "Hotel Bell", "Experiment W4", "Frost Warper"},
    ["Battle Axe"] = {"Default", "The Shred", "Ban Axe", "Cerulean Axe", "Mimic Axe", "Nordic Axe"},
    ["Chainsaw"] = {"Default", "Blobsaw", "Handsaws", "Mega Drill", "Buzzsaw", "Festive Buzzsaw"},
    ["Fists"] = {"Default", "Boxing Gloves", "Brass Knuckles", "Fists Of Hurt", "Pumpkin Claws", "Festive Fists"},
    ["Katana"] = {"Default", "Saber", "Lightning Bolt", "Stellar Katana", "Evil Trident", "New Years Katana", "Keytana", "Arch Katana", "Crystal Katana", "Pixel Katana", "Glorious Katana"},
    ["Knife"] = {"Default", "Chancla", "Karambit", "Balisong", "Machete", "Candy Cane", "Keylisong", "Keyrambit", "Caladbolg"},
    ["Riot Shield"] = {"Default", "Door", "Energy Shield", "Masterpiece", "Tombstone Shield", "Sled"},
    ["Scythe"] = {"Default", "Scythe of Death", "Anchor", "Sakura Scythe", "Bat Scythe", "Cryo Scythe", "Crystal Scythe", "Keythe", "Bug Net", "Arch Scythe"},
    ["Trowel"] = {"Default", "Plastic Shovel", "Garden Shovel", "Paintbrush", "Pumpkin Carver", "Snow Shovel"},
    ["Flashbang"] = {"Default", "Disco Ball", "Camera", "Lightbulb", "Skullbang", "Shining Star"},
    ["Freeze Ray"] = {"Default", "Temporal Ray", "Bubble Ray", "Gum Ray", "Spider Ray", "Wrapped Freeze Ray"},
    ["Grenade"] = {"Default", "Whoopee Cushion", "Water Balloon", "Dynamite", "Soul Grenade", "Jingle Grenade"},
    ["Jump Pad"] = {"Default", "Trampoline", "Bounce House", "Shady Chicken Sandwich", "Spider Web", "Jolly Man"},
    ["Medkit"] = {"Default", "Sandwich", "Laptop", "Medkitty", "Bucket of Candy", "Milk & Cookies", "Box of Chocolates", "Briefcase"},
    ["Molotov"] = {"Default", "Coffee", "Torch", "Lava Lamp", "Vexed Candle", "Hot Coals", "Arch Molotov"},
    ["Satchel"] = {"Default", "Advanced Satchel", "Notebook Satchel", "Bag O' Money", "Potion Satchel", "Suspicious Gift"},
    ["Smoke Grenade"] = {"Default", "Emoji Cloud", "Balance", "Hourglass", "Eyeball", "Snowglobe"},
    ["Subspace Tripmine"] = {"Default", "Don't Press", "Spring", "DIY Tripmine", "Trick or Treat", "Dev In the Box", "Pot O Keys"},
    ["War Horn"] = {"Default", "Trumpet", "Megaphone", "Air Horn", "Boneclaw Horn", "Mammoth Horn"},
    ["Warpstone"] = {"Default", "Cyber Warpstone", "Teleport Disc", "Electropunk Warpstone", "Warpbone", "Warpstar"},
    ["Permafrost"] = {"Default", "Snowman Permafrost", "Ice Permafrost", "Glorious Permafrost"},
}

local WrapList = {
    "None", "Gold", "Diamond", "Midas Touch", "Community Wrap", "Blush Wrapping", "Brain", "Crystalliz",
    "Damascus", "Black Damascus", ".exe wrap", "Groove", "Hollow Wrap", "Hesper", "Hyperdrive",
    "Gingerbread", "Neon Lights", "Hologram Arena", "Sunset", "Pink Lemonade", "Lovely Leopard",
    "Dawn", "Spectral", "Danger", "Termination", "Moonstone", "Starfall", "Black Glass",
    "Rift Wrap", "Starblaze", "Maganite", "Watermelon", "Reptile", "Water", "OranGG", "A5", "Cheese",
    "Nova", "Supernova", "Glass", "Mesh", "Meat Wrap", "Black Dark Wrap", "Cardinal", "Pixel Camo",
    "Nauseite", "Sensite", "Urban Camo", "Frosted", "Slime Wrap", "Carpet Wrap", "Cross Wrap",
    "Mainframe Wrap", "Honeycomb Wrap", "Black Opal Wrap", "Patriot", "PB&J Wrap", "Digital Camo",
    "Street Camo", "Ocean Camo", "Circuit", "Clouds", "Woven", "Ladybug"
}

local Weapons = {}
for weapon in pairs(SkinLists) do
    table.insert(Weapons, weapon)
end
table.sort(Weapons)

local function GetSkins(weapon)
    return SkinLists[weapon] or {"Default"}
end

-- ═══════════════════════════════════════════════
-- GLOBAL STATE
-- ═══════════════════════════════════════════════
_G.EquippedData = _G.EquippedData or {}
for weapon in pairs(SkinLists) do
    if not _G.EquippedData[weapon] then
        _G.EquippedData[weapon] = {Skin = "Default", Wrap = "None"}
    end
end

-- ═══════════════════════════════════════════════
-- MODULE RESOLUTION (lazy, only when enabled)
-- ═══════════════════════════════════════════════
local CosmeticLibrary, ItemLibrary, ReplicatedClass, ClientViewModel
local Resolved = false
local Resolving = false

local function robust_require(module)
    local mName = tostring(module)
    if shared[mName] or _G[mName] then
        return (shared[mName] or _G[mName])
    end
    if getrenv and (getrenv()._G[mName] or getrenv().shared[mName]) then
        return (getrenv()._G[mName] or getrenv().shared[mName])
    end
    local old_identity
    pcall(function()
        if getidentity and setidentity then
            old_identity = getidentity()
            setidentity(2)
        end
    end)
    local success, result = pcall(require, module)
    pcall(function()
        if setidentity and old_identity then
            setidentity(old_identity)
        end
    end)
    if success and result then return result end

    local getupvalues = debug.getupvalues or getupvalues
    for _, api in ipairs({getgc, getregistry, debug.getregistry}) do
        if type(api) == "function" then
            local ok, objects = pcall(api, true)
            if ok and type(objects) == "table" then
                for _, v in pairs(objects) do
                    if type(v) == "table" then
                        if mName:find("CosmeticLibrary") and (v.Cosmetics or rawget(v, "Cosmetics")) and (type(v.Equip) == "function" or type(v.GetSkins) == "function") then
                            return v
                        elseif mName:find("ItemLibrary") and (v.ViewModels or rawget(v, "ViewModels")) then
                            return v
                        elseif mName:find("ClientViewModel") and (v.new or rawget(v, "new")) and (v.GetWrap or rawget(v, "GetWrap")) then
                            return v
                        elseif mName:find("ReplicatedClass") and type(v.ToEnum) == "function" then
                            return v
                        end
                    elseif type(v) == "function" and getupvalues then
                        local ups = getupvalues(v)
                        for _, upv in pairs(ups) do
                            if type(upv) == "table" then
                                if mName:find("CosmeticLibrary") and upv.Cosmetics and upv.Equip then return upv end
                                if mName:find("ItemLibrary") and upv.ViewModels then return upv end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function ResolveModules()
    if Resolved or Resolving then return Resolved end
    Resolving = true
    local ok = pcall(function()
        CosmeticLibrary = robust_require(ReplicatedStorage:WaitForChild("Modules", 20):WaitForChild("CosmeticLibrary", 20))
        ItemLibrary = robust_require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 20))
        ReplicatedClass = robust_require(ReplicatedStorage.Modules:WaitForChild("ReplicatedClass", 20))
        local Modules = player.PlayerScripts:WaitForChild("Modules", 15)
        ClientViewModel = robust_require(Modules:WaitForChild("ClientReplicatedClasses", 15):WaitForChild("ClientFighter", 15):WaitForChild("ClientItem", 15):WaitForChild("ClientViewModel", 15))
    end)
    Resolving = false
    Resolved = true
    print("[SkinChanger] resolve pcall=" .. tostring(ok)
        .. " CosmeticLibrary=" .. tostring(CosmeticLibrary ~= nil)
        .. " ItemLibrary=" .. tostring(ItemLibrary ~= nil)
        .. " ReplicatedClass=" .. tostring(ReplicatedClass ~= nil)
        .. " ClientViewModel=" .. tostring(ClientViewModel ~= nil))
    return Resolved
end

local function getCosmeticData(name, cType)
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = table.clone(base)
    data.Name = name
    data.Type = cType
    if name == "AKEY-47" then
        data.IsMythical = true
        data.BundlePath = "Bundles"
    elseif name:find("Gingerbread") then
        data.BundlePath = "Festive Skin Case"
    elseif name == "Evil Trident" or name == "Devil's Trident" then
        data.DisplayName = "Evil Trident"
    end
    return data
end

-- ═══════════════════════════════════════════════
-- HOOKS (installed once, no-op while disabled)
-- ═══════════════════════════════════════════════
local oldGetWrap, oldNew
local Installed = false

local function Install()
    if Installed then return true end
    if not ResolveModules() then return false end

    if ClientViewModel and not oldGetWrap and type(ClientViewModel.GetWrap) == "function" then
        oldGetWrap = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            if not Toggles.SkinChanger then return oldGetWrap(self) end
            local ok, result = pcall(function()
                local weaponName = self.ClientItem and self.ClientItem.Name
                if weaponName and _G.EquippedData[weaponName] then
                    local wrapName = _G.EquippedData[weaponName].Wrap
                    if wrapName and wrapName ~= "None" then
                        return getCosmeticData(wrapName, "Wrap")
                    end
                end
            end)
            if ok and result then return result end
            return oldGetWrap(self)
        end
    end

    if ClientViewModel and not oldNew and type(ClientViewModel.new) == "function" then
        oldNew = ClientViewModel.new
        ClientViewModel.new = function(replicatedData, clientItem)
            pcall(function()
                if not Toggles.SkinChanger then return end
                if not clientItem then return end
                local weaponName = clientItem.Name
                if not weaponName then return end
                local info = _G.EquippedData[weaponName]
                if not info then return end
                local cf = rawget(clientItem, "ClientFighter")
                    or (pcall(function() return clientItem.ClientFighter end) and clientItem.ClientFighter)
                if not cf or cf.Player ~= player then return end
                local selectedSkin = info.Skin
                if not selectedSkin or selectedSkin == "Default" then return end
                local cosData = getCosmeticData(selectedSkin, "Skin")
                if not cosData then return end
                local dataKey = ReplicatedClass:ToEnum("Data")
                local skinKey = ReplicatedClass:ToEnum("Skin")
                local nameKey = ReplicatedClass:ToEnum("Name")
                replicatedData[dataKey] = replicatedData[dataKey] or {}
                replicatedData[dataKey][skinKey] = cosData
                replicatedData[dataKey][nameKey] = selectedSkin
            end)
            local vm = oldNew(replicatedData, clientItem)
            task.delay(0.1, function()
                pcall(function()
                    if vm and vm._UpdateWrap then vm:_UpdateWrap() end
                end)
            end)
            return vm
        end
    end

    Installed = true
    print("[SkinChanger] hooks installed: GetWrap=" .. tostring(oldGetWrap ~= nil) .. " .new=" .. tostring(oldNew ~= nil))
    return true
end

-- ═══════════════════════════════════════════════
-- ENABLE / RETRY
-- ═══════════════════════════════════════════════
local function TryEnable()
    local ok = ResolveModules()
    if not ok then
        print("[SkinChanger] module resolution failed, will retry while enabled")
        return
    end
    Install()
end

local PrevEnabled = nil
local RetryCount = 0
table.insert(Connections, RunService.Heartbeat:Connect(function()
    local enabled = Toggles.SkinChanger
    if enabled ~= PrevEnabled then
        PrevEnabled = enabled
        RetryCount = 0
        if enabled then
            task.spawn(TryEnable)
        end
    end
    if enabled then
        RetryCount = RetryCount + 1
        if not Installed and RetryCount % 120 == 0 then
            task.spawn(TryEnable)
        end
    end
end))

local function SetSelection(weapon, skin, wrap)
    weapon = weapon or Options.SkinWeapon or "Assault Rifle"
    skin = skin or "Default"
    wrap = wrap or "None"
    if SkinLists[weapon] then
        _G.EquippedData[weapon] = {Skin = skin, Wrap = wrap}
    end
    if Toggles.SkinChanger and CosmeticLibrary and skin ~= "Default" then
        pcall(function()
            CosmeticLibrary.Equip(weapon, "Skin", skin)
        end)
    end
end

local function GetEquipped(weapon)
    return _G.EquippedData[weapon] or {Skin = "Default", Wrap = "None"}
end

local function ClearAll()
    for weapon in pairs(SkinLists) do
        _G.EquippedData[weapon] = {Skin = "Default", Wrap = "None"}
    end
end

local function GetAssignments()
    local lines = {}
    for _, weapon in ipairs(Weapons) do
        local info = _G.EquippedData[weapon] or {Skin = "Default", Wrap = "None"}
        if info.Skin ~= "Default" or (info.Wrap and info.Wrap ~= "None") then
            lines[#lines + 1] = weapon .. ": " .. info.Skin .. (info.Wrap and info.Wrap ~= "None" and (" [" .. info.Wrap .. "]") or "")
        end
    end
    return lines
end

local module = {}
module.Weapons = Weapons
module.Wraps = WrapList
module.GetSkins = GetSkins
module.SetSelection = SetSelection
module.GetEquipped = GetEquipped
module.ClearAll = ClearAll
module.GetAssignments = GetAssignments
module.Unload = function()
    Toggles.SkinChanger = false
    if oldGetWrap and ClientViewModel then
        pcall(function()
            ClientViewModel.GetWrap = oldGetWrap
        end)
    end
    if oldNew and ClientViewModel then
        pcall(function()
            ClientViewModel.new = oldNew
        end)
    end
end

return module
