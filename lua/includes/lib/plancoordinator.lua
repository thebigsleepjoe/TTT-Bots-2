--[[
    This module is primarily for coordinating traitor bots with one another.
]]
include("includes/lib/plans.lua")

TTTBots.PlanCoordinator = {}
local PlanCoordinator = TTTBots.PlanCoordinator
local Plans = TTTBots.Plans
local ACTIONS = Plans.ACTIONS
local PLANSTATES = Plans.PLANSTATES
local TARGETS = Plans.PLANTARGETS

local IsRoundActive = TTTBots.Match.IsRoundActive --- @type function

-- hook.Add("TTTBeginRound", "TTTBots.PlanCoordinator.OnRoundStart", PlanCoordinator.OnRoundStart)
-- hook.Add("TTTEndRound", "TTTBots.PlanCoordinator.OnRoundEnd", PlanCoordinator.OnRoundEnd)

--- NOTE: due to how this function works, job chances are calculated PER assignment; it is possible to assign 1 bot when the max is 2 if the chance < 100%
function PlanCoordinator.TestJob(job, shouldIncrement)
    local conditions = job.Conditions
    if job.Skip then return false end
    local jobValid = TTTBots.Plans.AreConditionsValid(job)
    job.Skip = not jobValid
    if not jobValid then return false end

    local nAssigned = job.NumAssigned or 0
    local maxAssigned = job.MaxAssigned or 99

    if nAssigned >= maxAssigned then
        job.Skip = true
        return false
    end

    if shouldIncrement then job.NumAssigned = nAssigned + 1 end

    return true
end

--- Returns the next unassigned job in the assigned Plan's sequence.
---@param isAssignment boolean if this is being used to assign a job. default to false. if true then removes a/the job from stack
function PlanCoordinator.GetNextJob(isAssignment)
    if not IsRoundActive() then return nil end
    local selectedPlan = Plans.SelectedPlan
    if not selectedPlan then return nil end
    local jobs = selectedPlan.Jobs
    for i, job in pairs(jobs) do
        local test = PlanCoordinator.TestJob(job, isAssignment)
        if test then return job end
    end

    print("Reached end of plan stack, defaulting to attack everyone")
    return {
        Action = ACTIONS.ATTACKANY,
        Target = TARGETS.NEAREST_ENEMY,
    }
end

local targetHashTable = {
    [TARGETS.CALC_BOMBSPOT] = PlanCoordinator.CalculateTargetBombSpot,
    [TARGETS.CALC_POPULAR_AREA] = PlanCoordinator.CalculateTargetPopularArea,
    [TARGETS.FARTHEST_HIDINGSPOT] = PlanCoordinator.CalculateTargetFarthestHidingSpot,
    [TARGETS.FARTHEST_SNIPERSPOT] = PlanCoordinator.CalculateTargetFarthestSniperSpot,
    [TARGETS.NEAREST_ENEMY] = PlanCoordinator.CalculateTargetNearestEnemy,
    [TARGETS.NEAREST_HIDINGSPOT] = PlanCoordinator.CalculateTargetNearestHidingSpot,
    [TARGETS.NEAREST_SNIPERSPOT] = PlanCoordinator.CalculateTargetNearestSniperSpot,
    [TARGETS.NOT_APPLICABLE] = function() return nil end,
    [TARGETS.RAND_ENEMY] = PlanCoordinator.CalculateTargetRandEnemy,
    [TARGETS.RAND_FRIENDLY] = PlanCoordinator.CalculateTargetRandFriendly,
    [TARGETS.RAND_FRIENDLY_HUMAN] = PlanCoordinator.CalculateTargetRandFriendlyHuman,
    [TARGETS.RAND_POLICE] = PlanCoordinator.CalculateTargetRandPolice,
}

--- Calculates the target for a job, based upon the job's Target string.
---@param job table
---@return table Job the job, with the TargetObj field set. The TargetObj can also be retrieved with the second return value.
---@return Player|Vector3|nil TargetObj the target object, depending on the target type.
function PlanCoordinator.CalculateTargetForJob(job)
    local target = job.Target
    local targetFunc = targetHashTable[target]
    if not targetFunc then ErrorNoHalt("TargetFunc is not a real Target: " .. tostring(target)) end

    job.TargetObj = targetFunc(job)
    return job, job.TargetObj
end

function PlanCoordinator.Tick()
    Plans.Tick()
end
