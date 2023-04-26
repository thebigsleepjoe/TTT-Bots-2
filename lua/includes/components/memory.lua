--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
TTTBots = TTTBots or {}
TTTBots.Components.BotMemory = TTTBots.BotMemory or {}

local lib = TTTBots.Lib
local BotMemory = TTTBots.Components.BotMemory


function BotMemory:New(bot)
    local newMemory = {}
    setmetatable(newMemory, {
        __index = function(t, k) return BotMemory[k] end,
    })
    newMemory:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Memory for bot " .. bot:Nick())
    end

    return newMemory
end

function BotMemory:ResetMemory()
    self.playerPositions = {} -- List of where this bot last saw each player and how long ago
    self.playerStates = {}    -- List of what this bot understands each bot's current life state to be
end

function BotMemory:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.memory = self

    self:ResetMemory()

    self.bot = bot
    self.tick = 0
end

function BotMemory:UpdatePositions()
    local PlayersInRound = TTTBots.PlayersInRound
    local RoundActive = TTTBots.RoundActive
    if not RoundActive then
        self.playerPositions = {}
        return false
    end

    for i, ply in pairs(PlayersInRound) do
        -- TODO: vision check here
        local ct = CurTime()
        self.playerPositions[ply:Nick()] = {
            pos = ply:GetPos(),
            time = ct,
            timeSince = function()
                return CurTime() - ct
            end
        }
    end
end

-- Setup the player states at the start of the round.
-- Automatically bounces attempt if round is not active
function BotMemory:SetupStates()
    local ConfirmedDead = TTTBots.ConfirmedDead
    local PlayersInRound = TTTBots.PlayersInRound
    local RoundActive = TTTBots.RoundActive
    if not RoundActive then return false end

    for i, ply in pairs(PlayersInRound) do
        self.playerStates[ply:Nick()] = ConfirmedDead[ply] and "dead" or "alive"
    end
end

function BotMemory:UpdateStates()
    local CurrentlyAlive = lib.GetAlivePlayers()
    local ConfirmedDead = TTTBots.ConfirmedDead
    local RoundActive = TTTBots.RoundActive
    if not RoundActive then
        self.playerStates = {}
        self:SetupStates()
    end
end

function BotMemory:Think()
    self.tick = self.tick + 1
    local RUNRATE = 5
    if not (self.tick % RUNRATE == 0) then return end

    self:UpdatePositions()
    self:UpdateStates()
end
