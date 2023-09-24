TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FollowPlan = {}

local lib = TTTBots.Lib

local FollowPlan = TTTBots.Behaviors.FollowPlan
FollowPlan.Name = "FollowPlan"
FollowPlan.Description = "Follow the plan assigned to us by the game coordinator."
FollowPlan.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Ignore plans if we aren't evil or have a conflicting personality trait.
function FollowPlan:ShouldIgnorePlans(bot)
    if not TTTBots.Lib.IsEvil(bot) then return true end                   -- ignore plans if we aren't evil
    if bot.components.personality:GetIgnoresOrders() then return true end -- ignore plans if we have a conflicting personality trait

    return true
end

--- Validate the behavior
function FollowPlan:Validate(bot)
    if self:ShouldIgnorePlans(bot) then return false end
    if not TTTBots.Plans.SelectedPlan then return false end
    return true
end

--- Called when the behavior is started
function FollowPlan:OnStart(bot)
    print("Start following the plan")
    return STATUS.SUCCESS -- just for now, debug purposes
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
