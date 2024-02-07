TTTBots.PathManager = {}
TTTBots.PathManager.cullSeconds = 5
TTTBots.PathManager.maxCachedPaths = 200
TTTBots.PathManager.completeRange = 28 -- 32 = half player height

-- Define constants
local LADDER_FORWARD_TOP = 14
local LADDER_FORWARD_BOTTOM = 8
local LADDER_TOP_FORWARD_OFFSET = 64 --- Applies to when the bot is navigating up a ladder, and needs to move forward after getting to the top

--[[ Introduce new navmesh/navarea meta functions to make our lives easier ]]
local ladderMeta = FindMetaTable("CNavLadder")

function ladderMeta:GetCenter()
    local start = self:GetBottom()
    local ending = self:GetTop()

    return (start + ending) / 2
end

--- Get the top of the ladder offset by the forward normal vector
function ladderMeta:GetTop2()
    local top = self:GetTop()
    local forward = self:GetNormal()

    -- limit the z of the top to its highest top area
    local areas = {
        self:GetTopBehindArea(),
        self:GetTopForwardArea(),
        self:GetTopLeftArea(),
        self:GetTopRightArea(),
    }

    local highest = 0
    for i, area in pairs(areas) do
        if (area) then
            local center = area:GetCenter()
            if (center.z > highest) then
                highest = center.z
            end
        end
    end

    top.z = highest
    local adjusted = Vector(top.x, top.y, highest) + Vector(0, 0, 32) + forward * LADDER_FORWARD_TOP

    -- TTTBots.DebugServer.DrawCross(top, 10, Color(255, 0, 0), 5, "ladderTop")
    -- TTTBots.DebugServer.DrawLineBetween(top, adjusted, Color(255, 0, 0), 5, "ladderTop2")

    return adjusted
end

function ladderMeta:GetBottom2()
    local bottom = self:GetBottom()
    local forward = self:GetNormal()

    return bottom + forward * LADDER_FORWARD_BOTTOM
end

function ladderMeta:IsLadder()
    return true
end

function ladderMeta:GetConnectionTypeBetween(other)
    return "walk"
end

function ladderMeta:GetAdjacentAreas()
    local adjacents = {
        self:GetBottomArea(),
        self:GetTopBehindArea(),
        self:GetTopForwardArea(),
        self:GetTopLeftArea(),
        self:GetTopRightArea(),
    }

    local adjacentsFilter = {}
    for i, area in pairs(adjacents) do
        if (area) then
            table.insert(adjacentsFilter, area)
        end
    end

    return adjacents
end

function ladderMeta:GetLadders()
    return {}
end

-- same as CNavArea's function, get distance between GetCenter()'s
function ladderMeta:ComputeGroundHeightChange(other)
    return self:GetCenter().z - other:GetCenter().z
end

function ladderMeta:GetClosestPointOnArea(vec)
    local bottom = self:GetBottom()
    local top = self:GetTop()

    local distTop = vec:Distance(top)
    local distBottom = vec:Distance(bottom)

    if (distTop < distBottom) then
        return top
    else
        return bottom
    end
end

function ladderMeta:GetPossibleStuckCost() return 0 end

function ladderMeta:IsCrouch() return false end

function ladderMeta:GetPortals() return {} end

local ladderProximityCache = {}

local function updateOrGetLadderProxCache(ladder)
    local cacheEntry = ladderProximityCache[ladder]
    if not (cacheEntry and cacheEntry.expires < CurTime()) then
        local proxCache = {
            expires = CurTime() + 3,
            players = {},
            nPlayers = 0,
        }

        for i, ply in pairs(TTTBots.Match.AlivePlayers) do
            if not IsValid(ply) then continue end
            if not TTTBots.Lib.IsPlayerAlive(ply) then continue end
            local bottom = ladder:GetBottom()
            local top = ladder:GetTop()
            local distBottom = ply:GetPos():Distance(bottom)
            local distTop = ply:GetPos():Distance(top)
            local threshold = ladder:GetLength() / 2

            if (distBottom < threshold) or (distTop < threshold) then
                table.insert(proxCache.players, ply)
                proxCache.nPlayers = proxCache.nPlayers + 1
            end
        end

        ladderProximityCache[ladder] = proxCache

        return proxCache
    end
    return cacheEntry
end

function ladderMeta:GetPlayersOn()
    return updateOrGetLadderProxCache(self).players
end

function ladderMeta:GetNPlayersOn()
    return updateOrGetLadderProxCache(self).nPlayers
end

local navMeta = FindMetaTable("CNavArea")

--- Calls self:GetCorner( number cornerId ) for each corner (0 - 3)
function navMeta:GetCorners()
    local corners = {}
    for i = 0, 3 do
        corners[i] = self:GetCorner(i)
    end
    return corners
end

function navMeta:GetPossibleStuckCost()
    local commonStucks = TTTBots.Components.Locomotor.commonStuckPositions
    for i, tbl in pairs(commonStucks) do
        local cnav = tbl.cnavarea
        if cnav == self then
            return tbl.stuckTime
        end
    end

    return 0
end

local navAreaProxCache = {}

local function updateOrGetNavProxCache(nav)
    local cacheEntry = navAreaProxCache[nav]
    if not (cacheEntry and cacheEntry.expires < CurTime()) then
        local proxCache = {
            expires = CurTime() + 5,
            players = {},
            nPlayers = 0,
        }

        for i, ply in pairs(TTTBots.Match.AlivePlayers) do
            if not IsValid(ply) then continue end
            if not TTTBots.Lib.IsPlayerAlive(ply) then continue end
            local center = nav:GetCenter()
            local threshold = nav:GetSizeX() * 2
            if (center:DistToSqr(ply:GetPos()) < threshold) then
                table.insert(proxCache.players, ply)
                proxCache.nPlayers = proxCache.nPlayers + 1
            end
        end

        navAreaProxCache[nav] = proxCache

        return proxCache
    end
    return cacheEntry
end

function navMeta:GetPlayersInArea()
    local proxCache = updateOrGetNavProxCache(self)
    return proxCache.players
end

function navMeta:GetNPlayersInArea()
    local proxCache = updateOrGetNavProxCache(self)
    return proxCache.nPlayers
end

function navMeta:IsLadder()
    return false
end

function navMeta:IsCrouch()
    return self:HasAttributes(NAV_MESH_CROUCH)
end

local AREA_SMALL_THRESHOLD = 8192 -- equal to about 90x90 units (64 HU is the width of a player)
local navAreaCalcsCache = {}
function navMeta:IsSmall()
    local areaOfArea = navAreaCalcsCache[self] or (self:GetSizeX() * self:GetSizeY())
    if not navAreaCalcsCache[self] then navAreaCalcsCache[self] = areaOfArea end
    return (areaOfArea < AREA_SMALL_THRESHOLD)
end

local navAreaPortalsCache = {}
--- Get the list of portals connected to us. Always returns a table
--- @return table table table of portals
function navMeta:GetPortals()
    if navAreaPortalsCache[self] then
        return navAreaPortalsCache[self]
    end

    local portals = TTTBots.PathManager.GetPortals()

    for i, v in pairs(portals) do
        if v.portal_cnavarea == self then
            navAreaPortalsCache[self] = { v.destination_cnavarea }
            return navAreaPortalsCache[self]
        end
    end

    navAreaPortalsCache[self] = {}
    return navAreaPortalsCache[self]
end

-- Infer the type of connection between two navareas
function navMeta:GetConnectionTypeBetween(other)
    if other:IsLadder() then return "ladder" end
    local heightDiff = self:ComputeAdjacentConnectionHeightChange(other)

    -- Todo: The pathfinding needs to not jump up ramps or stairs.
    -- We need it to be as sensitive as it currently is, but not jump up ramps or stairs.

    if self:IsUnderwater() or other:IsUnderwater() then
        return "swim"
    end

    if self:IsCrouch() or other:IsCrouch() then
        return "crouch"
    end


    if heightDiff > 16 then
        return "jump"
    elseif heightDiff < -64 then
        return "fall"
    end


    return "walk" -- idk, just walk
end

--- Retrieve the connecting point between two navareas
function navMeta:GetConnectingEdge(other)
    if other:IsLadder() then
        local myCenter = self:GetCenter()
        local ladderBottom = other:GetBottom()
        local ladderTop = other:GetTop()

        local distBottom = myCenter:Distance(ladderBottom)
        local distTop = myCenter:Distance(ladderTop)

        if (distBottom < distTop) then
            return ladderBottom
        else
            return ladderTop
        end
    end
    local edge = self:GetClosestPointOnArea(other:GetCenter())
    -- snap edge onto other's navarea
    local otherEdge = other:GetClosestPointOnArea(edge)

    return otherEdge
end

local function get_penalties_between(area, neighbor)
    local smallFallPenalty = 1000
    local jumpPenalty = 300
    local medFallPenalty = math.huge / 8
    local largeFallPenalty = math.huge / 2

    -- local heightChange = current:ComputeAdjacentConnectionHeightChange(goal)
    -- if heightChange < -64 then
    --     h = h + fallCost
    -- end
    if neighbor:IsLadder() or area:IsLadder() then return 0 end

    local heightChange = area:ComputeAdjacentConnectionHeightChange(neighbor)

    if heightChange < -256 then return largeFallPenalty end
    if heightChange < -128 then return medFallPenalty end
    if heightChange < -64 then return smallFallPenalty end
    if heightChange > 32 then return jumpPenalty end

    return 0
end

local function heuristic_cost_estimate(current, goal)
    local avoidCost = math.huge
    local perPlayerPenalty = 200 -- Deprioritize high-trafficked areas
    -- Manhattan distance
    local h = math.abs(current:GetCenter().x - goal:GetCenter().x) + math.abs(current:GetCenter().y - goal:GetCenter().y)

    -- Add extra cost for ladders
    if current:IsLadder() then
        -- We really don't want bots to go up ladders with people on them.
        local ladderOccupiedCost = current:GetNPlayersOn() * (perPlayerPenalty * 2)

        return h + ladderOccupiedCost
    end

    -- Check if current and neighbor are underwater and add extra cost if true
    if current:IsUnderwater() then
        h = h + 50
    end

    -- local nPlayers = current:GetNPlayersInArea()
    -- h = h + (nPlayers * perPlayerPenalty)

    -- Never go into lava, or what we consider a "lava" area
    local isLava = current:HasAttributes(NAV_MESH_AVOID)
    if isLava then
        h = h + avoidCost -- We MUST avoid this area
    end

    return h
end

local function distance_between(area1, area2)
    local connectionType = area1:GetConnectionTypeBetween(area2)
    local cost = 0

    local centerDist = area1:GetCenter():Distance(area2:GetCenter())

    if (connectionType == "walk") then
        cost = centerDist
    elseif (connectionType == "crouch") then
        cost = centerDist * 2
    elseif (connectionType == "jump") then
        cost = centerDist * 1.5
    elseif (connectionType == "fall") then
        cost = centerDist * 4
    elseif (connectionType == "ladder") then
        cost = centerDist * 1.5
    elseif (connectionType == "swim") then
        cost = centerDist * 2
    end

    return cost
end

--- Coroutine function that calculates paths
--- Never call directly, do PathManager.RequestPath, and the path will be generated.
---@return boolean|table result false if no path found nor possible, else output a table of navareas
function TTTBots.PathManager.Astar2(start, goal, _playerFilter)
    -- local P_Astar2 = TTTBots.Lib.Profiler("Astar2", true)
    local closedSet = {}
    local openSet = { { area = start, cost = 0, fScore = heuristic_cost_estimate(start, goal) } }
    local neighborsCounted = 0
    local totalNeighbors = navmesh.GetNavAreaCount()
    -- Coroutine
    local cpf = TTTBots.Lib.GetConVarInt("pathfinding_cpf") *
        (TTTBots.Lib.GetConVarBool("pathfinding_cpf_scaling") and (math.max(#TTTBots.Bots, 5) * 0.2) or 1)
    local cn = 0

    if start == goal then return false end

    while (#openSet > 0) do
        cn = cn + 1
        if (cn % cpf == 0) then
            coroutine.yield(cn)
        end
        if cn > 600 then -- 600 is the max number of nodes that can be checked before the pathfinder gives up
            return false
        end
        ---------------------------------- end coroutine stuff
        local current = openSet[1]
        table.remove(openSet, 1)
        table.insert(closedSet, current.area)

        if (current.area == goal) then
            local path = { current.area }
            while (current.parent) do
                current = current.parent
                table.insert(path, 1, current.area)
            end
            return path
        end

        local adjacents = current.area:GetAdjacentAreas()
        local ladders = current.area:GetLadders()
        local portals = current.area:GetPortals()
        table.Add(adjacents, ladders)
        table.Add(adjacents, portals)

        for _, neighbor in pairs(adjacents) do
            if (not table.HasValue(closedSet, neighbor)) then
                neighborsCounted = neighborsCounted + 1
                local tentative_gScore = current.cost + distance_between(current.area, neighbor) +
                    get_penalties_between(current.area, neighbor)
                local tentative_fScore = tentative_gScore + heuristic_cost_estimate(neighbor, goal)

                local neighborInOpenSet = false
                local neighborIndex = 0

                for i, n in ipairs(openSet) do
                    if (n.area == neighbor) then
                        neighborInOpenSet = true
                        neighborIndex = i
                        break
                    end
                end

                if (not neighborInOpenSet) then
                    table.insert(openSet,
                        { area = neighbor, cost = tentative_gScore, fScore = tentative_fScore, parent = current })
                elseif (tentative_fScore < openSet[neighborIndex].fScore) then
                    openSet[neighborIndex].cost = tentative_gScore
                    openSet[neighborIndex].fScore = tentative_fScore
                    openSet[neighborIndex].parent = current
                end
            end
        end

        table.sort(openSet, function(a, b) return a.fScore < b.fScore end)
    end

    return false
end

--- Table of paths to calculate. First come, first served
TTTBots.PathManager.cachedPaths = {}
TTTBots.PathManager.queuedPaths = {}
TTTBots.PathManager.impossiblePaths = {}
TTTBots.PathManager.botPathCooldowns = {} -- table of bots on cooldowns, player obj as key, curtime as value

function TTTBots.PathManager.IsUnreachable(startArea, destinationArea)
    local ID = startArea:GetID() .. "to" .. destinationArea:GetID()
    return TTTBots.PathManager.impossiblePaths[ID] ~= nil
end

function TTTBots.PathManager.IsUnreachableVec(startVec, destVec)
    local startArea = navmesh.GetNearestNavArea(startVec)
    local destArea = navmesh.GetNearestNavArea(destVec)
    if not (startArea and destArea) then return true end
    return TTTBots.PathManager.IsUnreachable(startArea, destArea)
end

--- Returns true if the bot is on cooldown, false otherwise
function TTTBots.PathManager.BotIsOnCooldown(bot)
    local cooldown = TTTBots.PathManager.botPathCooldowns[bot]
    if (not cooldown) or cooldown < CurTime() then
        return false
    end
    return true
end

--- Places the bot on cooldown if it isn't already. Returns true if is **not** on cooldown (can path), and false otherwise.
---@param bot any The bot to place on cooldown
---@return boolean isOnCooldown Whether the bot is on cooldown or not. Regardless, it will be AFTER this call.
function TTTBots.PathManager.CreateBotCooldown(bot)
    local onCooldown = TTTBots.PathManager.BotIsOnCooldown(bot)
    if (not onCooldown) then
        TTTBots.PathManager.botPathCooldowns[bot] = CurTime() + TTTBots.Lib.GetConVarInt("pathfinding_cooldown")
    end
    return not onCooldown
end

function TTTBots.PathManager.RemoveBotCooldown(bot)
    TTTBots.PathManager.botPathCooldowns[bot] = nil
end

local function getQueuedPathFor(player)
    for i, path in ipairs(TTTBots.PathManager.queuedPaths) do
        if (path.owner == player) then
            return path, i
        end
    end
end
--[[]]
--- Request the creation of a path between two vectors, or areas, if you already have them.
--- This does not immediately return the path unless it has already been generated, instead, it is handled by the coroutine Astar2 fn.
--- Returns false as the path if it is impossible to reach the goal, and true if the path is being calculated/queued.
--- Otherwise it's the path.
-------
--- This function does no calculations on its own, this handles queueing and allows you to spam it without making errors.
-------
---@param owner Player The player owner to attribute this to. This is REQUIRED, and prevents bots from making multiple paths at the same time.
---@param startPos any Vector (or CNavArea if isAreas==true)
---@param finishPos any Vector (or CNavArea if isAreas==true)
---@param isAreas boolean
---@return string pathID, boolean|table<CNavArea> path, string status
function TTTBots.PathManager.RequestPath(owner, startPos, finishPos, isAreas)
    if not startPos or not finishPos then
        error(
            "No startPos and/or finishPos, keep your functions safe from this error.")
    end
    if not TTTBots.Lib.IsPlayerAlive(owner) then
        -- print("Tried generating path for owner " .. tostring(owner) .. " but they are dead.")
        -- error(
        --     "The bot you are generating a path for is dead. Your path generation should be made safer.")
        return
    end

    local startArea = (isAreas and startPos) or
        TTTBots.Lib.GetNearestNavArea(startPos)  --navmesh.GetNearestNavArea(startPos)
    local finishArea = (isAreas and finishPos) or
        TTTBots.Lib.GetNearestNavArea(finishPos) --navmesh.GetNearestNavArea(finishPos)
    if not startArea or not finishArea then return end
    local pathID = startArea:GetID() .. "to" .. finishArea:GetID()

    local isImpossible = TTTBots.PathManager.impossiblePaths[pathID] ~= nil
    local existingPath = TTTBots.PathManager.cachedPaths[pathID]
    local queuedPath, pathNumber = getQueuedPathFor(owner)

    if isImpossible then return pathID, false, "impossible" end
    if existingPath then return pathID, existingPath, "path_exists" end
    if queuedPath and queuedPath.pathID == pathID then return pathID, true, "queued_already" end

    -- if TTTBots.PathManager.BotIsOnCooldown(owner) and (existingPath) then
    --     return pathID, true, "bot_on_cooldown"
    -- end

    if queuedPath and queuedPath.pathID ~= pathID then
        table.remove(TTTBots.PathManager.queuedPaths, pathNumber)
        table.insert(TTTBots.PathManager.queuedPaths, {
            owner = owner,
            pathID = pathID,
            startArea = startArea,
            finishArea = finishArea,
            path = nil,
        })
        return pathID, true, "queue_replaced"
    end

    -- We can only reach this point if the path is not queued, not cached, and not impossible.
    table.insert(TTTBots.PathManager.queuedPaths, {
        owner = owner,
        pathID = pathID,
        startArea = startArea,
        finishArea = finishArea,
        path = nil,
    })
    return pathID, true, "queued_now"
end

function TTTBots.PathManager.CanSeeBetween(vecA, vecB, addheight)
    local a = Vector(vecA.x, vecA.y, vecA.z)
    local b = Vector(vecB.x, vecB.y, vecB.z)

    if addheight then
        a.z = a.z + 32
        b.z = b.z + 32
    end

    local trace = util.TraceLine({
        start = a,
        endpos = b,
        filter = nil,
        mask = MASK_ALL
    })

    return not trace.Hit, trace
end

function TTTBots.PathManager.CanSeeBetweenAreaCenters(a, b, addheight)
    local startPos = a:GetCenter()
    local finish = b:GetCenter()

    return TTTBots.PathManager.CanSeeBetween(startPos, finish, addheight)
end

-------------------------------------
-- Path smoothing (bezier curves)
-------------------------------------

-- Bezier curve function; p0 is the start point, p1 is the control point, p2 is the end point, and t is the time.
-- t ranges from 0 to 1, and represents the percentage of the path that has been travelled.
local function bezierQuadratic(p0, p1, p2, t)
    local x = (1 - t) ^ 2 * p0.x + 2 * (1 - t) * t * p1.x + t ^ 2 * p2.x
    local y = (1 - t) ^ 2 * p0.y + 2 * (1 - t) * t * p1.y + t ^ 2 * p2.y
    local z = (1 - t) ^ 2 * p0.z + 2 * (1 - t) * t * p1.z + t ^ 2 * p2.z
    return Vector(x, y, z)
end

-- Processes a table of vectors and returns a table of vectors that are placed on the navmesh,
-- at least 32 units from the edges of the navmesh.
function TTTBots.PathManager.PlacePointsOnNavarea(vectors, areas)
    local points = {}

    for i = 1, #vectors do
        local point = vectors[i]
        local navarea = areas[i]
        if not navarea then continue end

        local areaOfArea = navarea:GetArea()
        if areaOfArea < 1000 then continue end

        local center = navarea:GetCenter()
        local extents = navarea:GetExtents()

        local x = math.Clamp(point.x, center.x - extents.x + 32, center.x + extents.x - 32)
        local y = math.Clamp(point.y, center.y - extents.y + 32, center.y + extents.y - 32)
        local z = math.Clamp(point.z, center.z - extents.z + 32, center.z + extents.z - 32)

        table.insert(points, Vector(x, y, z))
    end

    return points
end

--- Same as :GetCorners but is 1-indexed instead of zero-indexed
function navMeta:GetCorners2()
    local corners = {}
    for i = 1, 4 do
        corners[i] = self:GetCorner(i - 1)
    end
    return corners
end

function TTTBots.PathManager.GetPaddedNavCorners(cnavarea)
    local PADDING = 32
    local MIN_PERIMETER = 64
    if cnavarea:GetSizeX() < MIN_PERIMETER or cnavarea:GetSizeY() < MIN_PERIMETER then
        return cnavarea:GetCorners2()
    end
    local center = cnavarea:GetCenter()
    local corners = cnavarea:GetCorners2()

    -- Move each corner 32 units closer to the center
    for i, corner in pairs(corners) do
        local dir = (corner - center):GetNormalized()
        corners[i] = corner - dir * PADDING
    end

    return corners
end

-- Function to find the closest point on a line segment defined by points 'start' and 'end' to a given 'point'.
-- This function essentially projects 'point' onto the line segment and clamps it to the segment's boundaries.
local function ClosestPointOnLineSegment(start, endpoint, point)
    -- Calculate the vectors relative to 'start'
    local startPointToP = point - start
    local startToEnd = endpoint - start

    -- Calculate the squared length of the segment (used for normalization purposes)
    local segmentLengthSquared = startToEnd:Dot(startToEnd)

    -- Calculate the projection of startPointToP onto startToEnd
    -- This gives us a scalar value which tells us how far along startToEnd our projected point is
    local t = startPointToP:Dot(startToEnd) / segmentLengthSquared

    -- Clamp t to the range [0, 1] to ensure the point lies on the segment
    t = math.Clamp(t, 0, 1)

    -- Calculate and return the actual point on the segment
    return start + startToEnd * t
end

-- Function to find the closest point on a rectangle (defined by its four 'corners') to a given 'point'.
local function ClosestPointOnRectangle(corners, point)
    if #corners ~= 4 then
        error("Expected 4 corners for a rectangle")
    end

    -- Define the four edges of the rectangle
    local edges = {
        { corners[1], corners[2] },
        { corners[2], corners[3] },
        { corners[3], corners[4] },
        { corners[4], corners[1] }
    }

    -- Initialize our search for the closest point
    local closestPoint = nil
    local shortestDistance = math.huge

    -- Iterate through each edge and find the closest point on that edge to our 'point'
    for _, edge in ipairs(edges) do
        local pointOnEdge = ClosestPointOnLineSegment(edge[1], edge[2], point)
        local distanceToEdge = point:Distance(pointOnEdge)

        -- If this edge's point is closer than previously found points, update our closest point
        if distanceToEdge < shortestDistance then
            shortestDistance = distanceToEdge
            closestPoint = pointOnEdge
        end
    end

    return closestPoint
end

--- Converts a Vector3 to a rounded, compact string representation.
--- @param vec Vector3: The vector to convert.
--- @return string: A compact, rounded string representation of the vector.
local function VectorToString(vec)
    local x = math.Round(vec.x)
    local y = math.Round(vec.y)
    local z = math.Round(vec.z)
    return x .. "," .. y .. "," .. z
end

local paddingCache = {}
local closestCache = {} -- indexed by "navarea id : navarea id"
--- Return the closest point within the padded borders of areaA and areaB, to areaB.
local function getClosestCache(areaA, areaB, pos)
    local index = areaA:GetID() .. ":" .. areaB:GetID() .. ((pos and VectorToString(pos)) or "")
    if closestCache[index] then return closestCache[index] end

    local paddingMe = paddingCache[areaA] or TTTBots.PathManager.GetPaddedNavCorners(areaA)
    if not paddingCache[areaA] then paddingCache[areaA] = paddingMe end

    local closest = ClosestPointOnRectangle(paddingMe, areaB:GetCenter())
    closestCache[index] = closest
    return closest
end

--- Return the closest point along our padding to their center. Accounts for ladders by returning either the closest pos (top or bottom)
---@param other CNavArea the nav area to get the closest point to
---@param centerOrPos Vector3 defaults to the other nav area's center, but can be a vector3 within other
---@return Vector3 pos the closest point on our nav area to the other nav area, within padding
function navMeta:GetClosestPaddedPoint(other, centerOrPos)
    if other:IsLadder() then return self:GetConnectingEdge(other) end
    centerOrPos = centerOrPos or other:GetCenter()
    local closest = getClosestCache(self, other, centerOrPos)
    return closest
end

local function addPointToPoints(pointsTbl, point, area, nextAreaOrString, ladder_dir)
    if point == nil then error("Point cannot be nil") end
    table.insert(pointsTbl, {
        pos = point,
        area = area,
        type = (type(nextAreaOrString) == "string" and nextAreaOrString)
            or area:GetConnectionTypeBetween(nextAreaOrString),
        ladder_dir = ladder_dir,
    })

    -- local dbg = TTTBots.Lib.GetDebugFor("pathfinding")
    -- if dbg then
    --     print(string.format("Area #%s: Added a point at %s;", area:GetID(), point))
    -- end
end

--- The `TTTBots.PathManager.PathPostProcess` function processes a given path to determine the navigation strategies required
--- to move between each point in the path. It identifies actions like "jump", "ladder", "walk", or "fall" that a navigator must
--- undertake to move smoothly from one point to the next.
---
--- @param path table: A sequence of CNavAreas and CNavLadders, representing a path from start to finish.
--- @return table: A table containing a set of points with their positions, associated navigation areas, navigation actions,
--- and any ladder-related directions.
function TTTBots.PathManager.PathPostProcess(path)
    --[[
        Point structure:
        {
            pos = Vector(0, 0, 0),     -- Position of the point.
            area = navarea,            -- Associated navigation area.
            type = "jump" or "ladder" or "walk" or "fall", -- Action required to reach this point from the last point.
            ladder_dir = "up" or "down", -- Direction to move on the ladder (if it's a ladder), else nil.
        }
    ]]
    local points = {}
    local climbDir = nil

    for i, navArea in ipairs(path) do
        local isLadder = navArea:IsLadder()
        local isLast = i == #path
        local isFirst = i == 1
        local center = navArea:GetCenter()

        -- Information about the next navigation area in the path.
        local nextNavArea = (not isLast) and path[i + 1]
        local nextIsLadder = nextNavArea and nextNavArea:IsLadder()
        local nextCenter = nextNavArea and nextNavArea:GetCenter()
        local nextIsLower = nextCenter and (center.z > nextCenter.z)
        local nextIsSmall = nextNavArea and not nextIsLadder and nextNavArea:IsSmall()

        -- Information about the previous navigation area in the path.
        local lastNavArea = (not isFirst) and path[i - 1]
        local lastIsLadder = lastNavArea and lastNavArea:IsLadder()
        local lastCenter = lastNavArea and lastNavArea:GetCenter()
        local lastIsLower = lastCenter and (center.z > lastCenter.z)
        local lastIsSmall = lastNavArea and not lastIsLadder and lastNavArea:IsSmall()

        -- Determine the direction to climb if nextNavArea is a ladder.
        if nextIsLadder and nextIsLower then
            climbDir = "down"
        elseif nextIsLadder and not nextIsLower then
            climbDir = "up"
        elseif nextIsLadder then
            -- print("Couldn't resolve climb direction; " .. tostring(nextIsLadder) .. ", " .. tostring(nextIsLower))
        end

        -- Handle ladder areas.
        if isLadder then
            -- if not climbDir then print("No ladder dir in node #" .. i) end
            -- print("Direction of ladder travel is " .. tostring(climbDir) .. " in node #" .. i)
            local ladderFwd = navArea:GetNormal() * -16
            local ladderStart = (climbDir == "up") and navArea:GetBottom2() or navArea:GetTop2()
            local ladderGoal = (climbDir == "up") and (navArea:GetTop2() + ladderFwd) or navArea:GetBottom2()
            addPointToPoints(points, ladderStart, navArea, "ladder", climbDir)
            addPointToPoints(points, ladderGoal, navArea, "ladder", climbDir)

            if climbDir == "up" and nextNavArea then
                local ladderOffPoint = navArea:GetTop2() + Vector(0, 0, 32)
                local ladderDismountGoal = nextNavArea:GetClosestPointOnArea(ladderOffPoint) or nextNavArea:GetCenter()
                addPointToPoints(points, ladderDismountGoal, navArea, nextNavArea, climbDir)
            end
        else
            -- Handle first navigation area in the path.
            if isFirst then
                local closestPoint = navArea:GetClosestPaddedPoint(nextNavArea)
                -- addPointToPoints(points, navArea:GetCenter(), navArea, nextNavArea, nil)
                addPointToPoints(points, closestPoint, navArea, nextNavArea, nil)
            elseif not isLast then
                -- Handle intermediate navigation areas.
                -- First, check if our area is too small to justify complex pathing.
                if navArea:IsSmall() then
                    addPointToPoints(points, navArea:GetCenter(), navArea, nextNavArea, nil)
                    continue
                end

                if not lastIsLadder then
                    -- Get the padded connecting edge from last to current. Does not apply if last is small
                    if not lastIsSmall then
                        local closestLast = lastNavArea:GetClosestPaddedPoint(navArea)
                        addPointToPoints(points, closestLast, navArea, lastNavArea, nil)
                    end

                    -- Also get the closest point along our navmesh to the last connecting edge for consistency
                    local closestUsToLast = navArea:GetClosestPaddedPoint(lastNavArea,
                        closestLast or lastNavArea:GetCenter())
                    addPointToPoints(points, closestUsToLast, navArea, lastNavArea, nil)
                end
                if not nextIsLadder then
                    -- Get the padded connecting edge from current to next
                    local closestNext = navArea:GetClosestPaddedPoint(nextNavArea)
                    addPointToPoints(points, closestNext, navArea, nextNavArea, nil)
                end
            else
                -- Handle the last navigation area in the path.
                if not lastIsLadder and not nextIsSmall then
                    local closestLast = lastNavArea:GetClosestPaddedPoint(navArea)
                    addPointToPoints(points, closestLast, navArea, lastNavArea, nil)
                end
                addPointToPoints(points, navArea:GetCenter(), navArea, lastNavArea, nil)
            end
        end
    end

    return points
end

--------------------------------------
-- Culling
--------------------------------------

-- Cull the cache of paths that are older than the cullSeconds, and cull the oldest if we have too many paths.
function TTTBots.PathManager.CullCache()
    local cullSeconds = TTTBots.PathManager.cullSeconds
    local maxPaths = TTTBots.PathManager.maxCachedPaths

    local paths = TTTBots.PathManager.cachedPaths
    local pathsToCull = {}

    -- Find paths that are older than cullSeconds
    for k, path in pairs(paths) do
        if path:TimeSince() > cullSeconds then
            table.insert(pathsToCull, k)
        end
    end

    -- If we have too many paths, cull the oldest
    if table.Count(paths) > maxPaths then
        local oldestPath = nil
        local oldestTime = 0
        for k, path in pairs(paths) do
            if path:TimeSince() > oldestTime then
                oldestPath = k
                oldestTime = path:TimeSince()
            end
        end
        table.insert(pathsToCull, oldestPath)
    end

    -- Cull the paths
    for k, path in pairs(pathsToCull) do
        paths[path] = nil
    end
end

-- Create timer to cull paths every 5 seconds
timer.Create("TTTBotsPathManagerCullCache", 5, 0, function()
    TTTBots.PathManager.CullCache()
end)

--------------------------------------
-- Utility functions, pathing-related
--------------------------------------

-- Check how close the bot is to the end of the path, return True if within completion distance completeRange
function TTTBots.PathManager.BotIsCloseEnough(bot, vec)
    local completeRange = TTTBots.PathManager.completeRange
    local botpos = bot:GetPos()

    return (vec:Distance(botpos) < completeRange)
end

--- Gets the "portals" (trigger_teleport's and their linked destinations)
function TTTBots.PathManager.GetPortals()
    local possible_portals = ents.FindByClass("trigger_teleport")
    local portals = {}
    --[[
        Example portal: {
            portal = <Entity:trigger_teleport>,
            portal_no = <Number>,
            portal_pos = <Vector>,
            portal_cnavarea = <NavArea>,
            destination = <Entity:info_teleport_destination>,
            destination_pos = <Vector>,
            destination_cnavarea = <NavArea>,
        }
    ]]
    for portal_no, portal in ipairs(possible_portals) do
        local portal_pos = portal:GetPos()
        local portal_cnavarea = navmesh.GetNearestNavArea(portal_pos)

        local dest_name = portal:GetKeyValues()["target"]

        local destinationExists = dest_name ~= nil and ents.FindByName(dest_name) ~= nil
        if not destinationExists then continue end

        local destination = ents.FindByName(dest_name)[1]
        if not (destination ~= NULL and IsValid(destination)) then continue end
        local destination_pos = destination:GetPos()
        local destination_cnavarea = navmesh.GetNearestNavArea(destination_pos)

        table.insert(portals, {
            portal = portal,
            portal_no = portal_no,
            portal_pos = portal_pos,
            portal_cnavarea = portal_cnavarea,
            destination = destination,
            destination_pos = destination_pos,
            destination_cnavarea = destination_cnavarea,
        })
    end

    return portals
end

--- Hook for pathing coroutine
hook.Add("Tick", "TTTBots.PathManager.PathCoroutine", function()
    --[[
        Putting this comment here because I'm not sure where else to put it.

        Queued path structure:
        local queuedPath = {
            owner = owner,
            pathID = pathID,
            startArea = startArea,
            finishArea = finishArea,
            path = nil,
        }

        Cached path structure:
        local pathinfo = {
            path = path,
            generatedAt = CurTime(),
            TimeSince = function(self)
                return CurTime() - self.generatedAt
            end,
            processedPath = path and type(path) == "table" and TTTBots.PathManager.PathPostProcess(path)
        }
    ]]
    local queued = TTTBots.PathManager.queuedPaths
    local fr = string.format
    if #queued == 0 then
        return
    end

    local queuedPath = queued[1]

    if queuedPath.path == nil then
        queuedPath.path = coroutine.create(TTTBots.PathManager.Astar2)
    end

    -- print(fr("Generating path of ID %s for bot %s.", queuedPath.pathID, queuedPath.owner:Nick()))
    local noErrs, result = coroutine.resume(queuedPath.path, queuedPath.startArea, queuedPath.finishArea,
        { queuedPath.owner })

    if not noErrs then print("Had errors generating;", result) end
    if (type(result) == "boolean" or type(result) == "table") then
        local path = result
        local pathID = queuedPath.pathID
        local owner = queuedPath.owner
        local processedPath = (path and type(path) == "table" and TTTBots.PathManager.PathPostProcess(path)) or
            nil

        -- print("Result of generation was " .. tostring(result) .. " (type " .. type(result) .. ")")

        -- Cache the path
        TTTBots.PathManager.cachedPaths[pathID] = {
            path = path,
            generatedAt = CurTime(),
            TimeSince = function(self) return CurTime() - self.generatedAt end,
            processedPath = processedPath
        }

        if not path or not processedPath or #processedPath == 0 then
            -- path is impossible add it to impossiblePaths
            TTTBots.PathManager.impossiblePaths[pathID] = true
            -- print("Found impossible path, " .. pathID)
        end

        -- Remove the path from the queue
        table.remove(queued, 1)

        -- print(fr("Path of ID %s for bot '%s' generated at %d", pathID, owner:Nick(), CurTime()))
    elseif result == "cannot resume dead coroutine" then
        -- print("Cannot resume dead coroutine, removing path from queue.")
        table.remove(queued, 1)
    end
end)
