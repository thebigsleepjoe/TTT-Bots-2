--[[
TODO goals for pathmanager:
    - Send a request to the pathmanager to generate a path between two vectors.
        If there is no path between the two vectors, return false.
        If there is a path, return the path as a table of CNavAreas. Finer details can be added later.

    - Once a path is generated, it should be cached by its CNavArea start and end points.
        If a path is requested between the same two CNavAreas, return the cached path.
        If it is unaccessed for more than 5 seconds, remove it from the cache, to save memory.

    - Once a path is generated, store its output in the bot's LatestPath field.
]]

TTTBots.PathManager = {}
TTTBots.PathManager.cache = {}
TTTBots.PathManager.cullSeconds = 5
TTTBots.PathManager.maxCachedPaths = 200
TTTBots.PathManager.completeRange = 32 -- 32 = half player height


--[[ Introduce new navmesh/navarea meta functions to make our lives easier ]]
local ladderMeta = FindMetaTable("CNavLadder")

function ladderMeta:GetCenter()
    local start = self:GetBottom()
    local ending = self:GetTop()

    return (start + ending) / 2
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
    for i,area in pairs(adjacents) do
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

local navMeta = FindMetaTable("CNavArea")

function navMeta:IsLadder()
    return false
end

function navMeta:IsCrouch()
    return self:HasAttributes(NAV_MESH_CROUCH)
end

-- Infer the type of connection between two navareas
function navMeta:GetConnectionTypeBetween(other)
    local heightDiff = self:ComputeGroundHeightChange(other)
    if other:IsLadder() then return "ladder" end

    if heightDiff == 0 then
        return "walk"
    elseif heightDiff > 32 then
        return "jump"
    elseif heightDiff < -32 then
        return "drop"
    end
end

--[[ Define local A* functions ]]

-- A* Heuristic: Euclidean distance
local function heuristic_cost_estimate(start, goal)
	return start:GetCenter():Distance( goal:GetCenter() )
end

-- using CNavAreas as table keys doesn't work, we use IDs
local function reconstruct_path( cameFrom, current )
	local total_path = { current }

	current = current:GetID()
	while ( cameFrom[ current ] ) do
		current = cameFrom[ current ]
		table.insert( total_path, navmesh.GetNavAreaByID( current ) )
    end
	return total_path
end

function TTTBots.PathManager.Astar2(start, goal)
    if (not IsValid(start) or not IsValid(goal)) then return false end
    if (start == nil) or (goal == nil) then return false end
	if ( start == goal ) then return true end

    local open = {
        {area=start, cost=0},
    }
    local closed = {}

    while (#open > 0) do
        local current = table.remove(open, 1)
        table.insert(closed, current)

        if (current.area == goal) then
            local path = {current.area}
            print("Cost of path " .. current.cost)
            while (current.parent) do
                current = current.parent
                table.insert(path, current.area)
            end
            return table.Reverse(path)
        end

        local adjacents = current.area:GetAdjacentAreas()
        local ladders = current.area:GetLadders()
        table.Add(adjacents, ladders)

        for k, neighbor in pairs(adjacents) do
            local currentCost = current.cost + heuristic_cost_estimate(current.area, neighbor)

            if neighbor:IsLadder() then
                currentCost = currentCost + neighbor:GetLength()
            else
                local heightchange = current.area:ComputeGroundHeightChange(neighbor)
                if (heightchange > 128) then -- > 2 ply heights
                    currentCost = currentCost + (heightchange ^ 2);
                elseif (heightchange > 256) then -- do not fall if more than 4 ply heights
                    currentCost = currentCost + (1000000);
                end

                local connectionType = current.area:GetConnectionTypeBetween(neighbor)
                if (connectionType == "jump") then
                    currentCost = currentCost + 75
                elseif (connectionType == "drop") then
                    currentCost = currentCost + 50
                end

                currentCost = currentCost + (neighbor:IsUnderwater() and 50 or 0)
            end

            local found = false
            for k, v in pairs(open) do
                if (v.area == neighbor) then
                    if (v.cost > currentCost) then
                        v.cost = currentCost
                        v.parent = current
                    end
                    found = true
                    break
                end
            end

            if (found) then continue end

            for k, v in pairs(closed) do
                if (v.area == neighbor) then
                    if (v.cost > currentCost) then
                        v.cost = currentCost
                        v.parent = current
                        table.insert(open, v)
                        table.remove(closed, k)
                    end
                    found = true
                    break
                end
            end

            if (found) then continue end

            table.insert(open, {area=neighbor, cost=currentCost, parent=current})
        end

        table.sort(open, function(a, b) return a.cost < b.cost end)
    end

    return false
end

local function AstarVector( start, goal )
	-- Find the nearest navareas to the start and goal positions
	local startArea = navmesh.GetNearestNavArea( start )
	local goalArea = navmesh.GetNearestNavArea( goal )

	-- Find a path between the start and goal navareas
	return TTTBots.PathManager.Astar2( startArea, goalArea )
end


--[[]]


local PathManager = TTTBots.PathManager

-- Request the creation of a path between two vectors. Returns pathinfo, which contains the path as a table of CNavAreas and the time of generation.
-- If it already exists, then return the cached path.
function PathManager.RequestPath(startpos, finishpos)
    -- Check if the path already exists in the cache
    local path = PathManager.GetPath(startpos, finishpos)
    if path then
        return path
    end

    -- If it doesn't exist, generate it
    local path = PathManager.GeneratePath(startpos, finishpos)
    if path then
        return path
    end

    -- If it still doesn't exist, return false
    return false
end

-- See the RequestPath function for external use.
-- This function is only used internally, and should not be called from outside the PathManager file.
function PathManager.GeneratePath(startpos, finishpos)
    -- Find the nearest navareas to the start and goal positions
    local startArea = navmesh.GetNearestNavArea(startpos)
    local goalArea = navmesh.GetNearestNavArea(finishpos)

    -- Find a path between the start and goal navareas
    local path = PathManager.Astar2(startArea, goalArea)
    if not path then return false end

    local pathinfo = {
        path = path,
        generatedAt = CurTime(),
        TimeSince = function (self)
            return CurTime() - self.generatedAt
        end
    }

    -- Cache the path
    PathManager.cache[startArea:GetID() .. "-" .. goalArea:GetID()] = pathinfo

    -- Return the pathinfo table
    return pathinfo
end

-- Return an existing pathinfo for a path between two vectors, or false if it doesn't exist.
-- Used internally in the RequestPath function, prefer to use RequestPath instead.
function PathManager.GetPath(startpos, finishpos)
    local nav1 = navmesh.GetNearestNavArea(startpos)
    local nav2 = navmesh.GetNearestNavArea(finishpos)
    if not nav1 or not nav2 then return false end

    local pathinfo = PathManager.cache[nav1:GetID() .. "-" .. nav2:GetID()]
    return pathinfo
end


function PathManager.CanSeeBetween(vecA, vecB, addheight)
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

function PathManager.CanSeeBetweenAreaCenters(a, b, addheight)
    local startPos = a:GetCenter()
    local finish = b:GetCenter()

    return PathManager.CanSeeBetween(startPos, finish, addheight)
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

local function getBezierPoints(start, control, finish, numpoints)
    local points = {}
    for i = 0, numpoints do
        local t = i / numpoints
        local point = bezierQuadratic(start, control, finish, t)
        table.insert(points, point)
    end
end

-- Processes a table of vectors and returns a table of vectors that are placed on the navmesh,
-- at least 32 units from the edges of the navmesh.
function PathManager.PlacePointsOnNavarea(vectors)
    local points = {}

    for i = 1, #vectors do
        local point = vectors[i]
        local navarea = navmesh.GetNearestNavArea(point)

        if not navarea then continue end

        local center = navarea:GetCenter()
        local extents = navarea:GetExtents()

        local x = math.Clamp(point.x, center.x - extents.x + 32, center.x + extents.x - 32)
        local y = math.Clamp(point.y, center.y - extents.y + 32, center.y + extents.y - 32)
        local z = math.Clamp(point.z, center.z - extents.z + 32, center.z + extents.z - 32)

        table.insert(points, Vector(x, y, z))
    end

    return points
end

--- This function will return a path based off the requested algorithm.
--- Possible algorithms are: "smoothpath", "smoothpath2", "smoothpathedges", "smoothpathcenters"
---@param smoothness integer The number of points to be generated between each navarea, if the algorithm uses it. 3 is the best value.
function PathManager.GetSmoothedPath(path, algorithm, smoothness)
    -- each algorithm is the name of a function in the PathManager table,
    local algos = {
        smoothpath = {
            func = PathManager.SmoothPath,
            vals = {path, smoothness or 3}
        },
        smoothpath2 = {
            func = PathManager.SmoothPath2,
            vals = {path, smoothness or 3}
        },
        smoothpathedges = {
            func = PathManager.SmoothPathEdges,
            vals = {path}
        },
        smoothpathcenters = {
            func = PathManager.SmoothPathCenters,
            vals = {path}
        }
    }

    local algo = algos[algorithm]
    if not algo then error(string.format("Attempt to use non-existant algorithm, '%s'", algorithm)) end
    return algo.func(table.unpack(algo.vals))
end

-- Smooths a path of CNavAreas using bezier curves. Returns a table of vectors.
-- smoothness is an integer that represents the number of points to be generated between each navarea.
function PathManager.SmoothPath(path, smoothness)
    -- The start is the center of the first navarea, the control point is the center of the second navarea, and the end is the center of the third navarea.

    local smoothPath = {}
    local n = 0 -- track number of points for next step

    for i = 1, #path-2, 3 do
        n = n + 1
        local p0 = path[i]:GetCenter()
        local p1 = path[i + 1]:GetCenter()
        local p2 = path[i + 2]:GetCenter()

        local csbac = PathManager.CanSeeBetweenAreaCenters

        -- Check we can see between all three navareas, if not then just add the 3 navarea centers to the path
        if
            (util.IsInWorld(p0) and util.IsInWorld(p1) and util.IsInWorld(p2))
            and not csbac(path[i], path[i + 2], true)
        then
            table.insert(smoothPath, p0)
            table.insert(smoothPath, p1)
            table.insert(smoothPath, p2)
            continue
        end

        for j = 1, smoothness do
            local t = j / smoothness
            local point = bezierQuadratic(p0, p1, p2, t)
            table.insert(smoothPath, point)
        end
    end

    -- If the path is not divisible by 3, then we need to add the last navarea(s) to the path.
    if #path % 3 == 1 then
        table.insert(smoothPath, path[#path]:GetCenter())
    elseif #path % 3 == 2 then
        table.insert(smoothPath, path[#path - 1]:GetCenter())
        table.insert(smoothPath, path[#path]:GetCenter())
    end

    return smoothPath
end

-- Use a different smoothing algorithm to smooth the path.
-- This will grab the edges of the navareas and use them to smooth the path, using the center of each navarea as the control.
-- This is a bit more accurate than the SmoothPath function, but it is also more expensive.
function PathManager.SmoothPath2(path, smoothness)
    local points = {}
    local areas = {} -- keep track of the navareas that we're using
    smoothness = math.max(smoothness, 3)

    for i, area in ipairs(path) do
        if area:IsLadder() then
            local lastcenter = path[i - 1]:GetCenter()

            local top = area:GetTop()
            local bottom = area:GetBottom()

            local topdist = lastcenter:Distance(top)
            local bottomdist = lastcenter:Distance(bottom)

            -- if we're closer to the top, then we want to go DOWN the ladder
            if topdist < bottomdist then
                table.insert(points, area:GetBottom())
                table.insert(points, area:GetCenter())
                table.insert(points, area:GetTop())
            else
                table.insert(points, area:GetTop())
                table.insert(points, area:GetCenter())
                table.insert(points, area:GetBottom())
            end


            continue
        end


        local tooSmallToSmooth = area:GetSizeX() < 64 or area:GetSizeY() < 64
        if tooSmallToSmooth then
            table.insert(points, area:GetCenter())
            continue
        end

        local center = area:GetCenter()

        if (i == 1) then
            table.insert(points, center)
            table.insert(points, area:GetClosestPointOnArea(path[i + 1]:GetCenter()))
            continue
        elseif (i == #path) then
            table.insert(points, area:GetClosestPointOnArea(path[i - 1]:GetCenter()))
            table.insert(points, center)
            continue
        end

        -- use :GetClosestPointOnArea(vec) to get the closest point on the past/future to our center
        local edge1 = path[i - 1]:GetClosestPointOnArea(center)
        local edge2 = path[i + 1]:GetClosestPointOnArea(center)

        -- edge1.z = center.z -- this is so we don't have to worry about the z axis
        -- edge2.z = center.z

        local visionTest = PathManager.CanSeeBetween(edge1, edge2, 32)

        -- if visionTest then use bezier to smooth btwn edge1, edge2 with center as control. use smoothness to determine n of points
        -- else then add each point raw w/o smoothing
        if visionTest then
            for j = 1, smoothness do
                local t = j / smoothness
                local point = bezierQuadratic(edge1, center, edge2, t)
                table.insert(points, point)
            end
        else
            table.insert(points, edge1)
            table.insert(points, center)
            table.insert(points, edge2)
        end
    end

    return points
end

-- Use the edges to "smooth". Basically, does what SmoothPath2, but no bezier curves. Just the edges.
function PathManager.SmoothPathEdges(path)
    local points = {}

    for i, area in ipairs(path) do
        local tooSmallToSmooth = area:GetSizeX() < 64 or area:GetSizeY() < 64
        if tooSmallToSmooth then
            table.insert(points, area:GetCenter())
            continue
        end

        local center = area:GetCenter()

        if (i == 1) or (i == #path) then
            table.insert(points, center)
            continue
        end

        -- use :GetClosestPointOnArea(vec) to get the closest point on the past/future to our center
        local edge1 = path[i - 1]:GetClosestPointOnArea(center)
        local edge2 = path[i + 1]:GetClosestPointOnArea(center)

        table.insert(points, edge1)
        table.insert(points, edge2)
    end

    return points
end

function PathManager.SmoothPathCenters(path)
    local points = {}

    for i, area in ipairs(path) do
        local center = area:GetCenter()
        table.insert(points, center)
    end

    return points
end

--------------------------------------
-- Culling
--------------------------------------

-- Cull the cache of paths that are older than the cullSeconds, and cull the oldest if we have too many paths.
function PathManager.CullCache()
    local cullSeconds = PathManager.cullSeconds
    local maxPaths = PathManager.maxCachedPaths

    local paths = PathManager.cache
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
timer.Create("TTTBotsPathManagerCullCache", 5, 0, function ()
    PathManager.CullCache()
end)

--------------------------------------
-- Utility functions, pathing-related
--------------------------------------

-- Check how close the bot is to the end of the path, return True if within completion distance completeRange
function PathManager.BotIsCloseEnough(bot, vec)
    local completeRange = PathManager.completeRange
    local botpos = bot:GetPos()

    return (vec:Distance(botpos) < completeRange)
end