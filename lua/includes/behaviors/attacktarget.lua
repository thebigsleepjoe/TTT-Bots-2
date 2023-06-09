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
Attack.Interruptible = false

---@enum STATUS
local STATUS = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

---@enum ATTACKMODE
local ATTACKMODE = {
    Seeking = 2,  -- We have a target and we saw them recently or can see them but not shoot them
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Validate the behavior
function Attack:Validate(bot)
    return self:ValidateTarget(bot)
end

--- Called when the behavior is started
function Attack:OnStart(bot)
    bot.lastSeek = true -- set this to true here for the first tick, despite the nam being misleading
    return STATUS.Running
end

function Attack:Seek(bot, targetPos)
    local target = bot.attackTarget
    local loco = bot.components.locomotor
    bot.components.locomotor.stopLookingAround = false
    -- If we can't see them, we need to move to them
    local targetPos = target:GetPos()
    loco:SetGoalPos(targetPos)
    bot.lastSeek = true --- Used to one-time stop loco when we start engaging
end

function Attack:Engage(bot, targetPos)
    local target = bot.attackTarget
    bot.components.locomotor.stopLookingAround = true
    ---@class CLocomotor
    local loco = bot.components.locomotor
    if bot.lastSeek then
        loco:Stop()
        bot:Say("Stopping aiming to look at target")
        bot.lastSeek = false
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

    loco:AimAt(targetPos)
end

--- Determine what mode of attack (attackMode) we are in.
---@param bot Player
---@return ATTACKMODE mode
function Attack:RunningAttackLogic(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local target = bot.attackTarget
    local targetPos, canSee = memory:GetCurrentPosOf(target)
    local mode = ATTACKMODE.Seeking               -- Default to seeking

    if canSee then mode = ATTACKMODE.Engaging end -- We can see them, we are engaging

    local switchcase = {
        [ATTACKMODE.Seeking] = self.Seek,
        [ATTACKMODE.Engaging] = self.Engage,
    }
    switchcase[mode](self, bot, targetPos) -- Call the function
    return mode
end

--- Validates if the target is extant and alive. True if valid.
---@param bot Player
---@return boolean isValid
function Attack:ValidateTarget(bot)
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
function Attack:OnRunning(bot)
    local target = bot.attackTarget
    -- We could probably do self:Validate but this is more explicit:
    if not self:ValidateTarget(bot) then return STATUS.Failure end -- Target is not valid

    local isNPC = target:IsNPC()
    local isPlayer = target:IsPlayer()
    if not isNPC and not isPlayer then
        ErrorNoHalt("Wtf has bot.attackTarget been assigned to? Not NPC nor player... target: " ..
            tostring(bot.attackTarget))
    end -- Target is not a player or NPC

    local attack = self:RunningAttackLogic(bot)
    bot.attackBehaviorMode = attack

    return STATUS.Running
end

--- Called when the behavior returns a success state
function Attack:OnSuccess(bot)
    bot.attackTarget = nil
    bot:Say("Killed that fool!")
end

--- Called when the behavior returns a failure state
function Attack:OnFailure(bot)
    bot.attackTarget = nil
    bot:Say("Lost that fool!")
end

--- Called when the behavior ends
function Attack:OnEnd(bot)
    bot.attackTarget = nil
    bot.components.locomotor.stopLookingAround = false
end
