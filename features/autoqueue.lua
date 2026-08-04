local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toggles = getgenv().Toggles
local Options = getgenv().Options

local Connections = getgenv().Connections or {}
getgenv().Connections = Connections

local Cooldown = 2.5
local LastAttempt = 0

local function GetRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local matchmaking = remotes:FindFirstChild("Matchmaking")
    if not matchmaking then return nil end
    return matchmaking:FindFirstChild("JoinQueue")
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    pcall(function()
        if not Toggles.AutoQueue then
            LastAttempt = 0
            return
        end

        local now = os.clock()
        if now - LastAttempt < Cooldown then return end
        LastAttempt = now

        local remote = GetRemote()
        if not remote then return end

        local qtype = Options.QueueType or "5v5"
        pcall(function()
            remote:InvokeServer(qtype)
        end)
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
    end
}
