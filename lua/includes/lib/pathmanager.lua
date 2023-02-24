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

function ladderMeta:IsCrouch() return false end

local navMeta = FindMetaTable("CNavArea")

function navMeta:IsLadder()
    return false
end

function navMeta:IsCrouch()
    return self:HasAttributes(NAV_MESH_CROUCH)
end

-- Infer the type of connection between two navareas
function navMeta:GetConnectionTypeBetween(other)
    local heightDiff = self:ComputeAdjacentConnectionHeightChange(other)
    if other:IsLadder() then return "ladder" end

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
    local edge = self:GetClosestPointOnArea(other:GetCenter())
    -- snap edge onto other's navarea
    local otherEdge = other:GetClosestPointOnArea(edge)

    return otherEdge
end

--[[ Define local A* functions ]]
-- A* Heuristic: Euclidean distance
local function heuristic_cost_estimate(start, goal)
    return start:GetCenter():Distance(goal:GetCenter())
end

function TTTBots.PathManager.Astar2(start, goal)
    if (not IsValid(start) or not IsValid(goal)) then return false end
    if (start == nil) or (goal == nil) then return false end
    if (start == goal) then return true end

    local open = {
        { area = start, cost = 0 },
    }
    local closed = {}

    while (#open > 0) do
        local current = table.remove(open, 1)
        table.insert(closed, current)

        if (current.area == goal) then
            local path = { current.area }
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
                currentCost = currentCost + (neighbor:GetLength() / 2) -- we want to prioritize ladders
            else
                local heightchange = current.area:ComputeGroundHeightChange(neighbor)
                if (heightchange > 128) then -- > 2 ply heights
                    currentCost = currentCost + (heightchange ^ 3);
                elseif (heightchange > 256) then -- do not fall if more than 4 ply heights
                    currentCost = currentCost + (100000000);
                end

                local connectionType = current.area:GetConnectionTypeBetween(neighbor)
                if (connectionType == "jump") then
                    currentCost = currentCost + 175
                elseif (connectionType == "fall") then
                    currentCost = currentCost + 150
                end

                currentCost = currentCost + (neighbor:IsUnderwater() and 50 or 0)

                if (neighbor:IsCrouch()) then
                    currentCost = currentCost + 50
                end
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

            table.insert(open, { area = neighbor, cost = currentCost, parent = current })
        end

        table.sort(open, function(a, b) return a.cost < b.cost end)
    end

    return false
end

--[[]]
-- Request the creation of a path between two vectors. Returns pathinfo, which contains the path as a table of CNavAreas and the time of generation.
-- If it already exists, then return the cached path.
function TTTBots.PathManager.RequestPath(startpos, finishpos)
    -- Check if the path already exists in the cache
    local path = TTTBots.PathManager.GetPath(startpos, finishpos)
    if path then
        return path
    end

    -- If it doesn't exist, generate it
    local path = TTTBots.PathManager.GeneratePath(startpos, finishpos)
    if path then
        return path
    end

    -- If it still doesn't exist, return false
    return false
end

-- See the RequestPath function for external use.
-- This function is only used internally, and should not be called from outside the TTTBots.PathManager file.
function TTTBots.PathManager.GeneratePath(startpos, finishpos)
    -- Find the nearest navareas to the start and goal positions
    local startArea = TTTBots.Lib.GetNearestNavArea(startpos)
    local goalArea = TTTBots.Lib.GetNearestNavArea(finishpos)

    -- Find a path between the start and goal navareas
    local path = TTTBots.PathManager.Astar2(startArea, goalArea)
    if not path then return false end

    local pathinfo = {
        path = path,
        generatedAt = CurTime(),
        TimeSince = function(self)
            return CurTime() - self.generatedAt
        end,
        preparedPath = path and type(path) == "table" and TTTBots.PathManager.PreparePathForLocomotor(path)
    }

    -- Cache the path
    TTTBots.PathManager.cache[startArea:GetID() .. "-" .. goalArea:GetID()] = pathinfo

    -- Return the pathinfo table
    return pathinfo
end

-- Return an existing pathinfo for a path between two vectors, or false if it doesn't exist.
-- Used internally in the RequestPath function, prefer to use RequestPath instead.
function TTTBots.PathManager.GetPath(startpos, finishpos)
    local nav1 = TTTBots.Lib.GetNearestNavArea(startpos)
    local nav2 = TTTBots.Lib.GetNearestNavArea(finishpos)
    if not nav1 or not nav2 then return false end

    local pathinfo = TTTBots.PathManager.cache[nav1:GetID() .. "-" .. nav2:GetID()]
    return pathinfo
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

---@deprecated
function TTTBots.PathManager.GetSmoothedPath(path, smoothness)
    error("Depricated function")
end

--- Use a simple algorithm to smooth the path. Calculate connection types between each navarea, and use that to determine
--- how to smooth the path, and instruct the navigator on what to do.
---@param path table Table of CNavAreas and CNavLadders that compose a real path, from start to finish.
---@return table PreparedPath table of vectors and how to navigate them.
function TTTBots.PathManager.PreparePathForLocomotor(path)
    --[[
        Point example:
        {
            pos = Vector(0, 0, 0),
            area = navarea,
            type = "jump" or "ladder" or "walk" or "fall", (if we have to do X to get here from the last point)
            ladder_dir = "up" or "down", (if ladder, else nil)
        }
    ]]
    local points = {}

    if path == nil or type(path) ~= "table" or #path == 0 then return points end

    --[[

        Basic Pathing:
            The way pathing works is that we add the connecting position between the current node and the last one.
            For instance, if the last node was a ladder and the path was supposed to move downwards,
            we add the GetBottom() position of the ladder.

            Here's a more algorithmic way of explaining it:

            1.) If this is the first node, add the center point of the navarea to the path.
            2.) If this is the last node, add the center point of the navarea to the path.
            3.) If this is a middle node (not first nor center):
                a.) If the prior node is a ladder:
                    i.) First determine what direction the ladder is supposed to be going.
                        This can be done by checking if the 2nd to last area (must be a cnavarea) is above or below the ladder's GetCenter().
                    ii.) If the 2nd to last area is above the ladder, the ladder is going down. Otherwise, up. And the placement of the
                        point is respective to that.

                b.) If the prior node is not a ladder, but the current one IS:
                    i.) Determine the direction of the ladder, same as above.
                    ii.) Add the point to the path, respective to the direction of the ladder.

                c.) If the prior node is not a ladder, and the current one is not a ladder:
                    i.) Add the navmeta:GetConnectingEdge() point to the path. This is very simple, and is the most common case.
                    ii.) Check if we need to jump between the last navarea and this one.
                    iii.) Check if we need to fall between the last navarea and this one.
                    iv.) Check if we need to crouch on this navarea.
    ]]
    for i = 1, #path do
        local secondlastnode = i > 2 and path[i - 2] or nil
        local lastnode = i > 1 and path[i - 1] or nil
        local currentnode = path[i]
        local nextnode = i ~= #path and path[i + 1] or nil

        -- 1.)
        if i == 1 then
            table.insert(points, {
                pos = currentnode:GetCenter(),
                area = currentnode,
                type = "walk",
            })

            -- 2.)
        else
            if i == #path then
                table.insert(points, {
                    pos = currentnode:GetCenter(),
                    area = currentnode,
                    type = "walk",
                })

                -- 3.)
            else
                -- a.)
                if lastnode:IsLadder() then
                    local ladder = lastnode
                    local ladder_dir = nil

                    -- i.)
                    if lastnode:GetCenter().z > currentnode:GetCenter().z then
                        ladder_dir = "down"
                    else
                        ladder_dir = "up"
                    end

                    -- ii.)
                    if ladder_dir == "down" then
                        table.insert(points, {
                            pos = ladder:GetBottom(),
                            area = ladder,
                            type = "ladder",
                            ladder_dir = "down",
                        })
                    else
                        table.insert(points, {
                            pos = ladder:GetTop(),
                            area = ladder,
                            type = "ladder",
                            ladder_dir = "up",
                        })
                    end

                    -- b.)
                else
                    if currentnode:IsLadder() then
                        local ladder = currentnode
                        local ladder_dir = nil

                        -- i.)
                        if currentnode:GetCenter().z > nextnode:GetCenter().z then
                            ladder_dir = "down"
                        else
                            ladder_dir = "up"
                        end

                        -- ii.)
                        if ladder_dir == "down" then
                            table.insert(points, {
                                pos = ladder:GetBottom(),
                                area = ladder,
                                type = "ladder",
                                ladder_dir = "down",
                            })
                        else
                            table.insert(points, {
                                pos = ladder:GetTop(),
                                area = ladder,
                                type = "ladder",
                                ladder_dir = "up",
                            })
                        end

                        -- c.)
                    else
                        local cedge = currentnode:GetConnectingEdge(lastnode)
                        --[[local mtype = lastnode and not lastnode:IsLadder() and
                            lastnode:GetConnectionTypeBetween(currentnode) or "walk"]]
                        local mtype = secondlastnode and not secondlastnode:IsLadder() and
                            secondlastnode:GetConnectionTypeBetween(lastnode) or "walk"
                        table.insert(points, {
                            pos = cedge,
                            area = currentnode,
                            type = mtype,
                        })
                    end
                end
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

    local paths = TTTBots.PathManager.cache
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
