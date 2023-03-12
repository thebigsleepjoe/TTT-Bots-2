TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.FakePing = TTTBots.Components.FakePing or {}

local lib = TTTBots.Lib
local FakePing = TTTBots.Components.FakePing
local playerMeta = getmetatable("Player")

function FakePing:New(bot)
    local newFakePing = {}
    setmetatable(newFakePing, {
        __index = function(t, k) return FakePing[k] end,
    })
    newFakePing:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized FakePing for bot " .. bot:Nick())
    end

    return newFakePing
end

function FakePing:Initialize(bot)
    print("Initializing")
    bot.components = bot.components or {}
    bot.components.fakeping = self

    self.componentID = string.format("fakeping (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                       -- Tick counter
    self.bot = bot
    self.ping = 0
    self.disabled = false
end

local oldPing = playerMeta.Ping
function playerMeta:Ping()
    print("Ping")
    if self:IsBot() then
        local fakePing = self.components.fakeping
        if fakePing then
            return fakePing:GetPing()
        end

        return self:GetPing()
    else
        return oldPing(self)
    end
end

function FakePing:GetPing()
    print("Getting fake ping")
    return self.ping
end

function FakePing:Think()
    if self.disabled then return end

    self.tick = self.tick + 1
    if self.tick % 3 == 0 then -- A tick is 0.1 seconds and the scoreboard updates every 0.3 seconds.
        self:UpdatePing()
    end
end

function FakePing:GetAvgHumanPing()
    local total = 0
    local count = 0

    for _, ply in pairs(player.GetAll()) do
        if ply:IsBot() then continue end

        total = total + ply:Ping()
        count = count + 1
    end

    if count == 0 then return 0 end
    return total / count
end

function FakePing:UpdatePing()
    local avgPing = self:GetAvgHumanPing()
    if avgPing then
        self.ping = math.random(avgPing - 20, avgPing + 20)
    end
end
