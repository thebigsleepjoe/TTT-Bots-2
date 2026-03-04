--[[
    This component defines the morality of the agent. It is primarily responsible for determining who to shoot.
    It also tells traitors who to kill.
]]
---@class CMorality : Component
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    -- Killing another player
    Kill = 9,                -- This player killed someone in front of us
    KillTrusted = 10,        -- This player killed a Trusted in front of us
    KillTraitor = -10,       -- This player killed a traitor in front of us
    Hurt = 4,                -- This player hurt someone in front of us
    HurtMe = 10,             -- This player hurt us
    HurtTrusted = 10,        -- This player hurt a Trusted in front of us
    HurtByTrusted = 4,       -- This player was hurt by a Trusted
    HurtByEvil = -2,         -- This player was hurt by a traitor
    KOSByTrusted = 10,       -- KOS called on this player by trusted innocent
    KOSByTraitor = -5,       -- KOS called on this player by known traitor
    KOSByOther = 5,          -- KOS called on this player
    AffirmingKOS = -3,       -- KOS called on a player we think is a traitor (rare, but possible)
    TraitorWeapon = 10,      -- This player has a traitor weapon
    NearUnidentified = 2,    -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -3,  -- This player has identified a traitor's corpse
    IdentifiedInnocent = -2, -- This player has identified an innocent's corpse
    IdentifiedTrusted = -2,  -- This player has identified a Trusted's corpse
    DefuseC4 = -7,           -- This player is defusing C4
    PlantC4 = 10,            -- This player is throwing down C4
    FollowingMe = 3,         -- This player has been following me for more than 10 seconds
    ShotAtMe = 7,            -- This player has been shooting at me
    ShotAt = 5,              -- This player has been shooting at someone
    ShotAtTrusted = 6,       -- This player has been shooting at a Trusted
    ThrowDiscombob = 2,      -- This player has thrown a discombobulator
    ThrowIncin = 8,          -- This player has thrown an incendiary grenade
    ThrowSmoke = 3,          -- This player has thrown a smoke grenade
    PersonalSpace = 2,       -- This player is standing too close to me for too long
    C4Killed = 8,            -- We survived a C4 explosion and traced it to this player
    HearGunfight = 3,        -- We heard gunfire associated with this player (sound-based suspicion)
    HoldingC4 = 10,          -- This player is holding a C4 bomb (instant KOS)
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
    self.bot = bot ---@type Bot
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

    mult = mult * (hook.Run("TTTBotsModifySuspicion", self.bot, target, reason, mult) or 1)

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
    local chatter = self.bot:BotChatter()
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
    local targetsRandoms = TTTBots.Roles.GetRoleFor(self.bot):GetStartsFights()
    if not (roundStarted and targetsRandoms) then return end
    if self.bot.attackTarget ~= nil then return end
    local delay = lib.GetConVarFloat("attack_delay")
    if TTTBots.Match.Time() <= delay then return end -- Don't attack randomly until the initial delay is over

    local aggression = math.max((self.bot:GetTraitMult("aggression")) * (self.bot:BotPersonality().rage / 100), 0.3)
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
    if lib.TestPercent(chanceAttackPerSec) then
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
---@param attacker Player
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
    if not TTTBots.Match.IsRoundActive() then return end
    local timestamp = CurTime()
    if attacker:IsBot() then
        attacker.lastKillTime = timestamp
    end
    if victim:IsBot() then
        victim.components.morality:OnKilled(attacker)
    end

    -- Check if this is an indirect attack (C4, fire, etc.)
    local isIndirectKill = not victim:Visible(attacker)
    local isC4Kill = weapon and IsValid(weapon) and weapon.GetClass and weapon:GetClass() == "ttt_c4"

    -- C4/indirect kills: only bots who already suspected the planter escalate.
    if isC4Kill or isIndirectKill then
        -- Try to identify the planter
        local planter = nil
        if isC4Kill and IsValid(weapon) then
            planter = weapon.oTTTBotsPlanter
        end
        if not IsValid(planter) then
            for c4, _ in pairs(TTTBots.Match.AllArmedC4s or {}) do
                if IsValid(c4) and IsValid(c4.oTTTBotsPlanter) then
                    if c4:GetPos():Distance(victim:GetPos()) < 1000 then
                        planter = c4.oTTTBotsPlanter
                        break
                    end
                end
            end
        end

        -- Only escalate for bots who already had the planter flagged
        if IsValid(planter) and planter:IsPlayer() and lib.IsPlayerAlive(planter) then
            for _, bot in ipairs(TTTBots.Bots) do
                if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
                if bot == planter then continue end
                if TTTBots.Roles.IsAllies(bot, planter) then continue end
                if not bot.components or not bot.components.morality then continue end

                local morality = bot.components.morality
                local existingSus = morality:GetSuspicion(planter) or 0

                -- Only escalate if the bot already had the planter at "Suspicious" level or above
                if existingSus >= BotMorality.Thresholds.Sus then
                    morality:ChangeSuspicion(planter, "C4Killed")
                end
            end
        end

        -- Skip direct-kill witness system; proximity reaction still runs below.
    end

    if not isIndirectKill and not isC4Kill then
        if victim:GetTeam() == TEAM_INNOCENT then       -- This is technically a cheat, but it's a necessary one.
            local ttt_bot_cheat_redhanded_time = lib.GetConVarInt("cheat_redhanded_time")
            attacker.redHandedTime = timestamp +
                ttt_bot_cheat_redhanded_time -- Only assign red handed time if it was a direct attack
        end

        -- Original witness system: bots who can see the attacker (90 degree arc)
        local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
        table.insert(witnesses, victim)

        for i, witness in pairs(witnesses) do
            if witness and witness.components then
                witness.components.morality:OnWitnessKill(victim, weapon, attacker)
            end
        end
    end

    -- Nearby bots react to seeing someone die close to them
    local DEATH_REACT_RANGE = 600
    local victimPos = victim:GetPos()
    local vicIsTraitor = victim:GetTeam() == TEAM_TRAITOR

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if bot == attacker or bot == victim then continue end
        if bot.attackTarget ~= nil then continue end

        local dist = bot:GetPos():Distance(victimPos)
        if dist > DEATH_REACT_RANGE then continue end

        if not bot:VisibleVec(victimPos + Vector(0, 0, 16)) then continue end

        if not vicIsTraitor then
            if not TTTBots.Roles.IsAllies(bot, attacker) then
                bot:SetAttackTarget(attacker)

                local memory = bot.components.memory
                if memory then
                    memory:UpdateKnownPositionFor(attacker, attacker:GetPos())
                end

                local chatter = bot:BotChatter()
                if chatter then
                    chatter:On("CallKOS", { player = attacker:Nick(), playerEnt = attacker })
                end
            end
        end
    end
end)

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    if damageTaken < 1 then return end -- Don't care.
    self:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if attacker == self.bot then       -- if we are the attacker, there is no sus to be thrown around.
        if victim == self.bot.attackTarget then
            local personality = self.bot:BotPersonality()
            if not personality then return end
            personality:OnPressureEvent("HurtEnemy")
        end
        return
    end
    if self.bot == victim then -- if we are the victim, just fight back instead of worrying about sus.
        self.bot:SetAttackTarget(attacker)
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("Hurt")
        end
    end
    if self.bot == victim or (self.bot == attacker and TTTBots.Roles.IsAllies(victim, attacker)) then return end -- Don't build sus on ourselves or our allies
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
    local angleDiffPercent = math.Clamp(angleDiff / 30, 0, 1)
    local sus = (1 - angleDiffPercent) / 4 -- Sus increases as angle difference shrinks (shots closer to us)
    if sus < 0.1 then sus = 0.1 end

    -- print(attacker, data, angleDiff, angleDiffPercent, sus)
    if sus > 3 then
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
    end
    self:ChangeSuspicion(attacker, "ShotAt", sus)
end

--- Called when a bullet passes close to us. Fights back if the shot was likely aimed at us.
---@param attacker Player The player who fired
---@param aimAngleToMe number Degrees between the shot direction and us (0 = dead on)
function BotMorality:OnNearMiss(attacker, aimAngleToMe)
    if not lib.IsPlayerAlive(self.bot) then return end
    if attacker == self.bot then return end
    if TTTBots.Roles.IsAllies(self.bot, attacker) then return end

    -- If we're already fighting THIS attacker, just refresh and skip
    if self.bot.attackTarget == attacker then
        self.bot.tttbots_nearMissTime = CurTime()
        return
    end

    -- Under 5 degrees = almost certainly aimed at us
    local directlyAtMe = aimAngleToMe < 5

    -- Check for nearby bystanders the shooter might be targeting instead
    local nearbyPlayers = 0
    if not directlyAtMe then
        local allPlys = player.GetAll()
        local nearRangeSqr = 300 * 300
        local botPos = self.bot:GetPos()
        for i = 1, #allPlys do
            local ply = allPlys[i]
            if ply == self.bot or ply == attacker then continue end
            if not lib.IsPlayerAlive(ply) then continue end
            if botPos:DistToSqr(ply:GetPos()) < nearRangeSqr then
                nearbyPlayers = nearbyPlayers + 1
            end
        end
    end

    if directlyAtMe or nearbyPlayers <= 1 then
        self.bot.tttbots_nearMissTime = CurTime()

        self.bot:SetAttackTarget(attacker)
        self:ChangeSuspicion(attacker, "ShotAtMe")
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
        local chatter = self.bot:BotChatter()
        if chatter then
            chatter:On("CallKOS", { player = attacker:Nick(), playerEnt = attacker })
        end
    else
        -- Someone else is nearby; just bump suspicion heavily
        self:ChangeSuspicion(attacker, "ShotAt", 1.5)
    end
end

local FIRE_BULLETS_RANGE_SQR = 1500 * 1500
local VEC_UP_8 = Vector(0, 0, 8)

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    if not TTTBots.Match.IsRoundActive() then return end

    local shooterPos = data.Src or entity:EyePos()
    local shootDir = data.Dir or entity:GetAimVector()
    local curTime = CurTime()

    for i, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if bot == entity then continue end

        -- Debounce: skip if this bot already processed a bullet from this shooter recently
        bot._lastFireBulletCheck = bot._lastFireBulletCheck or {}
        local lastCheck = bot._lastFireBulletCheck[entity] or 0
        if curTime - lastCheck < 0.1 then continue end

        local botPos = bot:GetPos()
        if shooterPos:DistToSqr(botPos) > FIRE_BULLETS_RANGE_SQR then continue end

        bot._lastFireBulletCheck[entity] = curTime

        -- Check aim angle against head, center mass, and feet
        local botCenter = bot:WorldSpaceCenter()
        local botEye = bot:EyePos()
        local botFeet = botPos + VEC_UP_8

        local bestAngle = 180
        for _, targetPos in ipairs({ botCenter, botEye, botFeet }) do
            local toPoint = (targetPos - shooterPos):GetNormalized()
            local dot = shootDir:Dot(toPoint)
            local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))
            if angle < bestAngle then
                bestAngle = angle
            end
        end

        if bestAngle < 15 then
            local morality = bot:BotMorality()
            if morality then
                morality:OnNearMiss(entity, bestAngle)
            end
        end

        if lib.CanSeeArc(bot, shooterPos, 90) then
            local morality = bot:BotMorality()
            if morality then
                morality:OnWitnessFireBullets(entity, data, bestAngle)
                hook.Run("TTTBotsOnWitnessFireBullets", bot, entity, data, bestAngle)
            end
        end
    end
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end

    if not victim:Visible(attacker) then
        -- Indirect attack — only blame C4 planter if already suspected
        if victim:IsBot() and victim.components and victim.components.morality then
            local victimPos = victim:GetPos()
            for c4, _ in pairs(TTTBots.Match.AllArmedC4s or {}) do
                if not IsValid(c4) then continue end
                local planter = c4.oTTTBotsPlanter
                if not (IsValid(planter) and planter:IsPlayer() and lib.IsPlayerAlive(planter)) then continue end
                if TTTBots.Roles.IsAllies(victim, planter) then continue end

                if c4:GetPos():Distance(victimPos) < 1000 then
                    local morality = victim.components.morality
                    local existingSus = morality:GetSuspicion(planter) or 0
                    -- Only escalate if we already had them flagged as suspicious
                    if existingSus >= BotMorality.Thresholds.Sus then
                        morality:ChangeSuspicion(planter, "C4Killed")
                    end
                    break
                end
            end

            -- Can't see attacker but got hurt — turn and fight if close enough
            if attacker ~= victim and not TTTBots.Roles.IsAllies(victim, attacker) then
                local dist = victimPos:Distance(attacker:GetPos())
                if dist < 1500 then
                    victim:SetAttackTarget(attacker)
                    local personality = victim:BotPersonality()
                    if personality then
                        personality:OnPressureEvent("Hurt")
                    end
                    -- Look toward the attacker so we can start engaging
                    local loco = victim:BotLocomotor()
                    if loco then
                        loco:LookAt(attacker:GetPos() + Vector(0, 0, 48))
                    end
                end
            end
        end
        return
    end

    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
            hook.Run("TTTBotsOnWitnessHurt", witness, victim, attacker, healthRemaining, damageTaken)
        end
    end

    -- Hearing-based reaction: nearby bots who can't see the attacker
    local HEAR_RANGE_SQR = 1250 * 1250
    local attackerPos = attacker:GetPos()
    local VEC_UP_72 = Vector(0, 0, 72)
    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if bot == attacker or bot == victim then continue end
        if not bot.components or not bot.components.morality then continue end

        if bot:GetPos():DistToSqr(attackerPos) > HEAR_RANGE_SQR then continue end

        if lib.CanSeeArc(bot, attacker:EyePos(), 90) then continue end

        -- Look toward the fight unless already reacting to a near-miss
        local loco = bot:BotLocomotor()
        local recentNearMiss = (bot.tttbots_nearMissTime or 0) + 3 > CurTime()
        if loco and bot.attackTarget == nil and not recentNearMiss then
            loco:LookAt(attackerPos + VEC_UP_72)
        end

        if bot.components.memory then
            bot.components.memory:UpdateKnownPositionFor(attacker, attackerPos)
        end
    end
end)

hook.Add("TTTBodyFound", "TTTBots.Components.Morality.BodyFound", function(ply, deadply, rag)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not (IsValid(deadply) and deadply:IsPlayer()) then return end
    local corpseIsTraitor = deadply:GetTeam() == TEAM_TRAITOR
    local corpseRoleData = TTTBots.Roles.GetRoleFor(deadply)
    local corpseIsPolice = corpseRoleData and corpseRoleData:GetAppearsPolice() or false

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

--- Consolidated per-player awareness timer: corpse tracking + disguised player detection.
--- Runs once per second, single iteration over alive players.
timer.Create("TTTBots.Components.Morality.PlayerAwareness", 1, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    local corpses = TTTBots.Match.Corpses

    for i, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end

        -- Corpse proximity tracking
        local isNearCorpse = BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
        if isNearCorpse then
            playersNearBodies[ply] = (playersNearBodies[ply] or 0) + 1
        else
            playersNearBodies[ply] = math.max((playersNearBodies[ply] or 0) - 1, 0)
        end

        -- Disguised player detection
        local isDisguised = TTTBots.Match.IsPlayerDisguised(ply)
        if isDisguised then
            local witnessBots = lib.GetAllWitnesses(ply:EyePos(), true)
            for _, bot in ipairs(witnessBots) do
                ---@cast bot Bot
                if not IsValid(bot) then continue end
                if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                local chatter = bot:BotChatter()
                if not chatter then continue end
                bot:SetAttackTarget(bot.attackTarget or ply)
                chatter:On("DisguisedPlayer")
            end
        end
    end
end)

---Keep killing any nearby non-allies if we're red-handed.
---@param bot Bot
local function continueMassacre(bot)
    local isRedHanded = bot.redHandedTime and (CurTime() < bot.redHandedTime)
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()

    if isRedHanded and isKillerRole then
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL then
            bot:SetAttackTarget(closest)
        end
    end
end

local function preventAttackAlly(bot)
    local attackTarget = bot.attackTarget
    local isAllies = TTTBots.Roles.IsAllies(bot, attackTarget)
    if isAllies then
        bot:SetAttackTarget(nil)
    end
end

local PS_RADIUS_SQR = 100 * 100
local PS_INTERVAL = 5 -- time before we start caring about personal space
local function personalSpace(bot)
    bot.personalSpaceTbl = bot.personalSpaceTbl or {}
    local ticked = {}
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end
    if IsValid(bot.attackTarget) then return end -- don't care about personal space if we're attacking someone

    local botPos = bot:GetPos()
    for _, other in ipairs(TTTBots.Match.AlivePlayers) do
        if other == bot then continue end
        if not IsValid(other) then continue end
        if TTTBots.Roles.IsAllies(bot, other) then continue end
        if botPos:DistToSqr(other:GetPos()) > PS_RADIUS_SQR then continue end
        if not bot:Visible(other) then continue end

        bot.personalSpaceTbl[other] = (bot.personalSpaceTbl[other] or 0) + 0.5
        ticked[other] = true
    end

    for other, time in pairs(bot.personalSpaceTbl) do
        if not ticked[other] then
            bot.personalSpaceTbl[other] = math.max(time - 0.5, 0)
        end

        if (bot.personalSpaceTbl[other] or 0) <= 0 then
            bot.personalSpaceTbl[other] = nil
        end

        if (bot.personalSpaceTbl[other] or 0) >= PS_INTERVAL then
            local morality = bot:BotMorality()
            if morality then morality:ChangeSuspicion(other, "PersonalSpace") end
            local chatter = bot:BotChatter()
            if chatter then chatter:On("PersonalSpace", { player = other:Nick() }) end
            bot.personalSpaceTbl[other] = nil
        end
    end
end

--- Look at the players around us and see if they are holding any T-weapons.
local function noticeTraitorWeapons(bot)
    if bot.attackTarget ~= nil then return end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end

    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local filtered = TTTBots.Lib.FilterTable(visible, function(other)
        if TTTBots.Roles.GetRoleFor(other):GetAppearsPolice() then return false end -- We don't sus detectives.
        local hasTWeapon = TTTBots.Lib.IsHoldingTraitorWep(other)
        if not hasTWeapon then return false end
        local iCanSee = TTTBots.Lib.CanSeeArc(bot, other:GetPos() + Vector(0, 0, 24), 90)
        return iCanSee
    end)

    if #filtered == 0 then return end

    local firstEnemy = TTTBots.Lib.GetClosest(filtered, bot:GetPos()) ---@cast firstEnemy Player?
    if not firstEnemy then return end
    bot:SetAttackTarget(firstEnemy)
    local chatter = bot:BotChatter()
    if chatter then chatter:On("HoldingTraitorWeapon", { player = firstEnemy:Nick() }) end
end

--- Detect anyone visibly holding C4. For innocent-side bots this is instant KOS --
--- only traitors carry C4, so seeing someone hold it is a dead giveaway.
local function noticeC4Holders(bot)
    if bot.attackTarget ~= nil then return end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end

    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    for _, other in pairs(nonAllies) do
        if not (IsValid(other) and other ~= NULL and lib.IsPlayerAlive(other)) then continue end
        if TTTBots.Roles.GetRoleFor(other):GetAppearsPolice() then continue end

        -- Check if this player is visibly holding C4
        local activeWep = other:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt_c4") then continue end

        if not TTTBots.Lib.CanSeeArc(bot, other:GetPos() + Vector(0, 0, 24), 90) then continue end

        local morality = bot.components and bot.components.morality
        if morality then
            morality:ChangeSuspicion(other, "HoldingC4")
        end
        bot:SetAttackTarget(other)

        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("CallKOS", { player = other:Nick(), playerEnt = other })
        end
        return -- One target at a time
    end
end

local function commonSense(bot)
    continueMassacre(bot)
    preventAttackAlly(bot)
    personalSpace(bot)
    noticeTraitorWeapons(bot)
    noticeC4Holders(bot)
end

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotMorality()
    ---@cast self Bot
    if not self.components then return nil end
    return self.components.morality
end

--- Hearing-based suspicion logic for a single bot. Called every 2 seconds.
---@param bot Bot
local function hearingReaction(bot)
    if not bot.components or not bot.components.memory or not bot.components.morality then return end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end

    local memory = bot.components.memory
    local morality = bot.components.morality
    local curTime = CurTime()

    local recentSounds = memory:GetRecentSounds()
    local heardShooters = {}
    for _, s in ipairs(recentSounds) do
        if s.sound ~= "Gunshot" then continue end
        if (curTime - s.time) > 8 then continue end
        if not (s.ply and IsValid(s.ply) and s.ply ~= bot) then continue end
        if lib.CanSeeArc(bot, s.pos, 90) then continue end
        heardShooters[s.ply] = (heardShooters[s.ply] or 0) + 1
    end

    for shooter, count in pairs(heardShooters) do
        if count >= 2 and not TTTBots.Roles.IsAllies(bot, shooter) then
            morality:ChangeSuspicion(shooter, "HearGunfight")
        end
    end

    local cluster = memory:GetMostUrgentGunfight()
    if cluster and cluster.count >= 3 and (curTime - cluster.newest) < 6 then
        local dist = bot:GetPos():Distance(cluster.pos)
        local recentNearMiss = (bot.tttbots_nearMissTime or 0) + 3 > curTime
        if dist < 2000 and bot.attackTarget == nil and not recentNearMiss then
            local loco = bot:BotLocomotor()
            if loco then
                loco:LookAt(cluster.pos + Vector(0, 0, 72))
            end
        end
    end
end

--- Consolidated per-bot awareness timer: common sense + hearing reaction.
--- Runs once per second with a single bot iteration. Hearing reaction runs
--- every other cycle (effectively every 2 seconds) via a tick counter.
local botAwarenessTick = 0
timer.Create("TTTBots.Components.Morality.BotAwareness", 1, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    botAwarenessTick = botAwarenessTick + 1
    local doHearing = (botAwarenessTick % 2 == 0)

    for i, bot in ipairs(TTTBots.Bots) do
        if not bot or bot == NULL or not IsValid(bot) then continue end
        if not bot.initialized or not bot.components then continue end
        if not lib.IsPlayerAlive(bot) then continue end

        -- Common sense (every 1s)
        if bot.components.chatter and bot:BotLocomotor() then
            commonSense(bot)
        end

        -- Hearing reaction (every 2s)
        if doHearing then
            hearingReaction(bot)
        end
    end
end)
