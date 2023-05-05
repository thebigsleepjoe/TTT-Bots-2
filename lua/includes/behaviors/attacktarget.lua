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

local status = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

local attackModes = {
    Hunting = 1,  -- We have a target but we do not know where they are
    Seeking = 2,  -- We have a target and we saw them recently or can see them but not shoot them
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Validate the behavior
function Attack:Validate(bot)
    local target = bot.attackTarget

    local hasTarget = target and true or false
    local targetIsValid = target and target:IsValid() or false
    local targetIsAlive = target and target:Alive() or false
    local targetIsPlayer = target and target:IsPlayer() or false
    local targetIsNPC = target and target:IsNPC() or false
    local targetIsPlayerAndAlive = targetIsPlayer and TTTBots.Lib.IsPlayerAlive(target) or false
    local targetIsNPCAndAlive = targetIsNPC and target:Health() > 0 or false
    local targetIsPlayerOrNPCAndAlive = targetIsPlayerAndAlive or targetIsNPCAndAlive or false

    local _dbg = false
    if _dbg then
        print(bot:Nick() .. " validating attack target behavior:")
        print("| hasTarget: " .. tostring(hasTarget))
        print("| targetIsValid: " .. tostring(targetIsValid))
        print("| targetIsAlive: " .. tostring(targetIsAlive))
        print("| targetIsPlayer: " .. tostring(targetIsPlayer))
        print("| targetIsNPC: " .. tostring(targetIsNPC))
        print("| targetIsPlayerAndAlive: " .. tostring(targetIsPlayerAndAlive))
        print("| targetIsNPCAndAlive: " .. tostring(targetIsNPCAndAlive))
        print("| targetIsPlayerOrNPCAndAlive: " .. tostring(targetIsPlayerOrNPCAndAlive))
        print("------------------")
    end

    return (
        hasTarget
        and targetIsValid
        and targetIsAlive
        and targetIsPlayerOrNPCAndAlive
    )
end

--- Called when the behavior is started
function Attack:OnStart(bot)
    return status.Running
end

function Attack:RunningAttackLogic()
    local memory = self.bot.components.memory
end

--- Called when the behavior's last state is running
function Attack:OnRunning(bot)
    local target = bot.attackTarget
    -- We could probably do self:Validate but this is more explicit:
    if not target or not target:IsValid() then return status.Failure end                          -- Target is invalid
    if not target:Alive() then return status.Success end                                          -- We probably killed them
    if target:IsPlayer() and not TTTBots.Lib.IsPlayerAlive(target) then return status.Success end -- We probably killed them

    local isNPC = target:IsNPC()
    local isPlayer = target:IsPlayer()
    if not isNPC and not isPlayer then
        ErrorNoHalt("Wtf has bot.attackTarget been assigned to? Not NPC nor player... target: " ..
            tostring(bot.attackTarget))
    end -- Target is not a player or NPC

    self:RunningAttackLogic()

    return status.Running
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
