TTTBots.Behaviors = TTTBots.Behaviors or {}
--[[
This behavior is not responsible for finding a target. It is responsible for attacking a target.

**It will only stop itself once the target is dead or nil. It cannot be interrupted by another behavior.**
]]
TTTBots.Behaviors.AttackTarget = {}

local lib = TTTBots.Lib

local Attack = TTTBots.Behaviors.AttackTarget
Attack.Name = "AttackTarget"
Attack.Description = "Attacking target"
Attack.Interruptible = false

local STATUS = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

---@enum ATTACKMODE
local ATTACKMODE = {
    Hunting = 1,  -- We have a target but we do not know where they are
    Seeking = 2,  -- We have a target and we saw them recently or can see them but not shoot them
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Validate the behavior
function Attack:Validate(bot)
    return self:ValidateTarget(bot)
end

--- Called when the behavior is started
function Attack:OnStart(bot)
    return STATUS.Running
end

--- Determine what mode of attack (attackMode) we are in.
---@param bot Player
---@return ATTACKMODE mode
function Attack:RunningAttackLogic(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local target = bot.attackTarget
    local targetPos = memory:GetCurrentPosOf(target)

    if not targetPos then return ATTACKMODE.Hunting end -- We don't know where they are

    -- TODO
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

    local isEvil = lib.IsEvil(bot)

    if attack == ATTACKMODE.Hunting and not isEvil then return STATUS.Failure end -- We are innocent and we lost our target

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
end
