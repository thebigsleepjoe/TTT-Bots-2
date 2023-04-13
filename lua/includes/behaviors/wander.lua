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
    return status.Running
end

--- Called when the behavior's last state is running
function Wander:OnRunning(bot)
    local wanderArea = bot.wanderArea or self:GetRandomArea()
    if navmesh.GetNearestNavArea(bot:GetPos()) == wanderArea then -- If we're in the area, get a new one
        wanderArea = self:GetRandomArea()
    end

    local wanderPos = wanderArea:GetCenter()
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
end

function Wander:GetRandomArea()
    local areas = navmesh.GetAllNavAreas()
    local area = table.Random(areas)
    return area
end
