TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FollowPlan = {}

local lib = TTTBots.Lib

local FollowPlan = TTTBots.Behaviors.FollowPlan
FollowPlan.Name = "FollowPlan"
FollowPlan.Description = "If you're reading this, something went wrong."
FollowPlan.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function FollowPlan:Validate(bot)
end

--- Called when the behavior is started
function FollowPlan:OnStart(bot)
end

--- Called when the behavior's last state is running
function FollowPlan:OnRunning(bot)
end

--- Called when the behavior returns a success state
function FollowPlan:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function FollowPlan:OnFailure(bot)
end

--- Called when the behavior ends
function FollowPlan:OnEnd(bot)
end
