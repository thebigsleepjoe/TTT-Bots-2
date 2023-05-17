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

local status = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

--- Validate the behavior
function Breaker:Validate(bot)
    local startPos = bot:EyePos()
    local endPos = startPos + (bot:GetAimVector() * 64)
    local traceResult = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = bot,
    })

    return traceResult.Hit and IsValid(traceResult.Entity) and
        table.HasValue(TTTBots.Components.ObstacleTracker.Breakables, traceResult.Entity) and
        traceResult.Entity:Health() > 0
end

--- Called when the behavior is started
function Breaker:OnStart(bot)
    return status.Running
end

--- Called when the behavior's last state is running
function Breaker:OnRunning(bot)
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
        return status.Failure
    end

    local loco = bot.components.locomotor
    local imgr = bot.components.inventorymgr
    -- Aim at closest using locomotor with loco:AimAt(pos, 0.5), imgr:EquipMelee(), and loco:SetAttack(true, 0.5)
    loco:AimAt(closest:GetPos(), 0.5)
    imgr:EquipMelee()
    loco:SetAttack(true, 0.5)
    loco:SetPriorityGoal(closest:GetPos(), 8) -- 8 is distance threshold
    return status.Running
end

--- Called when the behavior returns a success state
function Breaker:OnSuccess(bot)
    local loco = bot.components.locomotor
    loco:SetAttack(false)
end

--- Called when the behavior returns a failure state
function Breaker:OnFailure(bot)
    local loco = bot.components.locomotor
    loco:SetAttack(false)
end

--- Called when the behavior ends
function Breaker:OnEnd(bot)
end
