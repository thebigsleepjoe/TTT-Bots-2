--[[
    This module is primarily for coordinating traitor bots with one another.
]]
include("includes/lib/plans.lua")

TTTBots.PlanCoordinator = {}
local Coordinator = TTTBots.PlanCoordinator
local Plans = TTTBots.Plans
local ACTIONS = Plans.ACTIONS
local PLANSTATES = Plans.PLANSTATES
local TARGETS = Plans.PLANTARGETS

local IsRoundActive = TTTBots.Match.IsRoundActive --- @type function

-- hook.Add("TTTBeginRound", "TTTBots.PlanCoordinator.OnRoundStart", PlanCoordinator.OnRoundStart)
-- hook.Add("TTTEndRound", "TTTBots.PlanCoordinator.OnRoundEnd", PlanCoordinator.OnRoundEnd)

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
function PlanCoordinator.GetNextJob()
    if not IsRoundActive() then return nil end
    if not Plans.SelectedPlan then return nil end
    local selectedPlan = Plans.SelectedPlan
    -- TODO: Check conditions and return first unskipped/unassigned job
end

function PlanCoordinator.Tick()
    Plans.Tick()
end
