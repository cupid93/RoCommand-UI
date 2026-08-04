local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toggles = getgenv().Toggles
local Options = getgenv().Options

local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local waitf = task and task.wait or wait
local spawnf = task and task.spawn or spawn

-- // USER: set the Vote remote path below (folders from ReplicatedStorage)
local VoteRemotePath = {"Remotes", "Matchmaking", "Vote"}
local PickWeaponsPath = {"Remotes", "Replication", "Fighter", "PickWeapons"}

local function FindRemote(path)
    local obj = ReplicatedStorage
    for _, part in ipairs(path) do
        obj = obj:FindFirstChild(part)
        if not obj then return nil end
    end
    return obj
end

local function FirePickWeapons()
    if not Toggles.AutoEquip then return end

    local remote = FindRemote(PickWeaponsPath)
    if not remote then return end

    local order = {"EquipPrimary", "EquipSecondary", "EquipMelee", "EquipMisc"}
    local weapons = {}
    for _, key in ipairs(order) do
        local weapon = Options[key]
        if weapon and weapon ~= "None" then
            table.insert(weapons, weapon)
        end
    end
    if #weapons == 0 then return end

    pcall(function()
        remote:FireServer(weapons)
    end)
end

local VoteRemote = FindRemote(VoteRemotePath)
if VoteRemote then
    table.insert(Connections, VoteRemote.OnClientEvent:Connect(function()
        if Toggles.AutoEquip then
            spawnf(function()
                waitf(0.5)
                FirePickWeapons()
            end)
        end
    end))
end

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
    end
}
