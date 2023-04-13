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
end

--- Called when the behavior's last state is running
function Wander:OnRunning(bot)
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

function Wander:GetRandomSpawn()
    local spawnClass = navmesh.GetPlayerSpawnName()
    local spawnPoints = ents.FindByClass(spawnClass)

    return spawnPoints[math.random(1, #spawnPoints)]
end

function Wander:GetRandomSpawnArea()
    local spawn = self:GetRandomSpawn()
    local area = navmesh.GetNearestNavArea(spawn:GetPos())

    return area
end
