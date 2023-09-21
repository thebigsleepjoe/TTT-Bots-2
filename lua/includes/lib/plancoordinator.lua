--[[
    This module directs traitors (evil players) to collaborate with one another during rounds.
]]
include("includes/lib/plans.lua")

TTTBots.PlanCoordinator = {}
local Coordinator = TTTBots.PlanCoordinator

-- hook.Add("TTTBeginRound", "TTTBots.PlanCoordinator.OnRoundStart", PlanCoordinator.OnRoundStart)

function PlanCoordinator.OnRoundEnd()
    RoundInfo:Reset(false)
end

-- hook.Add("TTTEndRound", "TTTBots.PlanCoordinator.OnRoundEnd", PlanCoordinator.OnRoundEnd)

function PlanCoordinator.Tick()
end
