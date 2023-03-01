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

function ladderMeta:GetPossibleStuckCost() return 0 end

function ladderMeta:IsCrouch() return false end

function ladderMeta:GetPortals() return {} end

local navMeta = FindMetaTable("CNavArea")

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

function navMeta:IsLadder()
    return false
end

function navMeta:IsCrouch()
    return self:HasAttributes(NAV_MESH_CROUCH)
end

--- Get the list of portals connected to us. Always returns a table
--- @return table table table of portals
function navMeta:GetPortals()
    local portals = TTTBots.PathManager.GetPortals()

    for i, v in pairs(portals) do
        if v.portal_cnavarea == self then
            return { v.destination_cnavarea }
        end
    end

    return {}
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
    local edge = self:GetClosestPointOnArea(other:GetCenter())
    -- snap edge onto other's navarea
    local otherEdge = other:GetClosestPointOnArea(edge)

    return otherEdge
end

local function heuristic_cost_estimate(current, goal)
    -- local h = current:GetCenter():Distance(goal:GetCenter())
    -- Manhattan distance
    local h = math.abs(current:GetCenter().x - goal:GetCenter().x) + math.abs(current:GetCenter().y - goal:GetCenter().y)

    if (current:IsLadder() or goal:IsLadder()) then return h * 1.0 end

    -- check if current and neighbor are underwater and add extra cost if true
    if current:IsUnderwater() and goal:IsUnderwater() then
        h = h + 50
    end

    return h * 1.0
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

function TTTBots.PathManager.Astar2(start, goal)
    local P_Astar2 = TTTBots.Lib.Profiler("Astar2", true)
    local closedSet = {}
    local openSet = { { area = start, cost = 0, fScore = heuristic_cost_estimate(start, goal) } }
    local neighborsCounted = 0
    local totalNeighbors = navmesh.GetNavAreaCount()

    if start == goal then return false end

    while (#openSet > 0) do
        local current = openSet[1]
        table.remove(openSet, 1)
        table.insert(closedSet, current.area)

        if (current.area == goal) then
            local path = { current.area }
            while (current.parent) do
                current = current.parent
                table.insert(path, 1, current.area)
            end
            local ms = P_Astar2()
            local avgms = ms / neighborsCounted
            print(string.format("Nodes visited: %d/%d. Took %d ms, which avg. %dms per 10 neighbors", neighborsCounted,
                totalNeighbors,
                ms, avgms * 10))
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
                local tentative_gScore = current.cost + distance_between(current.area, neighbor)
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

    local ms = P_Astar2()
    local avgms = ms / neighborsCounted
    print(string.format("Nodes visited: %d/%d. Took %d ms, which avg. %dms/neighbor", neighborsCounted, totalNeighbors,
        ms, avgms))
    return false
end

TTTBots.PathManager.ImpossiblePaths = {}

--[[]]
-- Request the creation of a path between two vectors. Returns pathinfo, which contains the path as a table of CNavAreas and the time of generation.
-- If it already exists, then return the cached path.
function TTTBots.PathManager.RequestPath(startpos, finishpos)
    if not startpos or not finishpos then return false end
    local sa = navmesh.GetNearestNavArea(startpos)
    local fa = navmesh.GetNearestNavArea(finishpos)

    local pid = sa:GetID() .. "to" .. fa:GetID()

    -- Do not generate a path if we've already tried one between these points and failed.
    if TTTBots.PathManager.ImpossiblePaths[pid] then
        return false
    end

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

    -- If it still doesn't exist, return false, and add it to the impossible paths table
    TTTBots.PathManager.ImpossiblePaths[pid] = true
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

                        -- check if the area of the area is over 200^2
                        local area = currentnode:GetSizeX() * currentnode:GetSizeY()
                        if area > 40000 then
                            -- add the center
                            table.insert(points, {
                                pos = currentnode:GetCenter(),
                                area = currentnode,
                                type = "walk",
                            })
                        end
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
