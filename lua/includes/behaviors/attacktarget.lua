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
    Seeking = 2,  -- We have a target and we know where they are, but we are not in range
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Validate the behavior
function Attack:Validate(bot)
    local target = bot.attackTarget
    return (
        target
        and target:IsValid()
        and target:Alive()
        and (target:IsPlayer() and TTTBots.Lib.IsPlayerAlive(target)) -- IsPlayerAlive doesn't include spectators
        or (target:IsNPC() and target:Health() > 0)
        )
end

--- Called when the behavior is started
function Attack:OnStart(bot)
    return self.Running
end

--- Called when the behavior's last state is running
function Attack:OnRunning(bot)
    local bot = self.bot
    local target = bot.target
    -- We could probably do self:Validate but this is more explicit:
    if not target or not target:IsValid() then return self.Failure end                          -- Target is invalid
    if not target:Alive() then return self.Success end                                          -- We probably killed them
    if target:IsPlayer() and not TTTBots.Lib.IsPlayerAlive(target) then return self.Success end -- We probably killed them

    local isNPC = target:IsNPC()
    local isPlayer = target:IsPlayer()
    if not isNPC and not isPlayer then ErrorNoHalt("Wtf has bot.target been assigned to? " .. tostring(bot.target)) end -- Target is not a player or NPC

    bot:Say("Attacking target")
end

--- Called when the behavior returns a success state
function Attack:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Attack:OnFailure(bot)
end

--- Called when the behavior ends
function Attack:OnEnd(bot)
end
