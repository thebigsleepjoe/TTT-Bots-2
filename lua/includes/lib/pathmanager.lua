TTTBots.PathManager = {}
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
    local adjusted = Vector(top.x, top.y, highest) + Vector(0, 0, 32) + forward * 14

    TTTBots.DebugServer.DrawCross(top, 10, Color(255, 0, 0), 5, "ladderTop")
    TTTBots.DebugServer.DrawLineBetween(top, adjusted, Color(255, 0, 0), 5, "ladderTop2")

    return adjusted
end

function ladderMeta:GetBottom2()
    local bottom = self:GetBottom()
    local forward = self:GetNormal()

    return bottom + forward * 10
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

function navMeta:GetPlayersInArea(filterTbl)
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if filterTbl and table.HasValue(filterTbl, ply) then continue end
        local closestPoint = self:GetClosestPointOnArea(ply:GetPos())
        local threshold = self:GetSizeX() / 3
        if (closestPoint:Distance(ply:GetPos()) < threshold) then
            table.insert(players, ply)
        end
    end

    return players
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

local function heuristic_cost_estimate(current, goal, playerFilter)
    local avoidCost = math.huge
    local perPlayerPenalty = 800 -- Deprioritize high-trafficked areas
    -- Manhattan distance
    local h = math.abs(current:GetCenter().x - goal:GetCenter().x) + math.abs(current:GetCenter().y - goal:GetCenter().y)

    -- Add extra cost for ladders
    if current:IsLadder() then
        return h -- Must return here because otherwise it will error with below methods
    end

    -- Check if current and neighbor are underwater and add extra cost if true
    if current:IsUnderwater() then
        h = h + 50
    end

    local nPlayers = #current:GetPlayersInArea(playerFilter)
    h = h + (nPlayers * perPlayerPenalty)

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
function TTTBots.PathManager.Astar2(start, goal, playerFilter)
    -- local P_Astar2 = TTTBots.Lib.Profiler("Astar2", true)
    local closedSet = {}
    local openSet = { { area = start, cost = 0, fScore = heuristic_cost_estimate(start, goal, playerFilter) } }
    local neighborsCounted = 0
    local totalNeighbors = navmesh.GetNavAreaCount()
    -- Coroutine
    local cpf = TTTBots.Lib.GetConVarInt("pathfinding_cpf") *
        (TTTBots.Lib.GetConVarBool("pathfinding_cpf_scaling") and #player.GetBots() or 1)
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
                local tentative_fScore = tentative_gScore + heuristic_cost_estimate(neighbor, goal, playerFilter)

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
        error(
            "The bot you are generating a path for is dead. Your path generation should be made safer.")
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
            -- table.insert(points, {
            --     pos = currentnode:GetCenter(),
            --     area = currentnode,
            --     type = "walk",
            -- })

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
                            pos = ladder:GetBottom2(),
                            area = ladder,
                            type = "ladder",
                            ladder_dir = "down",
                        })
                    else
                        table.insert(points, {
                            pos = ladder:GetTop2(),
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
                                pos = ladder:GetTop2(),
                                area = ladder,
                                type = "ladder",
                                ladder_dir = "down",
                            })
                        else
                            table.insert(points, {
                                pos = ladder:GetBottom2(),
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

                        local area = currentnode:GetSizeX() * currentnode:GetSizeY()

                        if (mtype ~= "fall" or area < 500) then
                            table.insert(points, {
                                pos = currentnode:GetCenter(),
                                area = currentnode,
                                type = mtype,
                            })
                        else
                            table.insert(points, {
                                pos = cedge,
                                area = currentnode,
                                type = mtype,
                            })
                        end

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
            preparedPath = path and type(path) == "table" and TTTBots.PathManager.PreparePathForLocomotor(path)
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
        local preparedPath = (path and type(path) == "table" and TTTBots.PathManager.PreparePathForLocomotor(path)) or
            nil

        -- print("Result of generation was " .. tostring(result) .. " (type " .. type(result) .. ")")

        -- Cache the path
        TTTBots.PathManager.cachedPaths[pathID] = {
            path = path,
            generatedAt = CurTime(),
            TimeSince = function(self) return CurTime() - self.generatedAt end,
            preparedPath = preparedPath
        }

        if not path or not preparedPath or #preparedPath == 0 then
            -- path is impossible add it to impossiblePaths
            TTTBots.PathManager.impossiblePaths[pathID] = true
            print("Found impossible path, " .. pathID)
        end

        -- Remove the path from the queue
        table.remove(queued, 1)

        -- print(fr("Path of ID %s for bot '%s' generated at %d", pathID, owner:Nick(), CurTime()))
    elseif result == "cannot resume dead coroutine" then
        -- print("Cannot resume dead coroutine, removing path from queue.")
        table.remove(queued, 1)
    end
end)
