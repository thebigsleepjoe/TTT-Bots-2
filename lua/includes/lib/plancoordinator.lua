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

function PlanCoordinator.TestJob(job)
    local conditions = job.Conditions
    -- TODO: Check conditions
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
