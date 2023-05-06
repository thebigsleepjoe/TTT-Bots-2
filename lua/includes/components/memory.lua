--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
TTTBots.Components.Memory = TTTBots.Memory or {}
TTTBots = TTTBots or {}

local lib = TTTBots.Lib
local Memory = TTTBots.Components.Memory
local DEAD = "DEAD"
local ALIVE = "ALIVE"
local FORGET = {
    Base = 20,
    Variance = 5,
    Traits = {
        -- Personality traits that multiply Base
        cautious = 1.1,
        sniper = 1.2,
        camper = 1.3,
        aggressive = 0.9,
        doesntcare = 0.5,
        bodyguard = 1.1,
        lovescrowds = 0.8,
        teamplayer = 0.9,
        loner = 1.1,
        -- The big traits:
        veryobservant = 2.0,
        observant = 1.5,
        oblivious = 0.8,
        veryoblivious = 0.4,
    },
    GetRememberTime = function(ply)
        local traits = ply.components.personality.traits
        local base = FORGET.Base
        local variance = FORGET.Variance
        local multiplier = 1
        for i, trait in pairs(traits) do
            if FORGET.Traits[trait] then
                multiplier = multiplier * FORGET.Traits[trait]
            end
        end
        return base * multiplier + math.random(-variance, variance)
    end
}


function Memory:New(bot)
    local newMemory = {}
    setmetatable(newMemory, {
        __index = function(t, k) return Memory[k] end,
    })
    newMemory:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Memory for bot " .. bot:Nick())
    end

    return newMemory
end

function Memory:ResetMemory()
    self.playerKnownPositions = {} -- List of where this bot last saw each player and how long ago
    self.PlayerLifeStates = {}     -- List of what this bot understands each bot's current life state to be
end

function Memory:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.memory = self

    self:ResetMemory()

    self.bot = bot
    self.tick = 0
end

function Memory:HandleUnseenPlayer(ply)
    -- Check if we have any memory of this player, if we shouldForget() then delete it
    local pnp = self.playerKnownPositions[ply:Nick()]
    if not pnp then return end
    if pnp.shouldForget() then
        self.playerKnownPositions[ply:Nick()] = nil
    end
end

--- Get the last known position of the given player, if we have any.
---@param ply Player
---@return Vector|nil
function Memory:GetKnownPositionFor(ply)
    local pnp = self.playerKnownPositions[ply:Nick()]
    if not pnp then return nil end
    return pnp.pos
end

--- Get the last known position of the given player, if we have any. This differs from GetKnownPositionFor
--- in that it will either return ply:GetPos() if lib.CanSee(self.bot, ply), or the last known position.
---@param ply any
function Memory:GetCurrentPosOf(ply)
    if lib.CanSee(self.bot, ply) then
        return ply:GetPos()
    end
    return self:GetKnownPositionFor(ply)
end

function Memory:UpdateKnownPositions()
    local AlivePlayers = lib.GetAlivePlayers()
    local RoundActive = TTTBots.RoundActive
    if not RoundActive then
        self.playerKnownPositions = {}
        return false
    end

    for i, ply in pairs(AlivePlayers) do
        if ply == self.bot then continue end
        if not self.bot:Visible(ply) then
            self:HandleUnseenPlayer(ply)
            continue
        end
        local ct = CurTime()
        self.playerKnownPositions[ply:Nick()] = {
            pos = ply:GetPos(),
            time = ct,
            timeSince = function()
                return CurTime() - ct
            end,
            forgetTime = FORGET.GetRememberTime(ply), -- how many seconds to remember this position for, need to factor CurTime() into this to be useful
            shouldForget = function()
                local ts = CurTime() - ct
                local pKP = self.playerKnownPositions[ply:Nick()]
                return ts > pKP.forgetTime
            end
        }
    end
end

-- Setup the player states at the start of the round.
-- Automatically bounces attempt if round is not active
function Memory:SetupPlayerLifeStates()
    local ConfirmedDead = TTTBots.ConfirmedDead
    local PlayersInRound = TTTBots.PlayersInRound
    local RoundActive = TTTBots.RoundActive
    if not RoundActive then return false end

    for i, ply in pairs(PlayersInRound) do
        self:SetPlayerLifeState(ply, ConfirmedDead[ply] and DEAD or ALIVE)
    end
end

function Memory:GetPlayerLifeState(ply)
    return self.PlayerLifeStates[ply:Nick()]
end

function Memory:SetPlayerLifeState(ply, state)
    self.PlayerLifeStates[ply:Nick()] = state
end

function Memory:UpdatePlayerLifeStates()
    local CurrentlyAlive = lib.GetAlivePlayers()
    local ConfirmedDead = TTTBots.ConfirmedDead
    local RoundActive = TTTBots.RoundActive
    local IsEvil = lib.IsEvil
    local bot = self.bot

    if not RoundActive then
        self.PlayerLifeStates = {}
        self:SetupPlayerLifeStates()
    end

    for i, ply in pairs(ConfirmedDead) do
        self:SetPlayerLifeState(ply, DEAD)
    end

    -- Traitor handling
    if IsEvil(bot) then
        -- Traitors know who is dead and who is alive, so first set everyone to dead.
        for i, ply in pairs(player.GetAll()) do
            if ply == bot then continue end
            self:SetPlayerLifeState(ply, DEAD)
        end

        -- Then set everyone that is alive to alive.
        for i, ply in pairs(CurrentlyAlive) do
            if ply == bot then continue end
            self:SetPlayerLifeState(ply, ALIVE)
        end
    end
end

function Memory:Think()
    self.tick = self.tick + 1
    local RUNRATE = 5
    if not (self.tick % RUNRATE == 0) then return end

    self:UpdateKnownPositions()
    self:UpdatePlayerLifeStates()
end

--- Hooks

-- GM:EntityEmitSound(table data)
hook.Add("EntityEmitSound", "TTTBots.EntityEmitSound", function(data)
    -- PrintTable(data)
end)
