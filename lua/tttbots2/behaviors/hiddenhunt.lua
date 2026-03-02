--- HiddenHunt: activate invisibility, then hunt targets with knife only.

---@class BHiddenHunt
TTTBots.Behaviors.HiddenHunt = {}

local lib = TTTBots.Lib

---@class BHiddenHunt
local HiddenHunt = TTTBots.Behaviors.HiddenHunt
HiddenHunt.Name = "HiddenHunt"
HiddenHunt.Description = "Activate Hidden powers, hunt with knife while invisible, flee when damaged."
HiddenHunt.Interruptible = true

HiddenHunt.STRIKE_RANGE = 130       --- Distance to start melee attack
HiddenHunt.APPROACH_RANGE = 400     --- Within this range, rush in for the kill
HiddenHunt.FLEE_DISTANCE = 900      --- How far to run when damaged/visible
HiddenHunt.FLEE_TIME = 8            --- Seconds to flee (wait for invisibility to return)
HiddenHunt.ACTIVATE_DELAY = 3       --- Seconds after round start before activating powers
HiddenHunt.DAMAGE_FLEE_THRESHOLD = 0 --- Accumulated damage that triggers flee (0 = any damage triggers check)
HiddenHunt.RETARGET_INTERVAL = 8    --- Seconds between checking for better targets

local STATUS = TTTBots.STATUS

--- Find the Hidden's knife weapon.
---@param bot Bot
---@return Weapon|nil
function HiddenHunt.GetHiddenKnife(bot)
    return lib.FindWeaponByPattern(bot, {
        "hdnknife", "hidden_knife", "hdn_knife", "hiddenknife"
    })
end

--- Find the Hidden's stun grenade.
---@param bot Bot
---@return Weapon|nil
function HiddenHunt.GetHiddenGrenade(bot)
    return lib.FindWeaponByPattern(bot, {
        "hdngrenade", "hidden_grenade", "hdn_grenade", "hdn_stun", "hiddengrenade"
    })
end

--- Check if the Hidden has activated their powers (has the knife).
---@param bot Bot
---@return boolean
function HiddenHunt.HasActivated(bot)
    return bot.hiddenActivated == true
end

--- Check if the Hidden is currently partially visible (recently damaged).
--- The addon sets a networked bool or changes the player's render mode.
--- We detect this by tracking recent damage.
---@param bot Bot
---@return boolean
function HiddenHunt.IsPartiallyVisible(bot)
    if not bot.hiddenLastDamageTime then return false end
    -- The Hidden becomes partially visible after taking damage,
    -- and returns to full invisibility after a delay (roughly 5-8 seconds).
    local timeSinceDamage = CurTime() - bot.hiddenLastDamageTime
    return timeSinceDamage < 6
end

--- Find a navmesh-valid flee spot far from a given position.
---@param bot Bot
---@param dangerPos Vector
---@return Vector
function HiddenHunt.FindFleeSpot(bot, dangerPos)
    return lib.FindFleeSpot(bot, dangerPos, HiddenHunt.FLEE_DISTANCE)
end

--- Validate: only runs for Hidden bots.
---@param bot Bot
---@return boolean
function HiddenHunt.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end
    return true
end

---@param bot Bot
---@return BStatus
function HiddenHunt.OnStart(bot)
    bot.hiddenPhase = "activate"  -- activate → hunt → strike → flee
    bot.hiddenTarget = nil
    bot.hiddenActivated = false
    bot.hiddenActivateTime = CurTime() + HiddenHunt.ACTIVATE_DELAY
    bot.hiddenLastDamageTime = nil
    bot.hiddenFleeStart = nil
    bot.hiddenFleeSpot = nil
    bot.hiddenLastRetarget = 0
    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function HiddenHunt.OnRunning(bot)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    local inv = bot:BotInventory()

    local phase = bot.hiddenPhase or "activate"

    ---------------------------------------------------------------------------
    -- PHASE: ACTIVATE — press Reload to activate Hidden powers
    ---------------------------------------------------------------------------
    if phase == "activate" then
        -- Wait a moment before activating (don't instantly press R on round start)
        if CurTime() < (bot.hiddenActivateTime or 0) then
            return STATUS.RUNNING
        end

        -- Check if we already have the knife (powers already active)
        local knife = HiddenHunt.GetHiddenKnife(bot)
        if knife then
            bot.hiddenActivated = true
            bot.hiddenPhase = "hunt"
            if inv then inv:PauseAutoSwitch() end
            return STATUS.RUNNING
        end

        -- Press Reload to activate powers
        loco:Reload()
        bot.hiddenActivated = true
        bot.hiddenPhase = "hunt"
        if inv then inv:PauseAutoSwitch() end

        -- Small delay for the power to actually activate
        bot.hiddenActivateTime = CurTime() + 0.5
        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE: FLEE — run away when damaged (partially visible)
    ---------------------------------------------------------------------------
    if phase == "flee" then
        local fleeSpot = bot.hiddenFleeSpot
        if not fleeSpot then
            bot.hiddenPhase = "hunt"
            return STATUS.RUNNING
        end

        loco:SetGoal(fleeSpot)

        -- Check if we've regained invisibility (damage was long enough ago)
        if not HiddenHunt.IsPartiallyVisible(bot) then
            bot.hiddenPhase = "hunt"
            bot.hiddenFleeSpot = nil
            return STATUS.RUNNING
        end

        local elapsed = CurTime() - (bot.hiddenFleeStart or CurTime())
        if elapsed > HiddenHunt.FLEE_TIME then
            bot.hiddenPhase = "hunt"
            bot.hiddenFleeSpot = nil
            return STATUS.RUNNING
        end

        local distToFlee = bot:GetPos():Distance(fleeSpot)
        if distToFlee < 100 then
            -- Reached flee spot, just wait for invisibility to return
            loco:SetGoal()
            return STATUS.RUNNING
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- Check if we should flee (damaged, partially visible)
    ---------------------------------------------------------------------------
    if HiddenHunt.IsPartiallyVisible(bot) and phase ~= "flee" then
        bot.hiddenPhase = "flee"
        bot.hiddenFleeStart = CurTime()
        loco:StopAttack()
        bot.hiddenFleeSpot = HiddenHunt.FindFleeSpot(bot, bot:GetPos())
        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- TARGET VALIDATION
    ---------------------------------------------------------------------------
    local target = bot.hiddenTarget
    local needRetarget = not (target and IsValid(target) and lib.IsPlayerAlive(target))

    -- Also retarget periodically
    if not needRetarget and CurTime() - (bot.hiddenLastRetarget or 0) > HiddenHunt.RETARGET_INTERVAL then
        needRetarget = true
    end

    if needRetarget then
        local newTarget = lib.FindIsolatedTarget(bot)
        if not (newTarget and IsValid(newTarget) and lib.IsPlayerAlive(newTarget)) then
            -- No targets, just wander
            return STATUS.FAILURE
        end
        bot.hiddenTarget = newTarget
        bot.hiddenLastRetarget = CurTime()
        target = newTarget
    end

    local botPos = bot:GetPos()
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()
    local dist = botPos:Distance(targetPos)
    local canSee = bot:Visible(target)

    ---------------------------------------------------------------------------
    -- PHASE: HUNT — approach the target while invisible
    ---------------------------------------------------------------------------
    if phase == "hunt" then
        -- Equip the knife
        local knife = HiddenHunt.GetHiddenKnife(bot)
        if knife and IsValid(knife) then
            local activeWep = bot:GetActiveWeapon()
            if not (IsValid(activeWep) and activeWep == knife) then
                pcall(bot.SelectWeapon, bot, knife:GetClass())
            end
        end

        if not canSee then
            -- Track target via memory
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

        -- Move toward the target
        loco:SetGoal(targetPos)

        -- Throw stun grenade if multiple enemies are close together
        if dist < 500 and dist > 200 then
            local nearbyEnemies = 0
            local nonAllies = TTTBots.Roles.GetNonAllies(bot)
            for _, other in ipairs(nonAllies) do
                if IsValid(other) and lib.IsPlayerAlive(other) and other:GetPos():Distance(targetPos) < 300 then
                    nearbyEnemies = nearbyEnemies + 1
                end
            end
            -- Throw stun grenade at groups of 2+
            if nearbyEnemies >= 2 and not bot.hiddenThrewGrenade then
                local nade = HiddenHunt.GetHiddenGrenade(bot)
                if nade and IsValid(nade) then
                    pcall(bot.SelectWeapon, bot, nade:GetClass())
                    loco:LookAt(targetEyes)
                    loco:StartAttack()
                    bot.hiddenThrewGrenade = CurTime()
                    -- Switch back to knife next tick
                    timer.Simple(0.5, function()
                        if IsValid(bot) then
                            local k = HiddenHunt.GetHiddenKnife(bot)
                            if k and IsValid(k) then
                                pcall(bot.SelectWeapon, bot, k:GetClass())
                            end
                        end
                    end)
                    return STATUS.RUNNING
                end
            end
        end

        -- Reset grenade cooldown after the restock delay
        if bot.hiddenThrewGrenade and CurTime() - bot.hiddenThrewGrenade > 35 then
            bot.hiddenThrewGrenade = nil
        end

        -- Close enough to strike
        if canSee and dist <= HiddenHunt.STRIKE_RANGE then
            bot.hiddenPhase = "strike"
            return STATUS.RUNNING
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE: STRIKE — attack with the knife
    ---------------------------------------------------------------------------
    if phase == "strike" then
        if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
            -- Target died, go back to hunting
            bot.hiddenPhase = "hunt"
            bot.hiddenTarget = nil
            loco:StopAttack()
            return STATUS.RUNNING
        end

        -- Make sure knife is equipped
        local knife = HiddenHunt.GetHiddenKnife(bot)
        if knife and IsValid(knife) then
            local activeWep = bot:GetActiveWeapon()
            if not (IsValid(activeWep) and activeWep == knife) then
                pcall(bot.SelectWeapon, bot, knife:GetClass())
            end
        end

        -- Close in and attack
        loco:LookAt(targetEyes)
        if dist > 70 then
            loco:SetGoal(targetPos)
        else
            loco:SetGoal()
        end
        loco:StartAttack()

        -- If target gets far away, go back to hunt phase
        if dist > HiddenHunt.STRIKE_RANGE * 2 then
            bot.hiddenPhase = "hunt"
            loco:StopAttack()
        end

        return STATUS.RUNNING
    end

    return STATUS.FAILURE
end

---@param bot Bot
function HiddenHunt.OnSuccess(bot)
end

---@param bot Bot
function HiddenHunt.OnFailure(bot)
end

---@param bot Bot
function HiddenHunt.OnEnd(bot)
    bot.hiddenTarget = nil
    bot.hiddenPhase = nil
    bot.hiddenFleeStart = nil
    bot.hiddenFleeSpot = nil
    bot.hiddenThrewGrenade = nil
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

---------------------------------------------------------------------------
-- Damage tracking: detect when the Hidden takes damage → flee
---------------------------------------------------------------------------
hook.Add("PlayerHurt", "TTTBots.Behavior.HiddenHunt.DamageTrack", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer() and victim:IsBot()) then return end
    if not TTTBots.Match.IsRoundActive() then return end
    if not ROLE_HIDDEN then return end
    if not (victim.GetSubRole and victim:GetSubRole() == ROLE_HIDDEN) then return end

    -- Record damage time so IsPartiallyVisible() triggers flee
    victim.hiddenLastDamageTime = CurTime()
end)

---------------------------------------------------------------------------
-- Kill tracking: when Hidden kills someone, immediately find next target
---------------------------------------------------------------------------
hook.Add("PlayerDeath", "TTTBots.Behavior.HiddenHunt.KillTrack", function(victim, weapon, attacker)
    if not (IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot()) then return end
    if not TTTBots.Match.IsRoundActive() then return end
    if not ROLE_HIDDEN then return end
    if not (attacker.GetSubRole and attacker:GetSubRole() == ROLE_HIDDEN) then return end

    -- Clear the target so we immediately look for a new one
    if attacker.hiddenTarget == victim then
        attacker.hiddenTarget = nil
        attacker.hiddenLastRetarget = 0
    end
end)
