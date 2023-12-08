--- This behavior sucks and it deserves to be rewritten, integrated with the loco, and/or removed entirely.
--- But I'm not going to do that right now. Too bad!
---@class BBreaker
TTTBots.Behaviors.ClearBreakables = {}

local lib = TTTBots.Lib

---@class BBreaker
local Breaker = TTTBots.Behaviors.ClearBreakables
Breaker.Name = "ClearBreakables"
Breaker.Description = "Clear breakables near to the player"
Breaker.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function Breaker.Validate(bot)
    local startPos = bot:EyePos()
    local endPos = startPos + (bot:GetAimVector() * 64)
    local traceResult = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = bot,
    })

    return traceResult.Hit and IsValid(traceResult.Entity) and
        table.HasValue(TTTBots.Components.ObstacleTracker.Breakables, traceResult.Entity) and
        (traceResult.Entity:Health() > 0 and traceResult.Entity:Health() < 500)
end

--- Called when the behavior is started
function Breaker.OnStart(bot)
    return STATUS.Running
end

--- Called when the behavior's last state is running
function Breaker.OnRunning(bot)
    local startPos = bot:EyePos()
    local endPos = startPos + (bot:GetAimVector() * 64)
    local traceResult = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = bot,
    })

    local closest = traceResult.Entity

    -- If the line trace did not hit a valid breakable, return failure
    if not traceResult.Hit or not IsValid(closest) or closest:Health() <= 0 then
        return STATUS.Failure
    end

    ---@type CLocomotor
    local loco = bot.components.locomotor
    ---@type CInventory
    local imgr = bot.components.inventorymgr
    loco:LookAt(closest:GetPos(), 0.5)
    imgr:EquipMelee()
    imgr:PauseAutoSwitch()
    loco:StartAttack()
    loco:SetPriorityGoal(closest:GetPos(), 8) -- 8 is distance threshold
    return STATUS.Running
end

--- Called when the behavior returns a success state
function Breaker.OnSuccess(bot)
    local loco = bot.components.locomotor
    loco:StopAttack()
end

--- Called when the behavior returns a failure state
function Breaker.OnFailure(bot)
    local loco = bot.components.locomotor
    loco:StopAttack()
end

--- Called when the behavior ends, regardless of success or failure
function Breaker.OnEnd(bot)
    local loco = bot.components.locomotor
    bot.components.inventorymgr:ResumeAutoSwitch()
    loco:StopAttack()
end
