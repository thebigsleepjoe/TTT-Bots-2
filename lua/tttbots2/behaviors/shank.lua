--- Shank: hunt isolated players and backstab them. Flee after kills.

---@class BShank
TTTBots.Behaviors.Shank = {}

local lib = TTTBots.Lib

---@class BShank
local Shank = TTTBots.Behaviors.Shank
Shank.Name = "Shank"
Shank.Description = "Backstab isolated targets with the shanker knife."
Shank.Interruptible = true

Shank.STRIKE_RANGE = 120         --- Distance to begin the backstab attack
Shank.APPROACH_RANGE = 500       --- Within this range, start circling to get behind
Shank.FLEE_DISTANCE = 800        --- How far to run after a kill
Shank.FLEE_TIME = 6              --- Seconds to spend fleeing after a kill
Shank.MAX_WITNESSES = 1          --- Maximum non-ally witnesses before aborting a shank attempt
Shank.BEHIND_DOT_THRESHOLD = 0   --- Dot product threshold: < 0 means we're behind (facing their back)
Shank.PATIENCE_TIME = 30         --- Seconds of stalking before we give up on stealth and just attack

local STATUS = TTTBots.STATUS

--- Find the shanker knife weapon on the bot. Checks common class names.
---@param bot Bot
---@return Weapon|nil
function Shank.GetShankerKnife(bot)
    return lib.FindWeaponByPattern(bot, {
        "shankerknife", "shanker_knife", "shanker"
    })
end

--- Check if the bot is behind the target (target is facing away from us).
---@param bot Bot
---@param target Player
---@return boolean isBehind
function Shank.IsBehindTarget(bot, target)
    local toBot = (bot:GetPos() - target:GetPos()):GetNormalized()
    local targetForward = target:GetForward()
    -- Flatten to 2D (ignore vertical component)
    toBot.z = 0
    targetForward.z = 0
    toBot:Normalize()
    targetForward:Normalize()

    local dot = targetForward:Dot(toBot)
    -- dot < 0 means the bot is behind the target (target facing away)
    return dot < Shank.BEHIND_DOT_THRESHOLD
end

--- Get a position behind the target for flanking.
---@param target Player
---@return Vector
function Shank.GetPositionBehind(target)
    local behindDir = -target:GetForward()
    behindDir.z = 0
    behindDir:Normalize()
    return target:GetPos() + behindDir * 80
end

--- Validate: only runs for shanker bots with the shanker knife.
---@param bot Bot
---@return boolean
function Shank.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end

    -- Don't shank if we're already fighting back (FightBack handles that)
    if bot.attackTarget ~= nil then return false end

    -- Allow continuing flee phase even without knife
    if bot.shankPhase == "flee" then return true end

    -- Must have the shanker knife
    return Shank.GetShankerKnife(bot) ~= nil
end

---@param bot Bot
---@return BStatus
function Shank.OnStart(bot)
    bot.shankStartTime = CurTime()
    bot.shankPhase = "stalk"  -- stalk → approach → strike → flee
    bot.shankTarget = nil
    bot.shankFleeStart = nil

    -- Find an isolated target
    local target, score = lib.FindIsolatedTarget(bot)
    if target and IsValid(target) and lib.IsPlayerAlive(target) then
        bot.shankTarget = target
    end

    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function Shank.OnRunning(bot)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    local inv = bot:BotInventory()

    local phase = bot.shankPhase or "stalk"

    ---------------------------------------------------------------------------
    -- PHASE: FLEE — run away from the kill, never confirm the body
    ---------------------------------------------------------------------------
    if phase == "flee" then
        local fleeSpot = bot.shankFleeSpot
        if not fleeSpot then return STATUS.SUCCESS end

        loco:SetGoal(fleeSpot)

        local elapsed = CurTime() - (bot.shankFleeStart or CurTime())
        if elapsed > Shank.FLEE_TIME then
            return STATUS.SUCCESS
        end

        local distToFlee = bot:GetPos():Distance(fleeSpot)
        if distToFlee < 100 then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- TARGET VALIDATION
    ---------------------------------------------------------------------------
    local target = bot.shankTarget
    if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
        -- Target died or invalid — find a new one
        local newTarget = lib.FindIsolatedTarget(bot)
        if not (newTarget and IsValid(newTarget) and lib.IsPlayerAlive(newTarget)) then
            return STATUS.FAILURE
        end
        bot.shankTarget = newTarget
        target = newTarget
    end

    local botPos = bot:GetPos()
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()
    local dist = botPos:Distance(targetPos)
    local canSee = bot:Visible(target)
    local isBehind = Shank.IsBehindTarget(bot, target)
    local elapsed = CurTime() - (bot.shankStartTime or CurTime())

    -- Check witnesses: abort stealth approach if too many people watching
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local witnesses = lib.GetAllWitnessesBasic(botPos, nonAllies, bot)
    local witnessCount = #witnesses

    ---------------------------------------------------------------------------
    -- PHASE: STALK — approach the target, staying at distance
    ---------------------------------------------------------------------------
    if phase == "stalk" then
        -- Use memory to track target if we can't see them
        if not canSee then
            local memory = bot.components and bot.components.memory
            if memory then
                local knownPos = memory:GetKnownPositionFor(target)
                if knownPos then
                    loco:SetGoal(knownPos)
                end
            else
                loco:SetGoal(targetPos)
            end
            return STATUS.RUNNING
        end

        -- We can see the target. Move toward them.
        loco:SetGoal(targetPos)

        -- Once within approach range, transition to approach phase
        if dist <= Shank.APPROACH_RANGE then
            bot.shankPhase = "approach"
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE: APPROACH — get behind the target and close distance
    ---------------------------------------------------------------------------
    if phase == "approach" then
        if not canSee then
            -- Lost sight, go back to stalking
            bot.shankPhase = "stalk"
            return STATUS.RUNNING
        end

        -- Equip the shanker knife
        local knife = Shank.GetShankerKnife(bot)
        if knife and IsValid(knife) then
            local activeWep = bot:GetActiveWeapon()
            if not (IsValid(activeWep) and activeWep == knife) then
                pcall(bot.SelectWeapon, bot, knife:GetClass())
                if inv then inv:PauseAutoSwitch() end
            end
        end

        -- Try to get behind the target
        if isBehind and dist <= Shank.STRIKE_RANGE then
            -- We're behind and in range! Strike!
            bot.shankPhase = "strike"
            return STATUS.RUNNING
        end

        -- If we're behind but not close enough, walk straight to them
        if isBehind then
            loco:SetGoal(targetPos)
            loco:LookAt(targetEyes)
            return STATUS.RUNNING
        end

        -- Not behind yet: circle to their back
        local behindPos = Shank.GetPositionBehind(target)
        loco:SetGoal(behindPos)

        -- If we've been patient enough, just rush them
        if elapsed > Shank.PATIENCE_TIME then
            bot.shankPhase = "strike"
            return STATUS.RUNNING
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE: STRIKE — attack the target
    ---------------------------------------------------------------------------
    if phase == "strike" then
        if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
            -- Target is dead! Flee!
            Shank.StartFlee(bot, targetPos)
            return STATUS.RUNNING
        end

        loco:LookAt(targetEyes)

        -- Check if target turned around (facing us now)
        local targetFacingUs = not Shank.IsBehindTarget(bot, target)

        if targetFacingUs and dist > 80 then
            -- They spotted us! Switch to primary weapon and shoot
            if inv then inv:ResumeAutoSwitch() end
            bot:SetAttackTarget(target)

            -- After kill, the OnEnd will trigger flee via a hook or we just succeed
            return STATUS.SUCCESS
        end

        -- Still behind (or very close): keep using the knife
        local knife = Shank.GetShankerKnife(bot)
        if knife and IsValid(knife) then
            local activeWep = bot:GetActiveWeapon()
            if not (IsValid(activeWep) and activeWep == knife) then
                pcall(bot.SelectWeapon, bot, knife:GetClass())
            end
        end

        -- Close in and attack
        if dist > 70 then
            loco:SetGoal(targetPos)
        else
            loco:SetGoal()
        end
        loco:LookAt(targetEyes)
        loco:StartAttack()

        return STATUS.RUNNING
    end

    return STATUS.FAILURE
end

--- Start the flee phase after a kill.
---@param bot Bot
---@param killPos Vector
function Shank.StartFlee(bot, killPos)
    bot.shankPhase = "flee"
    bot.shankFleeStart = CurTime()

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    bot.shankFleeSpot = lib.FindFleeSpot(bot, killPos, Shank.FLEE_DISTANCE)
end

---@param bot Bot
function Shank.OnSuccess(bot)
end

---@param bot Bot
function Shank.OnFailure(bot)
end

---@param bot Bot
function Shank.OnEnd(bot)
    bot.shankTarget = nil
    bot.shankPhase = nil
    bot.shankStartTime = nil
    bot.shankFleeStart = nil
    bot.shankFleeSpot = nil
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

---------------------------------------------------------------------------
-- Shanker kill detection: when a shanker bot kills someone, trigger flee.
-- Covers both knife backstabs (strike phase) and gun kills (after target
-- turned around and we fell through to attacktarget).
---------------------------------------------------------------------------
hook.Add("PlayerDeath", "TTTBots.Behavior.Shank.FleeOnKill", function(victim, weapon, attacker)
    if not (IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot()) then return end
    if not TTTBots.Match.IsRoundActive() then return end

    -- Check if attacker is a shanker bot
    if not ROLE_SHANKER then return end
    if not (attacker.GetSubRole and attacker:GetSubRole() == ROLE_SHANKER) then return end

    -- If the shanker is in strike phase, start fleeing
    if attacker.shankPhase == "strike" then
        Shank.StartFlee(attacker, victim:GetPos())
        return
    end

    -- If the shanker just killed their shank target (e.g. with a gun after switching),
    -- also flee. The bot should never linger near their kills.
    if attacker.shankTarget == victim then
        Shank.StartFlee(attacker, victim:GetPos())
        return
    end

    -- Even for opportunistic kills, shanker bots flee. They don't confirm.
    Shank.StartFlee(attacker, victim:GetPos())
end)
