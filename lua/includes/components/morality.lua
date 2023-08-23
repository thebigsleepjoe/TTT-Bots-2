--[[
    This component defines the morality of the agent. It is primarily responsible for determining who to shoot.
    It also tells traitors who to kill.
]]
---@class CMorality
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality
local BotMorality = TTTBots.Components.Morality

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    -- Killing another player
    Kill = 9,         -- This player killed someone in front of us
    KillTrusted = 10, -- This player killed a Trusted in front of us
    KillTraitor = -9, -- This player killed a traitor in front of us

    -- Hurt a player
    Hurt = 4,          -- This player hurt someone in front of us
    HurtMe = 10,       -- This player hurt us
    HurtTrusted = 10,  -- This player hurt a Trusted in front of us
    HurtByTrusted = 4, -- This player was hurt by a Trusted
    HurtByEvil = -2,   -- This player was hurt by a traitor

    -- KOS-related events
    KOSTrusted = 10, -- KOS called on this player by trusted innocent
    KOSTraitor = -5, -- KOS called on this player by known traitor
    KOS = 5,         -- KOS called on this player

    -- Role-specific weapons
    TraitorWeapon = 5, -- This player has a traitor weapon

    -- Corpse-related events
    NearUnidentified = 2,   -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -2, -- This player has identified a traitor's corpse
    IdentifiedInnocent = 1, -- This player has identified an innocent's corpse
    IdentifiedTrusted = 1,  -- This player has identified a Trusted's corpse

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
    KOS = 8,
    Sus = 4,
    Trust = -4,
    Innocent = -8,
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
    if not mult then mult = 1 end
    if target == self.bot then return end                 -- Don't change suspicion on ourselves
    if TTTBots.Match.RoundActive == false then return end -- Don't change suspicion if the round isn't active, duh
    if lib.IsEvil(self.bot) or lib.IsPolice(target) then return end

    local susValue = self.SUSPICIONVALUES[reason] or ErrorNoHalt("Invalid suspicion reason: " .. reason)
    local increase = math.ceil(susValue * mult)
    local sus = (self:GetSuspicion(target)) + (increase)
    self.suspicions[target] = math.floor(sus)

    self:AnnounceIfThreshold(target)
    self:SetAttackIfTargetEvil(target)

    print(string.format("%s's suspicion on %s has changed by %d", self.bot:Nick(), target:Nick(), increase))
end

function BotMorality:GetSuspicion(target)
    return self.suspicions[target] or 0
end

--- Announce the suspicion level of the given player if it is above a certain threshold.
---@param target Player
function BotMorality:AnnounceIfThreshold(target)
    local sus = self:GetSuspicion(target)
    local KOSThresh = self.Thresholds.KOS
    local SusThresh = self.Thresholds.Sus
    local TrustThresh = self.Thresholds.Trust
    local InnocentThresh = self.Thresholds.Innocent

    if sus >= KOSThresh then
        self.bot:Say("I think " .. target:Nick() .. " is evil!")
    elseif sus >= SusThresh then
        self.bot:Say("I think " .. target:Nick() .. " is suspicious!")
    elseif sus <= InnocentThresh then
        self.bot:Say("I think " .. target:Nick() .. " is innocent!")
    elseif sus <= TrustThresh then
        self.bot:Say("I think " .. target:Nick() .. " is trustworthy!")
    end
end

--- Set the bot's attack target to the given player if they seem evil.
function BotMorality:SetAttackIfTargetEvil(target)
    if self.bot.attackTarget ~= nil then return end
    local sus = self:GetSuspicion(target)
    if sus >= self.Thresholds.KOS then
        self.bot.attackTarget = target
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
            local victim = player:AverageTraitMultFor("victim")
            table.insert(tbl, lib.SetWeight(player, victim))
        else
            table.insert(tbl, lib.SetWeight(player, 1))
        end
    end

    return lib.RandomWeighted(tbl)
end

function BotMorality:TickIfTraitor()
    if not (self.tick % TTTBots.Tickrate == 0) then return end -- Run only once every second
    local roundStarted = TTTBots.Match.RoundActive
    local isEvil = lib.IsEvil(self.bot)
    if not (roundStarted and isEvil) then return end
    if self.bot.attackTarget ~= nil then return end

    local aggression = (self.bot:AverageTraitMultFor("aggression")) * (self.bot.rage or 1)
    local time_modifier = TTTBots.Match.SecondsPassed / 45 -- Increase chance to attack over time.

    local maxTargets = math.max(2, math.ceil(aggression * 2 * time_modifier))
    local targets = lib.GetAllVisible(self.bot:EyePos(), true)

    if (#targets > maxTargets) or (#targets == 0) then return end -- Don't attack if there are too many targets

    local base_chance = 4.5                                       -- X% chance to attack per second
    local chanceAttackPerSec = (
        base_chance
        * aggression
        * (maxTargets / #targets)
        * time_modifier
    )
    if lib.CalculatePercentChance(chanceAttackPerSec) then
        local target = BotMorality:GetRandomVictimFrom(targets)
        self.bot.attackTarget = target
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

    self.bot.attackTarget = otherPlayer
end

function BotMorality:Think()
    self.tick = (self.bot.tick or 0)
    if not lib.IsPlayerAlive(self.bot) then return end
    self:TickSuspicions()
    self:TickIfTraitor()
    self:TickIfLastAlive()
end

---Called by OnWitnessHurt, but only if we (the owning bot) is a traitor.
---@param victim Player
---@param attacker Entity
---@param healthRemaining number
---@param damageTaken number
---@return nil
function BotMorality:OnWitnessHurtTraitor(victim, attacker, healthRemaining, damageTaken)
    if not lib.IsEvil(victim) then return end

    -- The victim is evil and so are we. We should defend them if we don't have a target.
    if self.bot.attackTarget == nil then
        self.bot.attackTarget = attacker
    end
end

function BotMorality:OnWitnessKill(victim, attacker)
    -- For this function, we will allow the bots to technically cheat and know what role the victim was. They will not know what role the attacker is.
    -- This allows us to save time and resources in optimization and let players have a more fun experience, despite technically being a cheat.
    if not lib.IsPlayerAlive(self.bot) then return end
    local vicIsEvil = lib.IsEvil(victim)

    -- change suspicion on the attacker by KillTraitor, KillTrusted, or Kill. Depending on role.
    if vicIsEvil then
        self:ChangeSuspicion(attacker, "KillTraitor")
    elseif lib.IsPolice(victim) then
        self:ChangeSuspicion(attacker, "KillTrusted")
    else
        self:ChangeSuspicion(attacker, "Kill")
    end
end

hook.Add("PlayerDeath", "TTTBots.Components.Morality.PlayerDeath", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if not victim:Visible(attacker) then return end -- This must be an indirect attack, like C4 or fire.
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessKill(victim, attacker)
        end
    end
end)

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    if lib.IsEvil(self.bot) then
        self:OnWitnessHurtTraitor(victim, attacker, healthRemaining, damageTaken)
        return
    end -- We are evil, we usually don't care about this.
    if attacker == self.bot then return end
    if self.bot == victim then self.bot.attackTarget = attacker end
    -- TODO: Disguiser should be taken into account here.
    -- local bad_guy = TTTBots.Match.WhoShotFirst(victim, attacker) -- TODO: Implement this later?

    local impact = (damageTaken / victim:GetMaxHealth()) * 3 --- Percent of max health lost * 3. 50% health lost =  6 sus
    local victimIsPolice = lib.IsPolice(victim)
    local attackerIsPolice = lib.IsPolice(attacker)
    local attackerSus = self:GetSuspicion(attacker)
    local victimSus = self:GetSuspicion(victim)
    if victimIsPolice or victimSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(attacker, "HurtTrusted", impact) -- Increase sus on the attacker because we trusted their victim
    elseif attackerIsPolice or attackerSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(victim, "HurtByTrusted", impact) -- Increase sus on the victim because we trusted their attacker
    elseif attackerSus > BotMorality.Thresholds.KOS then
        self:ChangeSuspicion(victim, "HurtByEvil", impact)    -- Decrease the sus on the victim because we know their attacker is evil
    else
        self:ChangeSuspicion(attacker, "Hurt", impact)        -- Increase sus on attacker because we don't trust anyone involved
    end

    -- self.bot:Say(string.format("I saw that! Attacker sus is %d; vic is %d", attackerSus, victimSus))
end

hook.Add("TTTPlayerRadioCommand", "TTTBots.Components.Morality.TTTRadioMessage", function(ply, msgName, msgTarget)
    print(ply, msgName, msgTarget)
end)

function BotMorality:OnWitnessFireBullets(attacker, data, angleDiff)
    local angleDiffPercent = angleDiff / 30
    local sus = -1 * (1 - angleDiffPercent) / 4 -- Sus decreases as angle difference grows
    if sus < 1 then sus = 0.1 end

    -- print(attacker, data, angleDiff, angleDiffPercent, sus)

    self.bot.components.morality:ChangeSuspicion(attacker, "ShotAt", sus)
end

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    local witnesses = lib.GetAllWitnesses(entity:EyePos(), true)

    local lookAngle = entity:EyeAngles()

    -- Combined loop for all witnesses
    for i, witness in pairs(witnesses) do
        if witness.components.morality then
            -- We calculate the angle difference between the entity and the witness
            local witnessAngle = witness:EyeAngles()
            local angleDiff = lookAngle.y - witnessAngle.y

            -- Adjust angle difference to be between -180 and 180
            angleDiff = ((angleDiff + 180) % 360) - 180
            -- Absolute value to ensure angleDiff is non-negative
            angleDiff = math.abs(angleDiff)

            witness.components.morality:OnWitnessFireBullets(entity, data, angleDiff)
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
