--[[
    This module is primarily for coordinating traitor bots with one another.
]]
include("tttbots2/lib/sv_plans.lua")

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
function PlanCoordinator.TestJob(job, shouldModify, bot)
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

    job.AssignedBots = job.AssignedBots or {}

    if (not job.Repeat) and job.AssignedBots[bot] then -- Do not repeat a job that has already been assigned to this bot
        return false
    end

    if shouldModify then
        job.NumAssigned = nAssigned + 1
        job.AssignedBots[bot] = true
    end

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
        local test = PlanCoordinator.TestJob(job, isAssignment, caller)
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
    local coverSpots = TTTBots.Spots.GetSpotsInCategory("hiding")
    local getWitnesses = TTTBots.Lib.GetAllWitnessesBasic

    for i, spot in pairs(coverSpots) do
        local witnesses = getWitnesses(spot, TTTBots.Match.AlivePlayers, caller) -- get all living witnesses to spot except caller
        if #witnesses == 0 then
            return spot
        end
    end

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

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcUnpopularArea(caller)
    local randArea = TTTBots.Lib.GetTopNUnpopularNavs(1) -- get the least popular nav
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
    local spots = TTTBots.Spots.GetSpotsInCategory("hiding")
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
        if TTTBots.Roles.IsAllies(caller, v) then continue end
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
    local spots = TTTBots.Spots.GetSpotsInCategory("hiding")
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
    local nonAllies = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply) return not TTTBots.Roles.IsAllies(caller, ply) end)
    local randInnocent = table.Random(nonAllies)

    return randInnocent
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandFriendly(caller)
    local allies = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply) return TTTBots.Roles.IsAllies(caller, ply) end)
    local randFriendly = table.Random(allies)

    return randFriendly
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandFriendlyHuman(caller)
    local alliesHuman = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        return TTTBots.Roles.IsAllies(caller, ply) and not ply:IsBot()
    end)
    local randFriendlyHuman = table.Random(alliesHuman)

    return randFriendlyHuman or PlanCoordinator.CalcRandFriendly(caller)
end

--- A Target Hashtable function to calculate a target for a job.
function PlanCoordinator.CalcRandPolice(caller)
    local police = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply) return ply:GetRoleStringRaw() == "detective" end)
    local randPolice = table.Random(police)

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
    [TARGETS.RAND_UNPOPULAR_AREA] = P.CalcUnpopularArea,
}

--- Calculates the target for a job, based upon the job's Target string.
---@param job table
---@return table Job the job, with the TargetObj field set. The TargetObj can also be retrieved with the second return value.
---@return Player|Vector3|nil TargetObj the target object, depending on the target type.
function PlanCoordinator.CalculateTargetForJob(job, caller)
    local target = job.Target
    local targetFunc = targetHashTable[target]
    if not targetFunc then ErrorNoHaltWithStack("TargetFunc is not a real Target: " .. tostring(target)) end

    job.TargetObj = targetFunc(caller)
    return job, job.TargetObj
end

function PlanCoordinator.Tick()
    Plans.Tick()
end
