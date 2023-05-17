--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
---@class CMemory
TTTBots.Components.Memory = {}
TTTBots = TTTBots or {}

TTTBots.Sound = {
    DetectionRanges = {
        Gun = 1000,
        Footstep = 250,
        Death = 1000,
        Melee = 500,
        C4 = 500,
    },
    TraitMults = {
        cautious = 1.3,
        sniper = 0.7,
        doesntcare = 0.2,
        bodyguard = 1.2,
        lovescrowds = 0.7,
        teamplayer = 0.9,
        loner = 1.1,

        veryobservant = 2.0,
        observant = 1.5,
        oblivious = 0.8,
        veryoblivious = 0.4,

        deaf = 0.0,
        lowvolume = 0.5,
        highvolume = 1.5,
    },
}

local lib = TTTBots.Lib
---@class CMemory
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
}

FORGET.GetRememberTime = function(ply)
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

local function shouldUseRadar()
    local rand = math.random(1, 100)
    local cv = GetConVar("ttt_bot_radar_chance"):GetInt()

    if rand <= cv then
        return true
    end
    return false
end

function Memory:ResetMemory()
    self.playerKnownPositions = {}   -- List of where this bot last saw each player and how long ago
    self.PlayerLifeStates = {}       -- List of what this bot understands each bot's current life state to be
    self.UseRadar = shouldUseRadar() -- Whether or not this bot should use radar
end

function Memory:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.memory = self

    self:ResetMemory()

    self.bot = bot
    self.tick = 0
end

--- Simulates radar scanning the position of ply
function Memory:UpdateRadar(ply)
    if self.UseRadar and self.tick % 300 ~= 69 then return end -- Nice
    if not TTTBots.Lib.IsEvil(self.bot) then return end
    if not TTTBots.Lib.IsPlayerAlive(ply) then return end

    local pos = ply:GetPos()
    self:UpdateKnownPositionFor(ply, pos)
end

function Memory:HandleUnseenPlayer(ply)
    -- Update radar if applicable
    self:UpdateRadar(ply)

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
---@return Vector|nil Pos, boolean CanSee
function Memory:GetCurrentPosOf(ply)
    local canSee = lib.CanSee(self.bot, ply)
    if canSee then
        return ply:GetPos()
    end
    return self:GetKnownPositionFor(ply), canSee
end

--- Update the known position in our database for the given player to their current position, or pos if provided.
---@param ply Player The player object of the target
---@param pos Vector|nil If nil then ply:GetPos() will be used, else this will be used.
---@return table knownPos The updated known position entry for this player
function Memory:UpdateKnownPositionFor(ply, pos)
    -- Get the current time
    local ct = CurTime()

    -- Create the knownPos entry
    local knownPos = {
        ply = ply,                                    -- The player object
        nick = ply:Nick(),                            -- The player's nickname
        pos = pos or ply:GetPos(),                    -- The position of the player
        inferred = (pos and true) or false,           -- Whether or not this position is inferred (and probably not accurate)
        time = ct,                                    -- The time this position was last updated
        forgetTime = FORGET.GetRememberTime(self.bot) -- How many seconds to remember this position for
    }

    -- Function to get how long ago this position was last updated
    function knownPos.timeSince()
        return CurTime() - knownPos.time
    end

    -- Function to check whether or not we should forget this position
    function knownPos.shouldForget()
        -- Calculate the elapsed time since the last update
        local ts = CurTime() - knownPos.time

        -- Get the corresponding known position of the player
        local pKP = self.playerKnownPositions[ply:Nick()]

        -- Return whether the elapsed time is greater than the forget time
        return ts > pKP.forgetTime
    end

    -- Update the known position for this player
    self.playerKnownPositions[ply:Nick()] = knownPos

    return knownPos
end

--- Updates the positions of every player in the game.
--- Handles forgetting players that we can no longer see according to memory rules.
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
        self:UpdateKnownPositionFor(ply)
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

function Memory:SawPlayerRecently(ply)
    local pnp = self.playerKnownPositions[ply:Nick()]
    if not pnp then return false end
    return pnp.timeSince() < 5
end

function Memory:GetRecentlySeenPlayers(withinSecs)
    local withinSecs = withinSecs or 5
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if self:SawPlayerRecently(ply) then
            table.insert(players, ply)
        end
    end
    return players
end

--- Gets a list of positions of players that we have seen recently.
---@return table<Vector> positions ["playername"]=Vector
function Memory:GetKnownPlayersPos()
    local positions = {}
    for i, ply in pairs(player.GetAll()) do
        local pnp = self.playerKnownPositions[ply:Nick()]
        if not pnp then continue end
        positions[ply:Nick()] = pnp.pos
    end
    return positions
end

--- Gets a list of every player we think is alive.
---@return table<Player> players
function Memory:GetKnownAlivePlayers()
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if self:GetPlayerLifeState(ply) == ALIVE then
            table.insert(players, ply)
        end
    end
    return players
end

--- Gets actually alive players irrespective of what we think.
---@return table<Player> players
function Memory:GetActualAlivePlayers()
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if lib.IsPlayerAlive(ply) then
            table.insert(players, ply)
        end
    end
    return players
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
    local sn = data.SoundName
    -- print(data.SoundName, data.Volume)
    -- TTTBots.DebugServer.DrawCross(data.Pos, 5, Color(0, 0, 0), 1)
    local f = string.find

    local isC4 = f(sn, "c4")
    local isGun = f(sn, "weapons")
    local isFootstep = f(sn, "footstep")
    local isMelee = f(sn, "swing")
    local isDead = f(sn, "pain")

    if isC4 then
        print("Beep")
        return
    end
    if isGun then
        print("Gun")
        return
    end
    if isFootstep then
        print("Footstep")
        return
    end
    if isMelee then
        print("Melee")
        return
    end
    if isDead then
        print("Dead")
        return
    end

    print("Unknown sound: " .. sn)
end)
