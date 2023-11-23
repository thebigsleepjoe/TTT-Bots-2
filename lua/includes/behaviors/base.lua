--[[
TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Base = {}

local lib = TTTBots.Lib

local BehaviorBase = TTTBots.Behaviors.Base
BehaviorBase.Name = "Base"
BehaviorBase.Description = "If you're reading this, something went wrong."
BehaviorBase.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function BehaviorBase.Validate(bot)
end

--- Called when the behavior is started
function BehaviorBase.OnStart(bot)
end

--- Called when the behavior's last state is running
function BehaviorBase.OnRunning(bot)
end

--- Called when the behavior returns a success state
function BehaviorBase.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function BehaviorBase.OnFailure(bot)
end

--- Called when the behavior ends
function BehaviorBase.OnEnd(bot)
end
]]
