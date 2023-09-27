TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FollowPlan = {}

local lib = TTTBots.Lib

local FollowPlan = TTTBots.Behaviors.FollowPlan
FollowPlan.Name = "FollowPlan"
FollowPlan.Description = "Follow the plan assigned to us by the game coordinator."
FollowPlan.Interruptible = true
-- When debugging the component and you want to print extra info, use this:
FollowPlan.Debug = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Ignore plans if we aren't evil or have a conflicting personality trait.
function FollowPlan:ShouldIgnorePlans(bot)
    local isEvil = TTTBots.Lib.IsEvil(bot)
    if not isEvil then return true end                                                             -- ignore plans if we aren't evil
    if not FollowPlan.Debug and bot.components.personality:GetIgnoresOrders() then return true end -- ignore plans if we have a conflicting personality trait

    return false
end

--- Validate the behavior
function FollowPlan:Validate(bot)
    if not TTTBots.Match.RoundActive and bot.Job then bot.Job = nil end
    if bot.Job then return true end
    if self:ShouldIgnorePlans(bot) then return false end
    if not TTTBots.Plans.SelectedPlan then return false end
    if not bot.Job and not self:AutoSetBotJob(bot) then return false end
    return true
end

function FollowPlan:GetBotJob(bot) return bot.Job end

function FollowPlan:GetJobState(bot)
    local job = self:GetBotJob(bot)
    return (job and job.State) or TTTBots.Plans.BOTSTATES.IDLE
end

--- Grabs an available job from the PlanCoordinator and assigns it to the bot.
---@param bot Player the bot to assign a job to
---@return boolean|table false if no job was assigned, otherwise the job
function FollowPlan:AutoSetBotJob(bot)
    bot.Job = nil
    local job = TTTBots.PlanCoordinator.GetNextJob(true, bot)
    if not job then
        if FollowPlan.Debug then print("No jobs remaining for bot " .. bot:Nick()) end
        return false
    end
    job.State = TTTBots.Plans.BOTSTATES.IDLE
    bot.Job = job
    return job
end

--- Finds a new job if one isn't already set. Returns false if a) no job, b) already employed, or c) job is not finished.
function FollowPlan:FindNewJobIfAvailable(bot)
    local isDone = self:GetJobState(bot) == TTTBots.Plans.BOTSTATES.FINISHED
    local isEmployed = bot.Job ~= nil
    if not (isDone and isEmployed) then return false end
    return self:AutoSetBotJob(bot)
end

--- Called when the behavior is started
function FollowPlan:OnStart(bot)
    print("Start following the plan")
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function FollowPlan:OnRunning(bot)
    print("Bot's assigned job: ")
    PrintTable(bot.Job)
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
