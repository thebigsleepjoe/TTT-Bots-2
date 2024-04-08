TTTBots.Behaviors = TTTBots.Behaviors or {}
--[[
This behavior is not responsible for finding a target. It is responsible for attacking a target.

**It will only stop itself once the target is dead or nil. It must not be interrupted by another behavior.**
]]
---@class BAttack
TTTBots.Behaviors.AttackTarget = {}

local lib = TTTBots.Lib

---@class BAttack
local Attack = TTTBots.Behaviors.AttackTarget
Attack.Name = "AttackTarget"
Attack.Description = "Attacking target"
Attack.Interruptible = true

---@enum STATUS
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

---@enum ATTACKMODE
local ATTACKMODE = {
    Seeking = 2,  -- We have a target and we saw them recently or can see them but not shoot them
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Validate the behavior
function Attack.Validate(bot)
    return Attack.ValidateTarget(bot)
end

--- Called when the behavior is started
function Attack.OnStart(bot)
    bot.wasPathing = true -- set this to true here for the first tick, despite the nam being misleading
    return STATUS.RUNNING
end

function Attack.Seek(bot, targetPos)
    local target = bot.attackTarget
    local loco = bot:BotLocomotor() ---@type CLocomotor
    local inv = bot:BotInventory() ---@type CInventory
    if not (loco and inv) then return end
    bot:BotLocomotor().stopLookingAround = false
    loco:StopAttack()
    inv:ReloadIfNecessary()

    ---@type CMemory
    local memory = bot.components.memory
    local lastKnownPos = memory:GetSuspectedPositionFor(target) or memory:GetKnownPositionFor(target)

    if lastKnownPos then
        loco:SetGoal(lastKnownPos)
        loco:LookAt(lastKnownPos + Vector(0, 0, 40)) -- around hip/abdomen level
    else
        -- We have not heard nor seen the target in a while, so we will wander around.
        lib.CallEveryNTicks(
            bot,
            function()
                local wanderArea = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
                if not IsValid(wanderArea) then return end
                loco:SetGoal(wanderArea:GetCenter())
            end,
            math.ceil(TTTBots.Tickrate * 5)
        )
    end

    bot.wasPathing = true --- Used to one-time stop loco when we start engaging
end

function Attack.GetTargetHeadPos(targetPly)
    local fallback = targetPly:EyePos()

    local head_bone_index = targetPly:LookupBone("ValveBiped.Bip01_Head1")
    if not head_bone_index then
        print("Returning fallback; no bone index for target.")
        return fallback
    end

    local head_pos, head_ang = targetPly:GetBonePosition(head_bone_index)

    if head_pos then
        return head_pos
    else
        print("Returning fallback, couldn't retrieve head_pos from bone index " .. head_bone_index)
        return fallback
    end
end

function Attack.GetTargetBodyPos(targetPly)
    local fallback = targetPly:GetPos() + Vector(0, 0, 30)

    local spine_bone_index = targetPly:LookupBone("ValveBiped.Bip01_Spine2")
    if not spine_bone_index then
        print("Returning fallback; no bone index for target.")
        return fallback
    end

    local spine_pos, spine_ang = targetPly:GetBonePosition(spine_bone_index)

    if spine_pos then
        return spine_pos
    else
        print("Returning fallback, couldn't retrieve spine_pos from bone index " .. spine_bone_index)
        return fallback
    end
end

function Attack.ShouldLookAtBody(bot, weapon)
    local personality = bot:BotPersonality() ---@type CPersonality
    local isBodyShotter = not (personality.isHeadshotter or false)
    return isBodyShotter or (weapon.is_shotgun or weapon.is_melee)
end

--- Tells loco to strafe
---@param weapon WeaponInfo
---@param loco CLocomotor
function Attack.StrafeIfNecessary(bot, weapon, loco)
    if bot.canStrafe == false then return false end
    if not (bot.attackTarget and bot.attackTarget.GetPos) then return false end
    if weapon.is_melee then return false end

    -- Do not strafe if we are on a cliff. We will fall off.
    local isCliffed = loco:IsCliffed()
    if isCliffed then return false end

    local distToTarget = bot:GetPos():Distance(bot.attackTarget:GetPos())
    local shouldStrafe = (
        distToTarget > 200
    -- and
    )

    if not shouldStrafe then return false end

    local strafeDir = math.random(0, 1) == 0 and "left" or "right"
    loco:Strafe(strafeDir)

    return true -- We are strafing
end

local IDEAL_APPROACH_DIST = 200

function Attack.ShouldApproachWith(bot, weapon)
    return weapon.is_shotgun or weapon.is_melee
end

--- Tests if the target is next to an explosive barrel, if so, returns the barrel.
---@param bot Player
---@param target Player
---@return Entity|nil barrel
function Attack.TargetNextToBarrel(bot, target)
    local lastBarrelTime = target.lastBarrelCheck or 0
    local targetBarrel = target.lastBarrel or nil
    local TIME_BETWEEN_BARREL_CHECKS = 3 -- 3 seconds

    if lastBarrelTime + TIME_BETWEEN_BARREL_CHECKS > CurTime() then return targetBarrel end

    local barrel = lib.GetClosestBarrel(target)
    target.lastBarrel = barrel
    return barrel
end

function Attack.ApproachIfNecessary(bot, weapon, loco)
    if not (bot.attackTarget and bot.attackTarget.GetPos) then return false end
    if not Attack.ShouldApproachWith(bot, weapon) then return false end

    local distToTarget = bot:GetPos():Distance(bot.attackTarget:GetPos())
    local shouldApproach = (
        distToTarget > IDEAL_APPROACH_DIST
    )
    local forceStop = (
        distToTarget < IDEAL_APPROACH_DIST
    )
    if forceStop then
        loco:SetForceForward(false)
        return false
    end -- Stop forcing forward if we are close enough
    if not shouldApproach then return false end

    loco:SetForceForward(true)

    return true -- We are approaching
end

--- Handles strafing, moving towards/away from our target, etc.
---@param weapon WeaponInfo
---@param loco CLocomotor
function Attack.HandleAttackMovement(bot, weapon, loco)
    Attack.StrafeIfNecessary(bot, weapon, loco)
    Attack.ApproachIfNecessary(bot, weapon, loco)
end

function Attack.GetPreferredBodyTarget(bot, wep, target)
    local body, head = Attack.GetTargetBodyPos(target), Attack.GetTargetHeadPos(target)
    if Attack.ShouldLookAtBody(bot, wep) then
        return body
    end

    return head
end

function Attack.Engage(bot, targetPos)
    local target = bot.attackTarget
    local inv = bot.components.inventory ---@type CInventory
    local weapon = inv:GetHeldWeaponInfo() ---@type WeaponInfo
    if not weapon then return end
    local usingMelee = not weapon.is_gun
    local loco = bot:BotLocomotor() ---@type CLocomotor
    loco.stopLookingAround = true

    local tooFarToAttack = false --- Used to prevent attacking when we are using a melee weapon and are too far away
    local distToTarget = bot:GetPos():Distance(target:GetPos())
    if bot.wasPathing and not usingMelee then
        loco:StopMoving()
        bot.wasPathing = false
    elseif usingMelee then
        tooFarToAttack = distToTarget > 160
        if distToTarget < 70 then
            loco:StopMoving()
            bot.wasPathing = false
        else
            loco:SetGoal(targetPos)
            bot.wasPathing = true
        end
    end

    -- Backpedal away if there is a bad guy near us.
    if not usingMelee and distToTarget < 100 then
        loco:SetForceBackward(true)
    else
        loco:SetForceBackward(false)
    end

    if not tooFarToAttack then
        if (Attack.LookingCloseToTarget(bot, target)) then
            if not Attack.WillShootingTeamkill(bot, target) then -- make sure we aren't about to teamkill by mistake!!
                loco:StartAttack()
            end

            -- lib.CallEveryNTicks(
            --     bot,
            --     function()
            --         loco:SetRandomStrafe()
            --     end,
            --     math.ceil(TTTBots.Tickrate * 1)
            -- )
        end
    else
        loco:StopAttack()
        loco:Strafe()
    end

    local dvlpr = lib.GetDebugFor("attack")
    if dvlpr then
        TTTBots.DebugServer.DrawLineBetween(
            bot:EyePos(),
            targetPos,
            Color(255, 0, 0),
            0.1,
            bot:Nick() .. ".attack"
        )
    end

    local aimPoint = Attack.GetPreferredBodyTarget(bot, weapon, target)

    if not usingMelee then
        local barrel = Attack.TargetNextToBarrel(bot, target)
        if barrel
            and target:VisibleVec(barrel:GetPos())
            and bot:VisibleVec(barrel:GetPos())
        then
            aimPoint = barrel:GetPos() + barrel:OBBCenter()
        end
    end

    Attack.HandleAttackMovement(bot, weapon, loco)

    local predictedPoint = aimPoint + Attack.PredictMovement(target, 0.4)
    local inaccuracyTarget = predictedPoint + Attack.CalculateInaccuracy(bot, aimPoint, target)
    loco:LookAt(inaccuracyTarget)
end

local INACCURACY_BASE = 9  --- The higher this is, the more inaccurate the bots will be.
local INACCURACY_SMOKE = 5 --- The inaccuracy modifier when the bot or its target is in smoke.
--- Calculate the inaccuracy of agent 'bot' according to a) its personality and b) diff setts
---@param bot Player The bot that is shooting.
---@param origin Vector The original aim point.
---@param target Player The target that is being shot at.
function Attack.CalculateInaccuracy(bot, origin, target)
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    local difficulty = lib.GetConVarInt("difficulty") -- int [0,5]
    if not (difficulty or personality) then return Vector(0, 0, 0) end

    local dist = bot:GetPos():Distance(origin)
    local distFactor = math.max((dist / 64) ^ 1.5, 0.5)
    local pressure = personality:GetPressure()   -- float [0,1]
    local rage = (personality:GetRage() * 2) + 1 -- float [1,3]

    local isTraitorFactor =
        (bot:GetRoleStringRaw() == "traitor" and lib.GetConVarBool("cheat_traitor_accuracy"))
        and 0.5 or 1

    local focus_factor = (1 - (bot.attackFocus or 0.01)) * 1.5

    local targetMoveFactor = 1
    local selfMoveFactor = bot:GetVelocity():LengthSqr() > 100 and 1.25 or 0.75
    if not (IsValid(target) and target:IsPlayer()) then
        targetMoveFactor = 0.5
    else
        local vel = target:GetVelocity():LengthSqr()
        targetMoveFactor = vel > 100 and 1.0 or 0.5
    end

    local smokeFn = TTTBots.Match.IsPlyNearSmoke
    local isInSmoke = (smokeFn(bot) or smokeFn(bot.attackTarget)) and INACCURACY_SMOKE or 1

    local inaccuracy_mod = (pressure / difficulty) -- The more pressure we have, the more inaccurate we are; decreased by difficulty
        * distFactor                               -- The further away we are, the more inaccurate we are
        * INACCURACY_BASE                          -- Obviously, multiply by a constant to make it more inaccurate
        * rage                                     -- The more rage we have, the more inaccurate we are
        * focus_factor                             -- The less focus we have, the more inaccurate we are
        * isInSmoke                                -- If we are in smoke, we are more inaccurate
        * isTraitorFactor                          -- Reduce aim difficulty if the cheat cvar is enabled
        * targetMoveFactor                         -- Reduce aim difficulty if the target is immobile

    inaccuracy_mod = math.max(inaccuracy_mod, 0.1)

    local rand = VectorRand() * inaccuracy_mod
    -- TTTBots.DebugServer.DrawCross(origin + rand, 8, Color(0, 255, 0), 0.1, bot:Nick() .. ".attack.inaccuracy")
    return rand
end

---Predict the (relative) movement of the target player using basic linear prediction
---@param target Player
---@return Vector predictedMovement
function Attack.PredictMovement(target, mult)
    local vel = target:GetVelocity()
    local predictionSecs = 1.0 / TTTBots.Tickrate
    local predictionMultSalt = math.random(95, 105) / 100.0
    local predictionMult = (1 + predictionMultSalt) * (mult or 0.5)
    local predictionRelative = (vel * predictionSecs * predictionMult)

    local dvlpr = lib.GetDebugFor("attack")
    if dvlpr then
        -- Draw a cross at the predicted position
        TTTBots.DebugServer.DrawCross(target:GetPos() + predictionRelative, 8, Color(255, 0, 0), predictionSecs,
            target:Nick() .. ".attack.prediction")
    end

    return predictionRelative
end

--- Returns true if shooting now would result in possibly shooting someone who isn't our target.
function Attack.WillShootingTeamkill(bot, target)
    -- Get the eye trace of our bot.
    local eyeTrace = bot:GetEyeTrace()
    local ent = eyeTrace.Entity
    if not ent then return false end                                 -- We are not looking at anything important, we can shoot
    if ent == target then return false end                           -- We are looking at our target, we can shoot
    if IsValid(ent) and not ent:IsPlayer() then return false end     -- We are looking at something that is not a player, we can shoot
    if not TTTBots.Roles.IsAllies(bot, target) then return false end -- We are not looking at a teammate, we can shoot
    return true                                                      -- We are looking at a teammate, we cannot shoot
end

function Attack.LookingCloseToTarget(bot, target)
    local targetPos = target:GetPos()
    ---@type CLocomotor
    local locomotor = bot:BotLocomotor()
    local degDiff = math.abs(locomotor:GetEyeAngleDiffTo(targetPos))

    local THRESHOLD = 10
    local isLookingClose = degDiff < THRESHOLD

    return isLookingClose
end

--- Determine what mode of attack (attackMode) we are in.
---@param bot Bot
---@return ATTACKMODE mode
function Attack.RunningAttackLogic(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local target = bot.attackTarget
    local targetPos, canSee = memory:GetCurrentPosOf(target)
    local mode = ATTACKMODE.Seeking -- Default to seeking
    local canShoot = lib.CanShoot(bot, target)

    if canShoot then mode = ATTACKMODE.Engaging end -- We can shoot them, we are engaging

    local switchcase = {
        [ATTACKMODE.Seeking] = Attack.Seek,
        [ATTACKMODE.Engaging] = Attack.Engage,
    }
    switchcase[mode](bot, targetPos) -- Call the function
    return mode
end

--- Validates if the target is extant and alive. True if valid.
---@param bot Player
---@return boolean isValid
function Attack.ValidateTarget(bot)
    local target = bot.attackTarget

    local hasTarget = (target and target ~= NULL) and true or false
    if target == NULL or not IsValid(target) then return false end
    local targetIsValid = target and target:IsValid() or false
    local targetIsAlive = target and target:Alive() or false
    local targetIsPlayer = target and target:IsPlayer() or false
    local targetIsNPC = target and target:IsNPC() or false
    local targetIsPlayerAndAlive = targetIsPlayer and TTTBots.Lib.IsPlayerAlive(target) or false
    local targetIsNPCAndAlive = targetIsNPC and target:Health() > 0 or false
    local targetIsPlayerOrNPCAndAlive = targetIsPlayerAndAlive or targetIsNPCAndAlive or false

    -- print(bot:Nick() .. " validating attack target behavior:")
    -- print("| hasTarget: " .. tostring(hasTarget))
    -- print("| targetIsValid: " .. tostring(targetIsValid))
    -- print("| targetIsAlive: " .. tostring(targetIsAlive))
    -- print("| targetIsPlayer: " .. tostring(targetIsPlayer))
    -- print("| targetIsNPC: " .. tostring(targetIsNPC))
    -- print("| targetIsPlayerAndAlive: " .. tostring(targetIsPlayerAndAlive))
    -- print("| targetIsNPCAndAlive: " .. tostring(targetIsNPCAndAlive))
    -- print("| targetIsPlayerOrNPCAndAlive: " .. tostring(targetIsPlayerOrNPCAndAlive))
    -- print("------------------")

    return (
        hasTarget
        and targetIsValid
        and targetIsAlive
        and targetIsPlayerOrNPCAndAlive
    )
end

function Attack.IsTargetAlly(bot)
    if not (IsValid(bot.attackTarget) and bot.attackTarget:IsPlayer()) then return false end
    return TTTBots.Roles.IsAllies(bot, bot.attackTarget)
end

--- Called when the behavior's last state is running
---@param bot Player
---@return STATUS status
function Attack.OnRunning(bot)
    local target = bot.attackTarget
    -- We could probably do Attack.Validate but this is more explicit:
    if not Attack.ValidateTarget(bot) then return STATUS.FAILURE end -- Target is not valid
    if Attack.IsTargetAlly(bot) then return STATUS.FAILURE end       -- Target is an ally. No attack!
    if target == bot then
        bot:SetAttackTarget(nil)
        return STATUS.FAILURE
    end

    local isNPC = target:IsNPC()
    local isPlayer = target:IsPlayer()
    if not isNPC and not isPlayer then
        ErrorNoHaltWithStack("Wtf has bot.attackTarget been assigned to? Not NPC nor player... target: " ..
            tostring(bot.attackTarget))
    end -- Target is not a player or NPC

    local attack = Attack.RunningAttackLogic(bot)
    bot.attackBehaviorMode = attack

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function Attack.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Attack.OnFailure(bot)
end

--- Called when the behavior ends
function Attack.OnEnd(bot)
    bot:SetAttackTarget(nil)
    bot:BotLocomotor().stopLookingAround = false
    bot:BotLocomotor():StopAttack()
end

local FOCUS_DECAY = 0.02
function Attack.UpdateFocus(bot)
    local factor = -FOCUS_DECAY
    factor = factor * (bot.attackTarget ~= nil and -2.5 or 1)
    factor = factor * (bot:GetTraitMult("focus") or 1)
    bot.attackFocus = (bot.attackFocus or 0.1) + factor
    bot.attackFocus = math.Clamp(bot.attackFocus, 0.1, 1)
end

timer.Create("TTTBots_AttackFocus", 1 / TTTBots.Tickrate, 0, function()
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        Attack.UpdateFocus(bot)
    end
end)
