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
---@param isAssignment boolean|nil if this is being used to assign a job. default to false. if true then removes a/the job from stack
---@param caller Player|nil the player who is calling this function. used for calculating targets if isAssignment is true. otherwise optional
function PlanCoordinator.GetNextJob(isAssignment, caller)
    if not IsRoundActive() then return nil end
    local selectedPlan = Plans.SelectedPlan
    if not selectedPlan then return nil end
    local jobs = selectedPlan.Jobs
    local assignedJob = { -- default job
        Action = ACTIONS.ATTACKANY,
        Target = TARGETS.NEAREST_ENEMY,
    }
    for i, job in pairs(jobs) do
        local test = PlanCoordinator.TestJob(job, isAssignment)
        if test then
            assignedJob = table.Copy(job) -- create a deep copy of the job
            break
        end
    end

    if isAssignment then
        assignedJob = PlanCoordinator.CalculateTargetForJob(assignedJob, caller)
        local timeNow = CurTime()
        assignedJob.TimeAssigned = timeNow
        assignedJob.ExpiryTime = timeNow + math.random((assignedJob.MinDuration or 15), (assignedJob.MaxDuration or 60))
    end
    return assignedJob
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcBombSpot(caller)
    local coverSpots = TTTBots.Lib.GetCoverSpots()
    local getWitnesses = TTTBots.Lib.GetAllWitnessesBasic

    for i, spot in pairs(coverSpots) do
        local witnesses = getWitnesses(spot, TTTBots.Match.AlivePlayers, caller) -- get all living witnesses to spot except caller
        if #witnesses == 0 then
            return spot
        end
    end

    print("couldn't find any spots to plant a bomb...")
    return nil
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcPopularArea(caller)
    local randArea = TTTBots.Lib.GetTopNPopularNavs(1) -- get the most popular nav
    if not (randArea and randArea[1]) then return PlanCoordinator.CalcRandFriendly(caller) end
    randArea = randArea[1][1]
    local targetPos = navmesh.GetNavAreaByID(randArea):GetRandomPoint()

    return targetPos
end

local function getClosestVec(origin, vecs)
    local closestVec = nil
    local closestDist = 0
    for i, vec in pairs(vecs) do
        local dist = vec:Distance(origin)
        if not closestVec or dist < closestDist then
            closestVec = vec
            closestDist = dist
        end
    end
    return closestVec, closestDist
end

local function getFarthestVec(origin, vecs)
    local farthestVec = nil
    local farthestDist = 0
    for i, vec in pairs(vecs) do
        local dist = vec:Distance(origin)
        if not farthestVec or dist > farthestDist then
            farthestVec = vec
            farthestDist = dist
        end
    end
    return farthestVec, farthestDist
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcFarthestHidingSpot(caller)
    local spots = TTTBots.Lib.GetCoverSpots()
    local callerPos = caller:GetPos()
    local farthestSpot, farthestDist = getFarthestVec(callerPos, spots)

    return farthestSpot
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcFarthestSniperSpot(caller)
    local spots = TTTBots.Lib.GetBestSniperSpots()
    local callerPos = caller:GetPos()
    local farthestSpot, farthestDist = getFarthestVec(callerPos, spots)

    return farthestSpot
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcNearestEnemy(caller)
    local closestInnocent = nil --TTTBots.Lib.GetClosest(TTTBots.Match.AliveNonEvil, caller:GetPos())
    local closestDist = math.huge

    for i, v in pairs(TTTBots.Match.AlivePlayers) do
        if v == caller then continue end
        if not TTTBots.Lib.IsPlayerAlive(v) then continue end
        local isevil = TTTBots.Lib.IsEvil(v)
        if isevil then continue end
        local dist = v:GetPos():Distance(caller:GetPos())
        if dist < closestDist then
            closestInnocent = v
            closestDist = dist
        end
    end

    return closestInnocent
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcNearestHidingSpot(caller)
    local spots = TTTBots.Lib.GetCoverSpots()
    local callerPos = caller:GetPos()
    local closestSpot, closestDist = getClosestVec(callerPos, spots)

    return closestSpot
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcNearestSnipeSpot(caller)
    local spots = TTTBots.Lib.GetBestSniperSpots()
    local callerPos = caller:GetPos()
    local closestSpot, closestDist = getClosestVec(callerPos, spots)

    return closestSpot
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandEnemy(caller)
    local randInnocent = table.Random(TTTBots.Match.AliveNonEvil)

    return randInnocent
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandFriendly(caller)
    local randFriendly = table.Random(TTTBots.Match.AliveTraitors)

    return randFriendly
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandFriendlyHuman(caller)
    local randFriendlyHuman = table.Random(TTTBots.Match.AliveHumanTraitors)

    return randFriendlyHuman or table.Random(TTTBots.Match.AliveTraitors)
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandPolice(caller)
    local randPolice = table.Random(TTTBots.Match.AlivePolice)

    return randPolice
end

local P = PlanCoordinator
local targetHashTable = {
    [TARGETS.ANY_BOMBSPOT] = P.CalcBombSpot,
    [TARGETS.FARTHEST_HIDINGSPOT] = P.CalcFarthestHidingSpot,
    [TARGETS.FARTHEST_SNIPERSPOT] = P.CalcFarthestSniperSpot,
    [TARGETS.NEAREST_ENEMY] = P.CalcNearestEnemy,
    [TARGETS.NEAREST_HIDINGSPOT] = P.CalcNearestHidingSpot,
    [TARGETS.NEAREST_SNIPERSPOT] = P.CalcNearestSnipeSpot,
    [TARGETS.NOT_APPLICABLE] = function() return nil end,
    [TARGETS.RAND_ENEMY] = P.CalcRandEnemy,
    [TARGETS.RAND_FRIENDLY] = P.CalcRandFriendly,
    [TARGETS.RAND_FRIENDLY_HUMAN] = P.CalcRandFriendlyHuman,
    [TARGETS.RAND_POLICE] = P.CalcRandPolice,
    [TARGETS.RAND_POPULAR_AREA] = P.CalcPopularArea,
}

--- Calculates the target for a job, based upon the job's Target string.
---@param job table
---@return table Job the job, with the TargetObj field set. The TargetObj can also be retrieved with the second return value.
---@return Player|Vector3|nil TargetObj the target object, depending on the target type.
function PlanCoordinator.CalculateTargetForJob(job, caller)
    local target = job.Target
    local targetFunc = targetHashTable[target]
    if not targetFunc then ErrorNoHalt("TargetFunc is not a real Target: " .. tostring(target)) end

    job.TargetObj = targetFunc(caller)
    return job, job.TargetObj
end

function PlanCoordinator.Tick()
    Plans.Tick()
end
