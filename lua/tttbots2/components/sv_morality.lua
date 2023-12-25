--[[
    This component defines the morality of the agent. It is primarily responsible for determining who to shoot.
    It also tells traitors who to kill.
]]
---@class CMorality : CBase
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality : CBase
local BotMorality = TTTBots.Components.Morality

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    -- Killing another player
    Kill = 9,          -- This player killed someone in front of us
    KillTrusted = 10,  -- This player killed a Trusted in front of us
    KillTraitor = -10, -- This player killed a traitor in front of us

    -- Hurt a player
    Hurt = 4,          -- This player hurt someone in front of us
    HurtMe = 10,       -- This player hurt us
    HurtTrusted = 10,  -- This player hurt a Trusted in front of us
    HurtByTrusted = 4, -- This player was hurt by a Trusted
    HurtByEvil = -2,   -- This player was hurt by a traitor

    -- KOS-related events
    KOSByTrusted = 10, -- KOS called on this player by trusted innocent
    KOSByTraitor = -5, -- KOS called on this player by known traitor
    KOSByOther = 5,    -- KOS called on this player
    AffirmingKOS = -3, -- KOS called on a player we think is a traitor (rare, but possible)

    -- Role-specific weapons
    TraitorWeapon = 10, -- This player has a traitor weapon

    -- Corpse-related events
    NearUnidentified = 2,    -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -3,  -- This player has identified a traitor's corpse
    IdentifiedInnocent = -2, -- This player has identified an innocent's corpse
    IdentifiedTrusted = -2,  -- This player has identified a Trusted's corpse

    -- Interacting with C4
    DefuseC4 = -7, -- This player is defusing C4
    PlantC4 = 10,  -- This player is throwing down C4

    -- Following a player
    FollowingMe = 3, -- This player has been following me for more than 10 seconds

    -- Shooting at a player
    ShotAtMe = 7,      -- This player has been shooting at me
    ShotAt = 5,        -- This player has been shooting at someone
    ShotAtTrusted = 6, -- This player has been shooting at a Trusted

    -- Throwing a grenade
    ThrowDiscombob = 2, -- This player has thrown a discombobulator
    ThrowIncin = 8,     -- This player has thrown an incendiary grenade
    ThrowSmoke = 3,     -- This player has thrown a smoke grenade
}

BotMorality.SuspicionDescriptions = {
    ["10"] = "Definitely evil",
    ["9"] = "Almost certainly evil",
    ["8"] = "Highly likely evil", -- Declare them as evil
    ["7"] = "Very suspicious, likely evil",
    ["6"] = "Very suspicious",
    ["5"] = "Quite suspicious",
    ["4"] = "Suspicious", -- Declare them as suspicious
    ["3"] = "Somewhat suspicious",
    ["2"] = "A little suspicious",
    ["1"] = "Slightly suspicious",
    ["0"] = "Neutral",
    ["-1"] = "Slightly trustworthy",
    ["-2"] = "Somewhat trustworthy",
    ["-3"] = "Quite trustworthy",
    ["-4"] = "Very trustworthy", -- Declare them as trustworthy
    ["-5"] = "Highly likely to be innocent",
    ["-6"] = "Almost certainly innocent",
    ["-7"] = "Definitely innocent",
    ["-8"] = "Undeniably innocent", -- Declare them as innocent
    ["-9"] = "Absolutely innocent",
    ["-10"] = "Unwaveringly innocent",
}

BotMorality.Thresholds = {
    KOS = 7,
    Sus = 3,
    Trust = -3,
    Innocent = -5,
}

function BotMorality:New(bot)
    local newMorality = {}
    setmetatable(newMorality, {
        __index = function(t, k) return BotMorality[k] end,
    })
    newMorality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Morality for bot " .. bot:Nick())
    end

    return newMorality
end

function BotMorality:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Morality = self

    self.componentID = string.format("Morality (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                       -- Tick counter
    self.bot = bot
    self.suspicions = {}                                                -- A table of suspicions for each player
end

--- Increase/decrease the suspicion on the player for the given reason.
---@param target Player
---@param reason string The reason (matching a key in SUSPICIONVALUES)
function BotMorality:ChangeSuspicion(target, reason, mult)
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion()
    if roleDisablesSuspicion then return end
    if not mult then mult = 1 end
    if target == self.bot then return end                 -- Don't change suspicion on ourselves
    if TTTBots.Match.RoundActive == false then return end -- Don't change suspicion if the round isn't active, duh
    local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()
    if targetIsPolice then
        mult = mult * 0.3 -- Police are much less suspicious
    end

    local susValue = self.SUSPICIONVALUES[reason] or ErrorNoHaltWithStack("Invalid suspicion reason: " .. reason)
    local increase = math.ceil(susValue * mult)
    local susFinal = ((self:GetSuspicion(target)) + (increase))
    self.suspicions[target] = math.floor(susFinal)

    self:AnnounceIfThreshold(target)
    self:SetAttackIfTargetSus(target)

    -- print(string.format("%s's suspicion on %s has changed by %d", self.bot:Nick(), target:Nick(), increase))
end

function BotMorality:GetSuspicion(target)
    return self.suspicions[target] or 0
end

--- Announce the suspicion level of the given player if it is above a certain threshold.
---@param target Player
function BotMorality:AnnounceIfThreshold(target)
    local sus = self:GetSuspicion(target)
    local chatter = lib.GetComp(self.bot, "chatter") ---@type CChatter
    if not chatter then return end
    local KOSThresh = self.Thresholds.KOS
    local SusThresh = self.Thresholds.Sus
    local TrustThresh = self.Thresholds.Trust
    local InnocentThresh = self.Thresholds.Innocent

    if sus >= KOSThresh then
        chatter:On("CallKOS", { player = target:Nick(), playerEnt = target })
        -- self.bot:Say("I think " .. target:Nick() .. " is evil!")
    elseif sus >= SusThresh then
        -- self.bot:Say("I think " .. target:Nick() .. " is suspicious!")
    elseif sus <= InnocentThresh then
        -- self.bot:Say("I think " .. target:Nick() .. " is innocent!")
    elseif sus <= TrustThresh then
        -- self.bot:Say("I think " .. target:Nick() .. " is trustworthy!")
    end
end

--- Set the bot's attack target to the given player if they seem evil.
function BotMorality:SetAttackIfTargetSus(target)
    if self.bot.attackTarget ~= nil then return end
    local sus = self:GetSuspicion(target)
    if sus >= self.Thresholds.KOS then
        self.bot:SetAttackTarget(target)
        return true
    end
    return false
end

function BotMorality:TickSuspicions()
    local roundStarted = TTTBots.Match.RoundActive
    if not roundStarted then
        self.suspicions = {}
        return
    end
end

--- Returns a random victim player, weighted off of each player's traits.
---@param playerlist table<Player>
---@return Player
function BotMorality:GetRandomVictimFrom(playerlist)
    local tbl = {}

    for i, player in pairs(playerlist) do
        if player:IsBot() then
            local victim = player:GetTraitMult("victim")
            table.insert(tbl, lib.SetWeight(player, victim))
        else
            table.insert(tbl, lib.SetWeight(player, 1))
        end
    end

    return lib.RandomWeighted(tbl)
end

--- Makes it so that traitor bots will attack random players nearby.
function BotMorality:SetRandomNearbyTarget()
    if not (self.tick % TTTBots.Tickrate == 0) then return end -- Run only once every second
    local roundStarted = TTTBots.Match.RoundActive
    local targetsRandoms = TTTBots.Roles.GetRoleFor(self.bot):GetKillsNonAllies()
    if not (roundStarted and targetsRandoms) then return end
    if self.bot.attackTarget ~= nil then return end
    local delay = lib.GetConVarFloat("attack_delay")
    if TTTBots.Match.Time() <= delay then return end -- Don't attack randomly until the initial delay is over

    local aggression = math.max((self.bot:GetTraitMult("aggression")) * (self.bot.rage or 1), 0.3)
    local time_modifier = TTTBots.Match.SecondsPassed / 30 -- Increase chance to attack over time.

    local maxTargets = math.max(2, math.ceil(aggression * 2 * time_modifier))
    local targets = lib.GetAllVisible(self.bot:EyePos(), true, self.bot)

    if (#targets > maxTargets) or (#targets == 0) then return end -- Don't attack if there are too many targets

    local base_chance = 4.5                                       -- X% chance to attack per second
    local chanceAttackPerSec = (
        base_chance
        * aggression
        * (maxTargets / #targets)
        * time_modifier
        * (#targets == 1 and 5 or 1)
    )
    if lib.CalculatePercentChance(chanceAttackPerSec) then
        local target = BotMorality:GetRandomVictimFrom(targets)
        self.bot:SetAttackTarget(target)
    end
end

function BotMorality:TickIfLastAlive()
    if not TTTBots.Match.RoundActive then return end
    local plys = self.bot.components.memory:GetActualAlivePlayers()
    if #plys > 2 then return end
    local otherPlayer = nil
    for i, ply in pairs(plys) do
        if ply ~= self.bot then
            otherPlayer = ply
            break
        end
    end

    self.bot:SetAttackTarget(otherPlayer)
end

function BotMorality:Think()
    self.tick = (self.bot.tick or 0)
    if not lib.IsPlayerAlive(self.bot) then return end
    self:TickSuspicions()
    self:SetRandomNearbyTarget()
    self:TickIfLastAlive()
end

---Called by OnWitnessHurt, but only if we (the owning bot) is a traitor.
---@param victim Player
---@param attacker Entity
---@param healthRemaining number
---@param damageTaken number
---@return nil
function BotMorality:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if not TTTBots.Roles.IsAllies(victim, attacker) then return end

    if self.bot.attackTarget == nil then
        self.bot:SetAttackTarget(attacker)
    end
end

function BotMorality:OnKilled(attacker)
    if not (attacker and IsValid(attacker) and attacker:IsPlayer()) then
        self.bot.grudge = nil
        return
    end
    self.bot.grudge = attacker -- Set grudge to the attacker
end

function BotMorality:OnWitnessKill(victim, weapon, attacker)
    if (weapon and IsValid(weapon) and weapon.GetClass and weapon:GetClass() == "ttt_c4") then return end -- We don't know who killed who with C4, so we can't build sus on it.
    -- For this function, we will allow the bots to technically cheat and know what role the victim was. They will not know what role the attacker is.
    -- This allows us to save time and resources in optimization and let players have a more fun experience, despite technically being a cheat.
    if not lib.IsPlayerAlive(self.bot) then return end
    local vicIsTraitor = victim:GetTeam() == TEAM_TRAITOR

    -- change suspicion on the attacker by KillTraitor, KillTrusted, or Kill. Depending on role.
    if vicIsTraitor then
        self:ChangeSuspicion(attacker, "KillTraitor")
    elseif TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice() then
        self:ChangeSuspicion(attacker, "KillTrusted")
    else
        self:ChangeSuspicion(attacker, "Kill")
    end
end

function BotMorality:OnKOSCalled(caller, target)
    if not lib.IsPlayerAlive(self.bot) then return end
    if not TTTBots.Roles.GetRoleFor(caller):GetUsesSuspicion() then return end

    local callerSus = self:GetSuspicion(caller)
    local callerIsPolice = TTTBots.Roles.GetRoleFor(caller):GetAppearsPolice()
    local targetSus = self:GetSuspicion(target)

    local TRAITOR = self.Thresholds.KOS
    local TRUSTED = self.Thresholds.Trust

    if targetSus > TRAITOR then
        self:ChangeSuspicion(caller, "AffirmingKOS")
    end

    if callerIsPolice or callerSus < TRUSTED then -- if we trust the caller or they are a detective, then:
        self:ChangeSuspicion(target, "KOSByTrusted")
    elseif callerSus > TRAITOR then               -- if we think the caller is a traitor, then:
        self:ChangeSuspicion(target, "KOSByTraitor")
    else                                          -- if we don't know the caller, then:
        self:ChangeSuspicion(target, "KOSByOther")
    end
end

hook.Add("PlayerDeath", "TTTBots.Components.Morality.PlayerDeath", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    local timestamp = CurTime()
    if attacker:IsBot() then
        attacker.lastKillTime = timestamp
    end
    if victim:IsBot() then
        victim.components.morality:OnKilled(attacker)
    end
    if not victim:Visible(attacker) then return end -- This must be an indirect attack, like C4 or fire.
    if victim:GetTeam() == TEAM_INNOCENT then       -- This is technically a cheat, but it's a necessary one.
        local ttt_bot_cheat_redhanded_time = lib.GetConVarInt("cheat_redhanded_time")
        attacker.redHandedTime = timestamp +
            ttt_bot_cheat_redhanded_time -- Only assign red handed time if it was a direct attack
    end
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessKill(victim, weapon, attacker)
        end
    end
end)

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    self:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if attacker == self.bot then -- if we are the attacker, there is no sus to be thrown around.
        if victim == self.bot.attackTarget then
            local personality = lib.GetComp(self.bot, "personality")
            if not personality then return end
            personality:OnPressureEvent("HurtEnemy")
        end
        return
    end
    if self.bot == victim then -- if we are the victim, just fight back instead of worrying about sus.
        self.bot:SetAttackTarget(attacker)
        local personality = lib.GetComp(self.bot, "personality")
        if personality then
            personality:OnPressureEvent("Hurt")
        end
    end
    -- If the target is disguised, we don't know who they are, so we can't build sus on them. Instead, ATTACK!
    if TTTBots.Match.IsPlayerDisguised(attacker) then
        if self.bot.attackTarget == nil then
            self.bot:SetAttackTarget(attacker)
        end
        return
    end

    local attackerSusMod = 1.0
    local victimSusMod = 1.0
    local can_cheat = lib.GetConVarBool("cheat_know_shooter")
    if can_cheat then
        local bad_guy = TTTBots.Match.WhoShotFirst(victim, attacker)
        if bad_guy == victim then
            victimSusMod = 2.0
            attackerSusMod = 0.5
        elseif bad_guy == attacker then
            victimSusMod = 0.5
            attackerSusMod = 2.0
        end
    end

    local impact = (damageTaken / victim:GetMaxHealth()) * 3 --- Percent of max health lost * 3. 50% health lost =  6 sus
    local victimIsPolice = TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice()
    local attackerIsPolice = TTTBots.Roles.GetRoleFor(attacker):GetAppearsPolice()
    local attackerSus = self:GetSuspicion(attacker)
    local victimSus = self:GetSuspicion(victim)
    if victimIsPolice or victimSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(attacker, "HurtTrusted", impact * attackerSusMod) -- Increase sus on the attacker because we trusted their victim
    elseif attackerIsPolice or attackerSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(victim, "HurtByTrusted", impact * victimSusMod)   -- Increase sus on the victim because we trusted their attacker
    elseif attackerSus > BotMorality.Thresholds.KOS then
        self:ChangeSuspicion(victim, "HurtByEvil", impact * victimSusMod)      -- Decrease the sus on the victim because we know their attacker is evil
    else
        self:ChangeSuspicion(attacker, "Hurt", impact * attackerSusMod)        -- Increase sus on attacker because we don't trust anyone involved
    end

    -- self.bot:Say(string.format("I saw that! Attacker sus is %d; vic is %d", attackerSus, victimSus))
end

function BotMorality:OnWitnessFireBullets(attacker, data, angleDiff)
    local angleDiffPercent = angleDiff / 30
    local sus = -1 * (1 - angleDiffPercent) / 4 -- Sus decreases as angle difference grows
    if sus < 1 then sus = 0.1 end

    -- print(attacker, data, angleDiff, angleDiffPercent, sus)
    if sus > 3 then
        local personality = lib.GetComp(self.bot, "personality")
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
    end
    self:ChangeSuspicion(attacker, "ShotAt", sus)
end

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    local witnesses = lib.GetAllWitnesses(entity:EyePos(), true)

    local lookAngle = entity:EyeAngles()

    -- Combined loop for all witnesses
    for i, witness in pairs(witnesses) do
        local morality = lib.GetComp(witness, "morality")
        if morality then
            -- We calculate the angle difference between the entity and the witness
            local witnessAngle = witness:EyeAngles()
            local angleDiff = lookAngle.y - witnessAngle.y

            -- Adjust angle difference to be between -180 and 180
            angleDiff = ((angleDiff + 180) % 360) - 180
            -- Absolute value to ensure angleDiff is non-negative
            angleDiff = math.abs(angleDiff)

            morality:OnWitnessFireBullets(entity, data, angleDiff)
        end
    end
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if not victim:Visible(attacker) then return end -- This must be an indirect attack, like C4 or fire.
    -- print(victim, attacker, healthRemaining, damageTaken)
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
        end
    end
end)

hook.Add("TTTBodyFound", "TTTBots.Components.Morality.BodyFound", function(ply, deadply, rag)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not (IsValid(deadply) and deadply:IsPlayer()) then return end
    local corpseIsTraitor = deadply:GetTeam() ~= TEAM_INNOCENT
    local corpseIsPolice = deadply:GetRoleStringRaw() == "detective"

    for i, bot in pairs(lib.GetAliveBots()) do
        local morality = bot.components and bot.components.morality
        if not morality or not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
        if corpseIsTraitor then
            morality:ChangeSuspicion(ply, "IdentifiedTraitor")
        elseif corpseIsPolice then
            morality:ChangeSuspicion(ply, "IdentifiedTrusted")
        else
            morality:ChangeSuspicion(ply, "IdentifiedInnocent")
        end
    end
end)

function BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
    local IsIdentified = CORPSE.GetFound
    for _, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        if IsIdentified(corpse) then continue end
        local dist = ply:GetPos():Distance(corpse:GetPos())
        local THRESHOLD = 500
        if ply:Visible(corpse) and (dist < THRESHOLD) then
            return true
        end
    end
    return false
end

--- Table of [Player]=number showing seconds near unidentified corpses
--- Does not stack. If a player is near 2 corpses, it will only count as 1. This is to prevent innocents discovering massacres and being killed for it.
local playersNearBodies = {}
timer.Create("TTTBots.Components.Morality.PlayerCorpseTimer", 1, 0, function()
    if TTTBots.Match.RoundActive == false then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    local corpses = TTTBots.Match.Corpses

    for i, ply in pairs(alivePlayers) do
        if not IsValid(ply) then continue end
        local isNearCorpse = BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
        if isNearCorpse then
            playersNearBodies[ply] = (playersNearBodies[ply] or 0) + 1
        else
            playersNearBodies[ply] = math.max((playersNearBodies[ply] or 0) - 1, 0)
        end
    end
end)

-- Disguised player detection
timer.Create("TTTBots.Components.Morality.DisguisedPlayerDetection", 1, 0, function()
    if not TTTBots.Match.RoundActive then return end
    -- local disguised = TTTBots.Match.DisguisedPlayers -- it's more efficient go loop thru every player because we are going to detect traitor weps anyway
    local alivePlayers = TTTBots.Match.AlivePlayers
    for i, ply in pairs(alivePlayers) do
        -- local isHoldingTraitorWeapon -- TODO: Implement this later
        local isDisguised = TTTBots.Match.IsPlayerDisguised(ply)

        if isDisguised then
            local witnessBots = lib.GetAllWitnesses(ply:EyePos(), true)
            for i, bot in pairs(witnessBots) do
                if not IsValid(bot) then continue end
                if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                local chatter = lib.GetComp(bot, "chatter")
                if not chatter then continue end
                -- set attack target if we do not have one already
                bot:SetAttackTarget(bot.attackTarget or ply)
                bot.components.chatter:On("DisguisedPlayer")
            end
        end
    end
end)

timer.Create("TTTBots.Components.Morality.CommonSense", 1, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    -- TODO: Deleted this code since it didn't do much anyway. It was overcomplicated and created lag spikes.
    -- Common sense: make red-handed traitors kill anyone else nearby
end)
