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

local printf = function(str, ...) print(string.format(str, ...)) end
local actRunnings = {
    [ACTIONS.ATTACKANY] = function(bot, job)
        local target = job.TargetObj
        if not (IsValid(target) and lib.IsPlayerAlive(target)) then return STATUS.FAILURE end
        bot.attackTarget = bot
    end,
    [ACTIONS.DEFEND] = function(bot, job)
        -- path to the TargetObj (which is a Vec3) and stand there
        -- TODO: Implement properly and auto-attack enemy targets that we can see.
        local targetPos = job.TargetObj
        bot.components.locomotor:SetGoalPos(targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.DEFUSE] = function(bot, job)
        -- TODO: Implement defusing plan (probably never will do this, as traitors do not need to defuse C4)
        printf("Bot %s attempting to perform unimplemented action DEFUSE", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.FOLLOW] = function(bot, job)
        -- set the path goal to the TargetObj's :GetPos location.
        -- TODO: This needs to be more subtle.
        local target = job.TargetObj
        if not IsValid(target) then return STATUS.FAILURE end
        local targetPos = target:GetPos()
        bot.components.locomotor:SetGoalPos(targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.GATHER] = function(bot, job)
        -- set the patch to the TargetObj (which is a vec3) and stand there.
        -- TODO: Expand on this behavior and make it more subtle.
        local targetPos = job.TargetObj
        bot.components.locomotor:SetGoalPos(targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.IGNORE] = function(bot, job)
        printf("This should not be getting called. Ever. Called by bot %s", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.PLANT] = function(bot, job)
        -- TODO: Implement bomb planting as a feature for traitors.
        printf("Bot %s attempting to perform unimplemented action PLANT", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.ROAM] = function(bot, job)
        -- walk directly to the TargetObj (vec3).
        -- TODO: Make this dynamically change the position so we actually roam.
        local targetPos = job.TargetObj
        bot.components.locomotor:SetGoalPos(targetPos)
        return STATUS.RUNNING
    end
}
actRunnings[ACTIONS.ATTACK] = actRunnings[ACTIONS.ATTACKANY]
--- Called when the behavior's last state is running
function FollowPlan:OnRunning(bot)
    return actRunnings[bot.Job.Action](bot, bot.Job)
end

--- Called when the behavior returns a success state
function FollowPlan:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function FollowPlan:OnFailure(bot)
end

--- Called when the behavior ends
function FollowPlan:OnEnd(bot)
    bot.Job = nil
end

-- Hook for PlayerSay to force give ourselves a follow job if a teammate traitor says in team chat to "follow"
hook.Add("PlayerSay", "TTTBots_FollowPlan_PlayerSay", function(ply, text, teamChat)
    printf("PlayerSay %s: %s (%s)", ply:Nick(), text, teamChat and "team" or "global")
    if not teamChat then return true end
    if not (lib.IsPlayerAlive(ply) and lib.IsEvil(ply)) then return true end
    if not string.find(string.lower(text), "follow", 1, true) then return true end

    local bot = TTTBots.Lib.GetClosest(TTTBots.Lib.GetAliveEvilBots(), ply:GetPos())

    local newJob = {
        Action = ACTIONS.FOLLOW,
        TargetObj = ply,
        State = TTTBots.Plans.BOTSTATES.IDLE,
        MinDuration = 20,
        MaxDuration = 60
    }

    bot.components.chatter:On("FollowRequest", { player = ply })

    bot.Job = newJob

    return true
end)
