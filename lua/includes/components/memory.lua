--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
---@class CMemory
TTTBots.Components.Memory = {}
TTTBots = TTTBots or {}

TTTBots.Sound = {
    DetectionInfo = {
        Gunshot = {
            Distance = 1250,
            Keywords = { "gun", "shoot", "shot", "bang", "pew",
                "fiveseven", "mac10", "deagle", "shotgun", "rifle", "pistol", "xm1014", "m249", "scout", "m4a1",
                "glock"
            }
        },
        Footstep = {
            Distance = 350,
            Keywords = { "footstep", "glass_sheet_step" }
        },
        Melee = {
            Distance = 600,
            Keywords = { "swing", "hit", "punch", "slash", "stab" }
        },
        Death = {
            Distance = 1250,
            Keywords = { "pain", "death", "die", "dead", "ouch", "male01" }
        },
        C4Beep = {
            Distance = 600,
            Keywords = { "beep" }
        },
        Explosion = {
            Distance = 1500,
            Keywords = { "ball_zap", "explode" }
        }
    },
}

local lib = TTTBots.Lib
---@class CMemory
local Memory = TTTBots.Components.Memory
local DEAD = "DEAD"
local ALIVE = "ALIVE"
local FORGET = {
    Base = 30,
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
    bot.components = bot.components or {}
    bot.components.memory = self

    self:ResetMemory()

    self.bot = bot
    self.tick = 0
    ---@type table<table>
    self.recentSounds = {}
    self.forgetTime = FORGET.GetRememberTime(self.bot)
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

--- Parse through our recent sound memory for any sounds tied to ply's entity. Returns the position vector, else nil.
---@param ply Player
---@return Vector|nil
function Memory:GetSuspectedPositionFor(ply)
    ---@type table<table>
    local recentSounds = self:GetRecentSoundsFromPly(ply)
    if #recentSounds == 0 then return end
    -- sort by time field
    table.sort(recentSounds, function(a, b) return a.time > b.time end)
    -- return the most recent sound
    return recentSounds[1].pos
end

--- Get the last known position of the given player, if we have any. This differs from GetKnownPositionFor
--- in that it will either return ply:GetPos() if lib.CanSee(self.bot, ply), or the last known position.
---@param ply any
---@return Vector|nil Pos, boolean CanSee
function Memory:GetCurrentPosOf(ply)
    local canSee = lib.CanSee(self.bot, ply)
    if canSee then
        self:UpdateKnownPositionFor(ply, ply:GetPos())
        return ply:GetPos(), canSee
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
        return (ts > pKP.forgetTime) or self.bot:VisibleVec(pKP.pos)
    end

    -- Update the known position for this player
    self.playerKnownPositions[ply:Nick()] = knownPos

    return knownPos
end

--- Updates the positions of every player in the game.
--- Handles forgetting players that we can no longer see according to memory rules.
function Memory:UpdateKnownPositions()
    local AlivePlayers = lib.GetAlivePlayers()
    local RoundActive = TTTBots.Match.RoundActive
    if not RoundActive then
        self.playerKnownPositions = {}
        return false
    end

    for i, ply in pairs(AlivePlayers) do
        if ply == self.bot then continue end
        if not lib.CanSee(self.bot, ply) then
            self:HandleUnseenPlayer(ply)
            continue
        end
        self:UpdateKnownPositionFor(ply)
    end
end

-- Setup the player states at the start of the round.
-- Automatically bounces attempt if round is not active
function Memory:SetupPlayerLifeStates()
    local ConfirmedDead = TTTBots.Match.ConfirmedDead
    local PlayersInRound = TTTBots.Match.PlayersInRound
    local RoundActive = TTTBots.Match.RoundActive
    if not RoundActive then return false end

    for i, ply in pairs(PlayersInRound) do
        self:SetPlayerLifeState(ply, ConfirmedDead[ply] and DEAD or ALIVE)
    end
end

function Memory:GetPlayerLifeState(ply)
    return self.PlayerLifeStates[ply:Nick()]
end

function Memory:SetPlayerLifeState(ply, state)
    if not ply or not IsValid(ply) then return end
    local nick = (type(ply) == "string" and ply) or ply:Nick()
    self.PlayerLifeStates[nick] = state
end

function Memory:UpdatePlayerLifeStates()
    local CurrentlyAlive = lib.GetAlivePlayers()
    local ConfirmedDead = TTTBots.Match.ConfirmedDead
    local RoundActive = TTTBots.Match.RoundActive
    local IsEvil = lib.IsEvil
    local bot = self.bot

    if not RoundActive then
        self.PlayerLifeStates = {}
        self:SetupPlayerLifeStates()
    end

    for plyname, value in pairs(ConfirmedDead) do
        self:SetPlayerLifeState(plyname, DEAD)
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
---@return table<Vector> positions [Player]=Vector
function Memory:GetKnownPlayersPos()
    local positions = {}
    for i, ply in pairs(player.GetAll()) do
        local pnp = self.playerKnownPositions[ply:Nick()]
        if not pnp then continue end
        positions[ply] = pnp.pos
    end
    return positions
end

--- Basically same as GetKnownPlayersPos, but filters for 'not lib.IsEvil(player)'
function Memory:GetKnownInnocentsPos()
    local positions = {}
    for i, ply in pairs(player.GetAll()) do
        if lib.IsEvil(ply) then continue end
        local pnp = self.playerKnownPositions[ply:Nick()]
        if not pnp then continue end
        positions[ply] = pnp.pos
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
    local RUNRATE = 3
    if not (self.tick % RUNRATE == 0) then return end

    self:UpdateKnownPositions()
    self:UpdatePlayerLifeStates()
end

--- Returns (and sets, if applicable) the hearing multiplier for this bot.
function Memory:GetHearingMultiplier()
    if self.HearingMultiplier then return self.HearingMultiplier end
    local bot = self.bot
    local mult = bot:GetTraitMult("hearing")

    self.HearingMultiplier = mult
    return mult
end

--- Returns a table of the recent sounds emitted by a player or an entity owned by a player.
---@param ply Player The player to get the recent sounds of.
---@return table<table> sounds
function Memory:GetRecentSoundsFromPly(ply)
    local sounds = {}
    for i, sound in pairs(self.recentSounds) do
        if sound.ply == ply then
            table.insert(sounds, sound)
        end
    end
    return sounds
end

function Memory:GetHeardC4Sounds()
    local sounds = {}
    for i, sound in pairs(self.recentSounds) do
        if sound.sound == "C4Beep" then
            table.insert(sounds, sound)
        end
    end
    return sounds
end

--- Handles incoming sounds.
--- Determines if the bot can hear the noise, then adds it to the components sound memory.
---@param info SoundInfo My custom sound info table.
---@param soundData table The original GLua sound table.
---@return boolean IsUseful Whether or not the sound was useful, basically false if did not hear.
function Memory:HandleSound(info, soundData)
    local bot = self.bot
    local soundpos = info.Pos
    local stdrange = info.Distance
    local botHearingMult = self:GetHearingMultiplier()

    local distTo = bot:GetPos():Distance(soundpos)
    local canHear = distTo <= stdrange * botHearingMult

    if not canHear then
        return false
    end

    local tbl = {
        time = CurTime(),
        sound = info.SoundName,
        pos = soundpos,
        info = info,
        ent = info.EntInfo.Entity or info.EntInfo.Owner,
        sourceIsPly = info.EntInfo.EntityIsPlayer or info.EntInfo.OwnerIsPlayer,
        ply = (info.EntInfo.EntityIsPlayer and info.EntInfo.Entity) or
            (info.EntInfo.OwnerIsPlayer and info.EntInfo.Owner),
        soundData = soundData,
        dist = distTo,
    }
    if tbl.ply == bot then return false end
    -- if tbl.dist > 600 and not bot:VisibleVec(tbl.pos) then
    --     tbl.ply = nil -- scrub the player if they are too far away and not visible for balancing reasons
    -- end
    table.insert(self.recentSounds, tbl)

    local pressureHash = {
        ["Gunshot"] = "HearGunshot",
        ["Death"] = "HearDeath",
        ["Explosion"] = "HearExplosion",
    }
    local hashedName = pressureHash[info.SoundName]
    if hashedName then
        local personality = lib.GetComp(bot, "personality")
        if personality then
            personality:OnPressureEvent(hashedName, tbl)
        end
    end

    return true
end

--- Automatically culls old sounds from self.recentSounds
function Memory:CullSoundMemory()
    local recentSounds = self.recentSounds
    if not recentSounds then return end
    local curTime = CurTime()
    for i, sound in pairs(recentSounds) do
        local timeSince = curTime - sound.time
        if timeSince > 5 then
            table.remove(recentSounds, i)
        elseif timeSince > 0.5 and lib.CanSeeArc(self.bot, sound.pos, 75) then
            table.remove(recentSounds, i) -- we don't need to remember sounds that we can see the source of
        end
    end
end

--[[
    time
    sound -- soundname, e.g. "Gunshot"
    pos -- vec3
    info -- soundinfo
    ent -- ent|nil
    sourceIsPly -- bool
    ply -- player|nil
    soundData -- glua sound table
    dist -- number
]]
---@return table<table> recentSounds
function Memory:GetRecentSounds()
    return self.recentSounds
end

timer.Create("TTTBots_CullSoundMemory", 1, 0, function()
    for i, v in pairs(TTTBots.Bots) do
        if not (v and v.components and v.components.memory) then continue end
        v.components.memory:CullSoundMemory()
    end
end)

--- Executes :HandleSound for every living bot in the game.
---@param info SoundInfo
---@param soundData table
function Memory.HandleSoundForAllBots(info, soundData)
    for i, v in pairs(TTTBots.Bots) do
        if not lib.IsPlayerAlive(v) then continue end
        if not (v and v.components and v.components.memory) then continue end
        local mem = v.components.memory

        -- local hasAgent = info.EntInfo.Entity or info.EntInfo.Owner
        -- if not hasAgent then continue end

        mem:HandleSound(info, soundData)
    end
end

---@class SoundInfo My custom sound info table.
---@field SoundName string The category of the sound.
---@field FoundKeyword string The keyword that was found in the sound name.
---@field Distance number The standard detection distance for this sound.
---@field Pos Vector|nil The position of the sound, if any.
---@field EntInfo SoundEntInfo The entity info table of the sound, if any.
---@class SoundEntInfo Sound entity info table inside of the SoundInfo table.
---@field Entity Entity|nil The entity that made the sound, if any.
---@field EntityIsPlayer boolean|nil Whether or not the entity is a player.
---@field OwnerIsPlayer boolean|nil Whether or not the owner of the entity is a player.
---@field Class string|nil The class of the entity.
---@field Name string|nil The name of the entity.
---@field Nick string|nil The nick of the entity, if it is a player.
---@field Owner Entity|nil The owner of the entity, if any.

-- GM:EntityEmitSound(table data)
hook.Add("EntityEmitSound", "TTTBots.EntityEmitSound", function(data)
    -- TTTBots.DebugServer.DrawCross(data.Pos, 5, Color(0, 0, 0), 1)
    local sn = data.SoundName
    local f = string.find

    for k, v in pairs(TTTBots.Sound.DetectionInfo) do
        local keywords = v.Keywords
        for i, keyword in pairs(keywords) do
            if f(sn, keyword) then
                -- print(string.format("%s: Found keyword %s in sound %s", k, keyword, sn))
                Memory.HandleSoundForAllBots(
                    {
                        SoundName = k,
                        FoundKeyword = keyword,
                        Distance = v.Distance,
                        Pos = data.Pos or (data.Entity and data.Entity:GetPos()),
                        EntInfo = {
                            Entity = data.Entity,
                            EntityIsPlayer = data.Entity and data.Entity:IsPlayer(),
                            OwnerIsPlayer = data.Entity and data.Entity:GetOwner() and data.Entity:GetOwner():IsPlayer(),
                            Class = data.Entity and data.Entity:GetClass(),
                            Name = data.Entity and data.Entity:GetName(),
                            Nick = data.Entity and data.Entity:IsPlayer() and data.Entity:Nick(),
                            Owner = data.Entity and data.Entity:GetOwner(),
                        }
                    },
                    data
                )
                return
            end
        end
    end

    -- print("Unknown sound: " .. sn)
end)
