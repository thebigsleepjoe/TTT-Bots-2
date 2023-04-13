--[[
TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Wander = {}

local lib = TTTBots.Lib

local BehaviorBase = TTTBots.Behaviors.Wander
BehaviorBase.Name = "Wander"
BehaviorBase.Description = "Wanders around the map"

local status = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

--- Validate the behavior
function BehaviorBase:Validate(bot)
    return true
end

--- Called when the behavior is started
function BehaviorBase:OnStart(bot)
end

--- Called when the behavior's last state is running
function BehaviorBase:OnRunning(bot)
end

--- Called when the behavior returns a success state
function BehaviorBase:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function BehaviorBase:OnFailure(bot)
end

--- Called when the behavior ends
function Wander:OnEnd(bot)
end
]]
