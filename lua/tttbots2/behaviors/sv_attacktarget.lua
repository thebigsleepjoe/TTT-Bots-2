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
    local loco = lib.GetComp(bot, "locomotor")
    if not loco then return end
    bot.components.locomotor.stopLookingAround = false
    loco:StopAttack()
    -- If we can't see them, we need to move to them
    -- local targetPos = target:GetPos()
    --loco:SetGoal(targetPos)

    ---@type CMemory
    local memory = bot.components.memory
    local lastKnownPos = memory:GetSuspectedPositionFor(target) or memory:GetKnownPositionFor(target)

    if lastKnownPos then
        loco:SetGoal(lastKnownPos)
        loco:LookAt(lastKnownPos)
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
    return weapon.is_shotgun or weapon.is_melee
end

--- Tells loco to strafe
---@param weapon WeaponInfo
---@param loco CLocomotor
function Attack.StrafeIfNecessary(bot, weapon, loco)
    if not (bot.attackTarget and bot.attackTarget.GetPos) then return false end

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

function Attack.Engage(bot, targetPos)
    local target = bot.attackTarget
    ---@class CInventory
    local inv = bot.components.inventory
    ---@type WeaponInfo
    local weapon = inv:GetHeldWeaponInfo()
    if not weapon then return end
    local usingMelee = not weapon.is_gun
    ---@class CLocomotor
    local loco = bot.components.locomotor
    loco.stopLookingAround = true

    local preventAttackBecauseMelee = false --- Used to prevent attacking when we are using a melee weapon and are too far away
    if bot.wasPathing and not usingMelee then
        loco:Stop()
        bot.wasPathing = false
    elseif usingMelee then
        local distToTarget = bot:GetPos():Distance(target:GetPos())
        preventAttackBecauseMelee = distToTarget > 160
        if distToTarget < 70 then
            loco:Stop()
            bot.wasPathing = false
        else
            loco:SetGoal(targetPos)
            bot.wasPathing = true
        end
    end

    if not preventAttackBecauseMelee then
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

    local aimTarget
    if Attack.ShouldLookAtBody(bot, weapon) then
        aimTarget = Attack.GetTargetBodyPos(target)
    else
        aimTarget = Attack.GetTargetHeadPos(target)
    end

    if not usingMelee then
        local barrel = Attack.TargetNextToBarrel(bot, target)
        if barrel
            and target:VisibleVec(barrel:GetPos())
            and bot:VisibleVec(barrel:GetPos())
        then
            aimTarget = barrel:GetPos() + barrel:OBBCenter()
        end
    end

    Attack.HandleAttackMovement(bot, weapon, loco)

    local predictedPoint = aimTarget + Attack.PredictMovement(target, 0.4)
    local inaccuracyTarget = predictedPoint + Attack.CalculateInaccuracy(bot, aimTarget)
    loco:LookAt(inaccuracyTarget)
end

local INACCURACY_BASE = 7 --- The higher this is, the more inaccurate the bots will be.
--- Calculate the inaccuracy of agent 'bot' according to a) its personality and b) diff setts
---@param bot Player The bot that is shooting.
---@param origin Vector The original aim point.
function Attack.CalculateInaccuracy(bot, origin)
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    local difficulty = lib.GetConVarInt("difficulty") -- int [0,5]
    if not (difficulty or personality) then return Vector(0, 0, 0) end

    local distFactor = (bot:GetPos():Distance(origin) / 16) ^ 1.5
    local pressure = personality:GetPressure()     -- float [0,1]
    local rage = (personality:GetRage() * 2) + 1   -- float [1,3]

    local inaccuracy_mod = (pressure / difficulty) -- The more pressure we have, the more inaccurate we are; decreased by difficulty
        * distFactor                               -- The further away we are, the more inaccurate we are
        * INACCURACY_BASE                          -- Obviously, multiply by a constant to make it more inaccurate
        * rage                                     -- The more rage we have, the more inaccurate we are
    inaccuracy_mod = math.min(math.max(inaccuracy_mod, 0.1), 6)

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
    if not ent then return false end                             -- We are not looking at anything important, we can shoot
    if ent == target then return false end                       -- We are looking at our target, we can shoot
    if IsValid(ent) and not ent:IsPlayer() then return false end -- We are looking at something that is not a player, we can shoot
    local sameTeam = lib.IsEvil(bot) == lib.IsEvil(ent)
    if not sameTeam then return false end                        -- We are not looking at a teammate, we can shoot
    return true                                                  -- We are looking at a teammate, we cannot shoot
end

function Attack.LookingCloseToTarget(bot, target)
    local targetPos = target:GetPos()
    ---@type CLocomotor
    local locomotor = bot.components.locomotor
    local degDiff = math.abs(locomotor:GetEyeAngleDiffTo(targetPos))

    local THRESHOLD = 10
    local isLookingClose = degDiff < THRESHOLD

    return isLookingClose
end

--- Determine what mode of attack (attackMode) we are in.
---@param bot Player
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

    local hasTarget = target and true or false
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

--- Called when the behavior's last state is running
---@param bot Player
---@return STATUS status
function Attack.OnRunning(bot)
    local target = bot.attackTarget
    -- We could probably do Attack.Validate but this is more explicit:
    if not Attack.ValidateTarget(bot) then return STATUS.FAILURE end -- Target is not valid
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
    bot:Say("Killed that fool!")
end

--- Called when the behavior returns a failure state
function Attack.OnFailure(bot)
    bot:Say("Lost that fool!")
end

--- Called when the behavior ends
function Attack.OnEnd(bot)
    bot:SetAttackTarget(nil)
    bot.components.locomotor.stopLookingAround = false
    bot.components.locomotor:StopAttack()
end
