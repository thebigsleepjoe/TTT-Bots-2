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
local Plans = TTTBots.Plans
local ACTIONS = Plans.ACTIONS
local PLANSTATES = Plans.PLANSTATES
local TARGETS = Plans.PLANTARGETS

--- Ignore plans if we aren't evil or have a conflicting personality trait.
function FollowPlan:ShouldIgnorePlans(bot)
    local isEvil = TTTBots.Lib.IsEvil(bot)
    if not isEvil then return true end                                                             -- ignore plans if we aren't evil
    if not FollowPlan.Debug and bot.components.personality:GetIgnoresOrders() then return true end -- ignore plans if we have a conflicting personality trait

    return false
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

local function validateJobTime(job)
    return CurTime() > job.ExpiryTime
end

local actValidations = {
    [ACTIONS.ATTACKANY] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target)
    end,
    [ACTIONS.ATTACK] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target)
    end,
    [ACTIONS.DEFEND] = function(job)
        return validateJobTime(job)
    end,
    [ACTIONS.DEFUSE] = function(job)
        local targetC4 = job.TargetObj
        -- TODO: check if targetC4 is a C4, and check if it has been defused or not
    end,
    [ACTIONS.FOLLOW] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target)
    end,
    [ACTIONS.GATHER] = function(job)
        return validateJobTime(job)
    end,
    [ACTIONS.IGNORE] = function(job) return true end,
    [ACTIONS.PLANT] = function(job)
        local targetPos = job.TargetObj
        -- TODO: check if we have planted the bomb at the location (bascially if there is a c4 ent nearby it)
    end,
    [ACTIONS.ROAM] = function(job)
        return validateJobTime(job)
    end,
}

function FollowPlan:ValidateJob(bot, job)
    if not job then return false end
    local act = job.Action
    if not actValidations[act] then
        print("Attempt to do invalid job act! Type: '" .. tostring(job.Action) .. "'")
        return false
    end
    return actValidations[act](job)
end

--- Finds a new job if one isn't already set. Doesn't impact anything if the bot is doing a job already; otherwise, assigns a job using AutoSetBotJob
---@param bot Player the bot to assign a job to
---@return boolean|table false if no job was assigned, otherwise the job
function FollowPlan:FindNewJobIfAvailable(bot)
    local job = self:GetBotJob(bot)
    local jobValid = self:ValidateJob(bot, job)
    if jobValid then return false end

    return self:AutoSetBotJob(bot)
end

--- Validate the behavior
function FollowPlan:Validate(bot)
    if not TTTBots.Match.RoundActive and bot.Job then bot.Job = nil end
    if bot.Job then return true end
    if self:ShouldIgnorePlans(bot) then return false end
    if not TTTBots.Plans.SelectedPlan then return false end
    self:FindNewJobIfAvailable(bot)
    return true
end

--- Called when the behavior is started
function FollowPlan:OnStart(bot)
    if FollowPlan.Debug then
        print(" === JOB ASSIGNED ===")
        print(bot:Nick() .. "'s assigned job table: ")
        PrintTable(bot.Job)
        print(" === END JOB ===")
    end
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function FollowPlan:OnRunning(bot)
    print("Running action: " .. tostring(bot.Job.Action))
    return STATUS.RUNNING
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
