TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Wander = {}

local lib = TTTBots.Lib

local Wander = TTTBots.Behaviors.Wander
Wander.Name = "Wander"
Wander.Description = "Wanders around the map"

local status = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

--- Validate the behavior
function Wander:Validate(bot)
    return true
end

--- Called when the behavior is started
function Wander:OnStart(bot)
    bot.wander = {
        tick = 0,
        destArea = self:GetRandomArea(),
        wanderTime = 200, -- Maximum time before re-generating a destination
    }
    return status.Running
end

--- Called when the behavior's last state is running
function Wander:OnRunning(bot)
    local dest = bot.wander.destArea:GetCenter()
    local withinRange = self:DestinationWithinRange(bot, 100)
    bot.wander.tick = bot.wander.tick + 1
    if bot.wander.tick > bot.wander.wanderTime or withinRange then
        bot.wander.tick = 0
        bot.wander.destArea = self:GetRandomArea()
        return status.Success
    end

    local wanderPos = dest
    bot.components.locomotor:SetGoalPos(wanderPos)

    return status.Running
end

--- Called when the behavior returns a success state
function Wander:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Wander:OnFailure(bot)
end

--- Called when the behavior ends
function Wander:OnEnd(bot)
    bot.wander = {}
end

function Wander:DestinationWithinRange(bot, range)
    local dest = bot.wander.destArea:GetCenter()
    local pos = bot:GetPos()
    local dist = pos:Distance(dest)
    return dist < range
end

function Wander:GetRandomArea()
    local areas = navmesh.GetAllNavAreas()
    local area = table.Random(areas)
    return area
end
