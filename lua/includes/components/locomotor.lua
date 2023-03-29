--[[

This component is how the bot gets to something. It does not create the paths, it just follows them.

TODO: rewrite instructions on how to use this component

]]
TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.Locomotor = {}

local lib = TTTBots.Lib
local BotLocomotor = TTTBots.Components.Locomotor

function BotLocomotor:New(bot)
    local newLocomotor = {}
    setmetatable(newLocomotor, {
        __index = function(t, k) return BotLocomotor[k] end,
    })
    newLocomotor:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized locomotor for bot " .. bot:Nick())
    end

    return newLocomotor
end

function BotLocomotor:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.locomotor = self

    self.componentID = string.format("locomotor (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                        -- Tick counter
    self.bot = bot

    self.path = nil                    -- Current path
    self.pathingRandomAngle = Angle()  -- Random angle used for viewangles when pathing
    self.pathLookSpeed = 0.05          -- Movement angle turn speed when following a path

    self.goalPos = nil                 -- Current goal position, if any. If nil, then bot is not moving.

    self.tryingMove = false            -- If true, then the bot is trying to move to the goal position.
    self.posOneSecAgo = nil            -- Position of the bot one second ago. Used for pathfinding.

    self.lookPosOverride = nil         -- Override look position, this is only used from outside of this component. Like aiming at a player.
    self.lookLerpSpeed = 0.05          -- Current look speed (rate of lerp)
    self.lookPosGoal = nil             -- The current goal position to look at
    self.lookPos = nil                 -- Current look position, gets lerped to Override, or to self.lookPosGoal.

    self.movePriorityVec = nil         -- Current movement priority vector, overrides movementVec if not nil
    self.movementVec = Vector(0, 0, 0) -- Current movement position, gets lerped to Override
    self.moveLerpSpeed = 0             -- Current movement speed (rate of lerp)
    self.moveNormal = Vector(0, 0, 0)  -- Current movement normal, functionally this is read-only.
    self.moveNormalOverride = nil      -- Override movement normal, mostly used within this component.

    self.strafe = nil                  -- "left" or "right" or nil
    self.forceForward = false          -- If true, then the bot will always move forward

    self.crouch = false
    self.jump = false
    self.dontmove = false
end

function BotLocomotor:GetWhereStandForDoor(door)
    if not IsValid(door) then return end
    if not IsEntity(door) then return end
    -- stand in front of the door
    local eyePos = self.bot:EyePos()
    local doorPos = door:GetPos()
    local trace = util.TraceLine({
        start = eyePos,
        endpos = doorPos,
        filter = self.bot,
        mask = MASK_SOLID,
    })
    if not trace.Hit then return end

    local hitNormal = trace.HitNormal

    -- The size of the side with the biggest width. This will essentially tell us how far to stand back.
    local widestAmt = math.max(door:OBBMaxs().x, door:OBBMaxs().y, door:OBBMaxs().z)
    local doorCenter = door:WorldSpaceCenter()
    local standPos = doorCenter + (hitNormal * widestAmt * 1.5)
    local standPosNav = navmesh.GetNearestNavArea(standPos)
    if not standPosNav then return end

    local standPosSnapped = standPosNav:GetClosestPointOnArea(standPos)
    return standPosSnapped
end

function BotLocomotor:GetMoveNormal()
    if self.moveNormalOverride then return self.moveNormalOverride end
    return self.moveNormal
end

function BotLocomotor:GetMoveNormalOverride()
    return self.moveNormalOverride
end

function BotLocomotor:OverrideMoveNormal(vec)
    self.moveNormalOverride = vec
end

function BotLocomotor:GetPriorityGoal()
    return self.movePriorityVec or false
end

--- Functionally assigns movePriorityVec to the given vector, if not within a certain range
---@param vec Vector
---@param range number defaults to 32
function BotLocomotor:SetPriorityGoal(vec, range)
    if not vec then return end
    range = range or 32

    local dist = self.bot:GetPos():Distance(vec)
    if dist < range then return end

    self.movePriorityVec = vec
end

--- Functionally sets movePriorityVec to nil.
function BotLocomotor:StopPriorityMovement()
    self.movePriorityVec = nil
end

--- Returns a table of the path generation info. The actual path is stored in a key called "path"
---@return table
function BotLocomotor:GetPath()
    return self.path
end

---@return boolean
function BotLocomotor:HasPath()
    return type(self.path) == "table" and type(self.path.path) == "table"
end

function BotLocomotor:GetPathLength()
    if not self:HasPath() then return 0 end
    if type(self:GetPath()) ~= "table" then return 0 end
    if not (self.path and self.path.path and self.path.path.path and type(self.path.path.path) == "table") then return 0 end
    -- # operator does not work here for some reason so count the old way
    return table.Count(self.path.path.path)
end

---@return boolean
function BotLocomotor:WaitingForPath()
    return self.pathWaiting
end

---@deprecated
---@see TTTBots.Components.Locomotor.HasPath
function BotLocomotor:ValidatePath()
    error("Deprecated function. Use HasPath instead.")
end

function BotLocomotor:UpdateLookPos()
    if self.lookPosOverride then
        self.lookPos = LerpVector(self.lookLerpSpeed, self:GetCurrentLookPos(), self:GetLookPosOverride())
        return
    end

    if self.lookPosGoal then
        self.lookPos = LerpVector(self.pathLookSpeed, self:GetCurrentLookPos(), self:GetLookPosGoal())
    end
    self.bot:SetEyeAngles((self.lookPos - self.bot:EyePos()):Angle())
end

function BotLocomotor:AimAt(pos, time)
    if time then
        self:TimedVariable("lookPosOverride", pos, time)
    else
        self.lookPosOverride = pos
    end
end

-- Getters and setters, just for formality and easy reading.
function BotLocomotor:SetCrouching(bool) self.crouch = bool end

function BotLocomotor:SetJumping(bool) self.jump = bool end

function BotLocomotor:SetCanMove(bool) self.dontmove = not bool end

-- Set a look override, we will use the look override to override viewangles. Actual look angle is lerped to the override using moveLerpSpeed.
function BotLocomotor:SetLookPosOverride(pos) self.lookPosOverride = pos end

---@deprecated Don't use. It works, but just don't use it. It's too abrupt.
function BotLocomotor:SetCurrentLookPos(pos) self.lookPos = pos end

function BotLocomotor:SetLookPosGoal(pos) self.lookPosGoal = pos end

function BotLocomotor:ClearLookPosOverride() self.lookPosOverride = nil end

function BotLocomotor:SetMoveLerpSpeed(speed) self.moveLerpSpeed = speed end

function BotLocomotor:SetStrafe(value) self.strafe = value end

function BotLocomotor:SetGoalPos(pos) self.goalPos = pos end

function BotLocomotor:SetUsing(bool) self.emulateInUse = bool end

function BotLocomotor:GetCrouching() return self.crouch end

function BotLocomotor:GetJumping() return self.jump end

function BotLocomotor:GetCanMove() return not self.dontmove end

function BotLocomotor:GetLookPosOverride() return self.lookPosOverride end

function BotLocomotor:GetLookPosGoal() return self.lookPosGoal end

function BotLocomotor:GetCurrentLookPos() return self.lookPos or self.bot:GetEyeTrace().HitPos end

function BotLocomotor:GetMoveLerpSpeed() return self.moveLerpSpeed end

function BotLocomotor:GetStrafe() return self.strafe end

function BotLocomotor:GetGoalPos() return self.goalPos end

function BotLocomotor:GetUsing() return self.emulateInUse end

--- Prop and player avoidance
function BotLocomotor:EnableAvoidance()
    self.dontAvoid = false
end

--- Prop and player avoidance
function BotLocomotor:DisableAvoidance()
    self.dontAvoid = true
end

function BotLocomotor:WithinCompleteRange(pos)
    return self.bot:GetPos():Distance(pos) < TTTBots.PathManager.completeRange
end

function BotLocomotor:GetClosestLadder()
    return lib.GetClosestLadder(self.bot:GetPos())
end

function BotLocomotor:IsOnLadder()
    return self.bot:GetMoveType() == MOVETYPE_LADDER
end

-- Do a trace to check if our feet are obstructed, but our head is not.
function BotLocomotor:CheckFeetAreObstructed()
    local pos = self.bot:GetPos()
    local bodyfacingdir = self:GetMoveNormal() or Vector(0, 0, 0)
    -- disregard z
    bodyfacingdir.z = 0

    local startpos = pos + Vector(0, 0, 16)
    local endpos = pos + Vector(0, 0, 8) + bodyfacingdir * 30

    local trce = util.TraceLine({
        start = startpos,
        endpos = endpos,
        filter = self.bot,
        --mask = MASK_SOLID_BRUSHONLY + MASK_SHOT_HULL
    })

    -- draw debug line
    --TTTBots.DebugServer.DrawLineBetween(startpos, endpos, Color(255, 0, 255))

    return trce.Hit and not (trce.Entity and (trce.Entity:IsPlayer() or trce.Entity:IsDoor()))
end

function BotLocomotor:ShouldJump()
    return self:CheckFeetAreObstructed() or (math.random(1, 100) == 1 and self:IsStuck())
end

function BotLocomotor:ShouldCrouchBetweenPoints(a, b)
    if not a or not b then return false end
    local area1 = navmesh.GetNearestNavArea(a)
    local area2 = navmesh.GetNearestNavArea(b)

    return (area1 and area1:IsCrouch()) or (area2 and area2:IsCrouch())
end

--- Wrapper for TTTBots.PathManager.BotIsCloseEnough(bot, pos)
function BotLocomotor:CloseEnoughTo(pos)
    return TTTBots.PathManager.BotIsCloseEnough(self.bot, pos)
end

--- Detect if there is a door ahead of us. Runs two traces, one for moveangles and one for viewangles. If so, then return the door.
function BotLocomotor:DetectDoorAhead()
    local pos = self.bot:EyePos()
    local nextPos = self.nextPos

    if not nextPos then return end

    local npTrace = util.TraceLine({
        start = pos,
        endpos = nextPos,
        filter = self.bot,
        mask = MASK_SOLID_BRUSHONLY
    })

    if npTrace.Hit then
        local ent = npTrace.Entity

        if IsValid(ent) and ent:IsDoor() then
            return ent
        end
    end

    return false
end

--- Sets a variable to a value for a certain amount of time. Useful for temporary positioning, and +use timing.
---@param name string Name of the variable to set
---@param value any Value to set the variable to
---@param time number Time in seconds
function BotLocomotor:TimedVariable(name, value, time)
    self[name] = value

    timer.Simple(time, function()
        if self[name] == value then -- only remove if it's still the same value
            self[name] = nil
        end
    end)

    return value
end

--- If the timed variable is not nil, return true. Otherwise, start the timer and return false.
--- To ONLY get the variable, just do self[name]. This function is only for setting the variable and returning its current setting.
---@param name string
---@param value any
---@param time number
---@return boolean Output True if the variable is already set, false if it is not.
function BotLocomotor:GetSetTimedVariable(name, value, time)
    if self[name] then return true end

    self:TimedVariable(name, value, time)
    return false
end

--- Used to prevent spamming of doors.
--- Calling this function returns a bool. True if can use again. If it returns true, it starts the timer.
--- Otherwise it returns false, and does nothing
function BotLocomotor:DoorOpenTimer()
    -- if self.cantUseAgain then return false end

    -- self:TimedVariable("cantUseAgain", true, 1.2)
    -- return true
    return not self:GetSetTimedVariable("cantUseAgain", true, 1.2)
end

--- Tick periodically. Do not tick per GM:StartCommand
function BotLocomotor:Think()
    self.tick = self.tick + 1
    local status = self:UpdatePath() -- Update the path that the bot is following, so that we can move along it.
    self:UpdateMovement()            -- Update the invisible angle that the bot moves at, and make it move.
end

--- Gets nearby players then determines the best direction to strafe to avoid them.
function BotLocomotor:AvoidPlayers()
    if self.dontAvoid then return end
    if self:GetIsCliffed() then return end -- don't let trolls push us off the map...
    local plys = player.GetAll()
    local pos = self.bot:GetPos()
    local bodyfacingdir = self:GetMoveNormal() or Vector(0, 0, 0)

    for _, ply in pairs(plys) do
        if ply == self.bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local plypos = ply:GetPos()
        local dist = pos:Distance(plypos)

        if dist < 64 then
            local dir = (pos - plypos):GetNormalized()
            local dot = dir:Dot(bodyfacingdir)

            if dot > 0 then
                self:SetStrafe("left")
                -- TTTBots.DebugServer.DrawLineBetween(pos, self.bot:GetPos() - self.bot:GetRight() * 100, Color(255, 0, 0))
            else
                self:SetStrafe("right")
                -- TTTBots.DebugServer.DrawLineBetween(pos, self.bot:GetPos() + self.bot:GetRight() * 100, Color(255, 0, 0))
            end
        end
    end
end

--- Determine if we're "Cliffed" (i.e., on the edge of something)
--- by doing two traces to our right and left, starting from EyePos and ending 100 units down, offset by 50 units to the right or left.
---@return boolean Cliffed True if we're cliffed (on the edge of something), false if we're not.
function BotLocomotor:GetIsCliffed()
    local pos = self.bot:EyePos()
    local right = self.bot:GetRight()
    local forward = self.bot:GetForward()
    local down = Vector(0, 0, -100)

    local rightTrace = util.TraceLine({
        start = pos,
        endpos = pos + (right * 50) + down,
        filter = self.bot,
        mask = MASK_SOLID_BRUSHONLY
    })

    local leftTrace = util.TraceLine({
        start = pos,
        endpos = pos - (right * 50) + down,
        filter = self.bot,
        mask = MASK_SOLID_BRUSHONLY
    })

    -- draw these traces with TTTBots.DebugServer.DrawLineBetween(start, finish, color, lifetime, forceID)
    -- TTTBots.DebugServer.DrawLineBetween(pos, pos + (right * 50) + down, Color(255, 0, 0))
    -- TTTBots.DebugServer.DrawLineBetween(pos, pos - (right * 50) + down, Color(255, 0, 0))

    return not (rightTrace.Hit and leftTrace.Hit)
end

--- Fetch obstacle props from our obstacletracker component, and modify the moveNormal
---@deprecated
function BotLocomotor:AvoidObstacles()
    if self.dontAvoid then return end
    local pos = self.bot:GetPos()
    local bodyfacingdir = self:GetMoveNormal() or Vector(0, 0, 0)
    local avgNearby = Vector(0, 0, 0)
    local nearbyCount = 0

    for _, ent in pairs(self.bot.components.obstacletracker:GetNearbyObstacles()) do
        if ent:GetClass() ~= "prop_physics" then continue end
        local entpos = ent:GetPos()
        avgNearby = avgNearby + entpos
        nearbyCount = nearbyCount + 1
    end

    if nearbyCount > 0 then
        avgNearby = avgNearby / nearbyCount
        local dir = (pos - avgNearby):GetNormalized()
        local dot = dir:Dot(bodyfacingdir)

        self:OverrideMoveNormal((bodyfacingdir + dir) * 0.5)
        TTTBots.DebugServer.DrawLineBetween(pos, pos + self.moveNormal * 100, Color(255, 0, 0))
    end
end

function BotLocomotor:Unstuck()
    --[[
        So we're stuck. Let's send 3x raycasts to figure out why.
            Ray 1: Straight forward, at knee-height, 30 units long. Mask is everything
            Ray 2: Straight left, at knee-height, 30 units long. Mask is everything
            Ray 3: Straight right, at knee-height, 30 units long. Mask is everything
        IF:
            Ray 1: We should jump.
            Ray 2: Strafe right
            Ray 3: Strafe left
    ]]
    local kneePos = self.bot:GetPos() + Vector(0, 0, 16)
    local bodyfacingdir = self.bot:GetAimVector()

    local magnitude = 30
    local forward = kneePos + (bodyfacingdir * magnitude)
    local ang = (bodyfacingdir:Angle():Right() * magnitude * 2)
    local left = kneePos + ang
    local right = kneePos - ang

    local trce1 = util.TraceLine({
        start = kneePos,
        endpos = forward,
        filter = self.bot,
        mask = MASK_ALL
    })

    local trce2 = util.TraceLine({
        start = kneePos,
        endpos = left,
        filter = self.bot,
        mask = MASK_ALL
    })

    local trce3 = util.TraceLine({
        start = kneePos,
        endpos = right,
        filter = self.bot,
        mask = MASK_ALL
    })

    -- draw debug lines
    -- TTTBots.DebugServer.DrawLineBetween(kneePos, forward, Color(255, 0, 255))
    -- TTTBots.DebugServer.DrawLineBetween(kneePos, left, Color(255, 0, 255))
    -- TTTBots.DebugServer.DrawLineBetween(kneePos, right, Color(255, 0, 255))
    local dvlpr = lib.GetConVarBool("debug_pathfinding")
    if dvlpr then
        TTTBots.DebugServer.DrawText(kneePos, string.format("%s's stuck!", self.bot:Nick()), Color(255, 0, 255))
    end

    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetStrafe(nil)

    self:SetJumping(trce1.Hit and not (trce1.Entity and (trce1.Entity:IsPlayer() or trce1.Entity:IsDoor())))
    self:SetStrafe(
        (trce2.Hit and "left") or
        (trce3.Hit and "right") or
        nil
    )

    if not (trce1.Hit or trce2.Hit or trce3.Hit) then
        -- We are still stuck but we can't figure out why. Just strafe in a random direction based off of the current tick.
        local direction = (self.tick % 20 == 0) and "left" or "right"
        self:SetStrafe(direction)
    end
end

--- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function BotLocomotor:UpdateMovement()
    local dbg_um = true
    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetStrafe(nil)
    self:SetUsing(false)
    self:OverrideMoveNormal(nil)
    self:StopPriorityMovement()
    self:SetLookPosOverride(nil)
    self.forceForward = false
    self.tryingMove = false
    if self.dontmove then return end

    local followingPath = self:FollowPath() -- true if doing proper pathing
    self.tryingMove = followingPath

    -- Walk straight towards the goal if it doesn't require complex pathing.
    local goal = self:GetGoalPos()

    if goal and not followingPath and not self:CloseEnoughTo(goal) then
        -- check goal navarea is same as bot:GetPos() nav area
        local botArea = navmesh.GetNearestNavArea(self.bot:GetPos())
        local goalArea = navmesh.GetNearestNavArea(goal)
        if (botArea == goalArea) then
            --self:LerpMovement(0.1, goal)
            self:SetPriorityGoal(goal)
            -- self.forceForward = true
            self.tryingMove = true
        end
    end

    -----------------------
    -- Unstuck code
    -----------------------

    if not self.tryingMove then return end

    -- If we're stuck, try to get unstuck.
    if self.tick % 3 == 1 then self:RecordPosition() end
    if self:IsStuck() then
        self:Unstuck()
    end

    -- self:AvoidObstacles()
    self:AvoidPlayers()

    -----------------------
    -- Door code
    -----------------------

    local door = self:DetectDoorAhead()
    if door then
        self:SetUsing(true)
        if not self.doorStandPos then
            local vec = self:GetWhereStandForDoor(door)
            local duration = 0.9
            self:TimedVariable("doorStandPos", vec, duration)
            self:TimedVariable("targetDoor", door, duration)
        end

        -- Above if sttement ensures doorStandPos is not nil
        self:SetPriorityGoal(self.doorStandPos, 8)
    end
end

--- Record the bot's position. This is used for getting the bot unstuck from weird situations.
function BotLocomotor:RecordPosition()
    if self.lastPositions == nil then self.lastPositions = {} end
    table.insert(self.lastPositions, self.bot:GetPos())

    if #self.lastPositions > 10 then
        table.remove(self.lastPositions, 1)
    end
end

--- Check if the bot is stuck. This is used for getting the bot unstuck from weird situations.
function BotLocomotor:IsStuck()
    if self.lastPositions == nil then return false end
    if #self.lastPositions < 10 then return false end

    local pos = self.bot:GetPos()
    local avgPos = Vector(0, 0, 0)
    for _, v in pairs(self.lastPositions) do
        avgPos = avgPos + v
    end
    avgPos = avgPos / #self.lastPositions

    local dist = pos:Distance(avgPos)

    return dist < 8
end

--- Update the path. Requests a path from our current position to our goal position.
---@return string status Status of the pathing, mostly flavor/debugging text.
function BotLocomotor:UpdatePath()
    self.cantReachGoal = false
    self.pathWaiting = false
    if self.dontmove then return "dont_move" end
    if self:GetGoalPos() == nil then return "no_goalpos" end
    if not lib.IsPlayerAlive(self.bot) then return "bot_dead" end

    local path = self:GetPath()
    local goalNav = navmesh.GetNearestNavArea(self:GetGoalPos())
    local pathLength = self:GetPathLength()
    if (self:HasPath() and pathLength > 0 and path.path.path[self:GetPathLength()] == goalNav) then
        return "pathing_currently"
    end


    -- If we don't have a path, request one
    local pathid, path, status = TTTBots.PathManager.RequestPath(self.bot, self.bot:GetPos(), self:GetGoalPos(), false)

    local fr = string.format

    if (path == false or path == nil) then -- path is impossible
        self.cantReachGoal = true
        self.path = nil
        return "path_impossible"
    elseif (path == true) then -- path is pending
        self.path = nil
        self.pathWaiting = true
        return "path_pending"
    else -- path is a table
        self.path = {
            path = path,
            pathid = pathid,
            preparedPath = path.preparedPath,
            pathIndex = 1, -- the index of the next path node to go to
            owner = self.bot,
        }
        self.pathWaiting = false
        return "path_ready"
    end
end

--- Do a traceline from startPos to endPos, with no specific mask (hit anything). Filter out ourselves.
--- Returns if we can see the endPos without interruption
function BotLocomotor:VisionTestNoMask(startPos, endPos)
    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = self.bot,
    })
    return not trace.Hit -- true if we can see the endPos
end

function BotLocomotor:DivideLineIntoSegments(startPos, endPos, units)
    local dist = startPos:Distance(endPos)
    local numSegments = math.ceil(dist / units)
    local segments = {}
    for i = 1, numSegments do
        local t = i / numSegments
        local pos = LerpVector(t, startPos, endPos)
        table.insert(segments, pos)
    end
    return segments
end

function BotLocomotor:GetStandHereTrace(pos)
    local origin = pos + Vector(0, 0, 16)
    local mins = self.bot:OBBMins()
    local maxs = self.bot:OBBMaxs() - Vector(0, 0, 16)
    local tr = util.TraceHull({
        start = origin,
        endpos = origin,
        mins = mins,
        maxs = maxs,
        filter = self.bot,
        ignoreworld = true,
    })
    return tr
end

function BotLocomotor:CanStandHere(pos)
    if util.IsInWorld(pos) then return false end

    local tr = self:GetStandHereTrace(pos)
    return not tr.Hit
end

function BotLocomotor:SnapPosToNearestNav(pos)
    local closestNav = lib.GetNearestNavArea(pos)
    if not closestNav:IsLadder() then
        pos = closestNav:GetClosestPointOnArea(pos)
    end
    return pos
end

--- Find the nearest walkable position around an entity
---@param point Vector The point to start from
---@param entity Entity The entity to find a walkable position around
---@param origin Vector The origin to measure distance from
---@return Vector WalkablePos the nearest walkable position
function BotLocomotor:FindNearestWalkableAroundEnt(point, entity, origin, lastWasAdjusted)
    if not origin then origin = self.bot:GetPos() end
    if not IsValid(entity) then return point end
    local attempts = {}
    local boundingR = entity:BoundingRadius() + 32

    local function addAttempt(pos)
        local dist = pos:Distance(origin)
        local walkable = self:CanStandHere(pos)
        local tr = util.TraceLine(
            {
                start = pos + Vector(0, 0, 0),
                endpos = pos + Vector(0, 0, 0),
                mask = MASK_SOLID_BRUSHONLY,
            }
        )
        local hitpos = tr.HitPos
        table.insert(attempts, {
            pos = hitpos or pos,
            walkable = walkable,
            dist = dist,
        })
    end

    addAttempt(point + Vector(boundingR, 0, 0))
    addAttempt(point + Vector(-boundingR, 0, 0))
    addAttempt(point + Vector(0, boundingR, 0))
    addAttempt(point + Vector(0, -boundingR, 0))

    table.SortByMember(attempts, "dist", true)
    local filter = lib.NthFilteredItem
    local N = lastWasAdjusted and 1 or 2
    local closestSuccess = filter(N, attempts, function(a)
        return a.walkable
    end)
    local closestFail = filter(N, attempts, function(a)
        return not a.walkable
    end)
    closestSuccess = closestSuccess and closestSuccess.pos
    closestFail = closestFail and closestFail.pos


    if closestSuccess then return closestSuccess end

    return closestFail
end

local function getClosestInTable(tbl, origin)
    local closestDist = math.huge
    local closestI = nil
    for i, v in ipairs(tbl) do
        local dist = v:Distance(origin)
        if dist < closestDist then
            closestDist = dist
            closestI = i
        end
    end
    return tbl[closestI], closestI
end

--- Determine the next pos along our current path
function BotLocomotor:DetermineNextPos()
    local pathinfo = self:GetPath().path
    if not pathinfo or not pathinfo.path or not pathinfo.preparedPath then return nil end
    local purePath = pathinfo.path
    local prepPath = pathinfo.preparedPath

    local bot = self.bot
    local botPos = bot:GetPos()
    local botEyePos = bot:GetShootPos()

    local dvlpr = lib.GetConVarBool("debug_pathfinding")

    local nextUncompleted = nil
    local lastCompleted = nil
    for i, v in ipairs(prepPath) do
        if not v.completed then
            nextUncompleted = v
            lastCompleted = prepPath[i - 1]
            break
        end
    end
    if not nextUncompleted then return nil end -- no more nodes to go to
    -- If we can't see neither the next node nor the last completed node, then we're stuck, mark the last completed as uncompleted
    if lastCompleted and not self:VisionTestNoMask(botEyePos, lastCompleted.pos + Vector(0, 0, 16)) and not self:VisionTestNoMask(botEyePos, nextUncompleted.pos + Vector(0, 0, 16)) then
        lastCompleted.completed = false
        if dvlpr then print("Bot is stuck, marking last completed node as uncompleted") end
        return nil -- return nil because if we return DetermineNextPos we will soft lock
    end

    local nextPos = nextUncompleted.pos

    -- now check if we're within 70 units of the next node and can see it
    local dist = botPos:Distance(nextPos)
    local canSee = self:VisionTestNoMask(botEyePos, nextPos + Vector(0, 0, 16))
    if (dist < 60 and canSee) or dist < 30 then
        nextUncompleted.completed = true
        return self:DetermineNextPos()
    end

    return nextPos, nextUncompleted.i
end

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    if not self:HasPath() then return false end
    if self.goalPos and self.goalPos:Distance(self.bot:GetPos()) < 40 then return false end
    local dvlpr = lib.GetDebugFor("pathfinding")
    local bot = self.bot

    local preparedPath = self:GetPath().preparedPath
    -- PrintTable(self:GetPath())

    if dvlpr and preparedPath then
        for i = 1, #preparedPath - 1 do
            local p1 = i == 1 and bot:GetPos() or preparedPath[i].pos
            TTTBots.DebugServer.DrawLineBetween(p1, preparedPath[i + 1].pos, Color(0, 125, 255))
        end
    end

    local nextPos, nextPosI = self:DetermineNextPos()
    self.nextPos = nextPos
    self.nextPosI = nextPosI

    if not self.nextPos then return false end

    if self:ShouldJump() then
        self:SetJumping(true)
    end

    if self:ShouldCrouchBetweenPoints(bot:GetPos(), nextPos) then
        self:SetCrouching(true)
    end

    if dvlpr then
        -- TTTBots.DebugServer.DrawSphere(nextPos, TTTBots.PathManager.completeRange, Color(255, 255, 0, 50))
        local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
        TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
        -- TTTBots.DebugServer.DrawLineBetween(bot:GetPos(), nextPos, Color(255, 255, 255))
    end

    return true
end

function BotLocomotor:UpdateViewAngles(cmd)
    local override = self:GetLookPosOverride()
    if override then
        self.lookPosGoal = override
        return
    end

    local preparedPath = self:HasPath() and self:GetPath().preparedPath
    local goal = self.goalPos


    if self.nextPos then
        local nextPosNormal = (self.nextPos - self.bot:GetPos()):GetNormal()
        local outwards = self.bot:GetPos() + nextPosNormal * 1200
        local randomLook = self:GetSetTimedVariable("randomLook", outwards, math.random(0.5, 2))

        -- do an eyetrace to see if there is something directly ahead of us
        local eyeTrace = self.bot:GetEyeTrace()
        local eyeTracePos = eyeTrace.HitPos
        local eyeTraceDist = eyeTracePos and eyeTracePos:Distance(self.bot:GetPos())
        local wallClose = eyeTraceDist and eyeTraceDist < 100

        if wallClose then self.randomLook = nil end

        self.lookPosGoal = (
            (not wallClose and self["randomLook"])
            or (wallClose and self.nextPos + Vector(0, 0, 64))
            or goal
            )
    end

    if self:IsOnLadder() then
        self.lookPosGoal = self.nextPos
    elseif self.targetDoor then
        local doorCenter = self.targetDoor:WorldSpaceCenter()
        self.lookPosGoal = doorCenter
    end

    if not self.lookPosGoal then return end

    self:UpdateLookPos()

    local dvlpr = lib.GetDebugFor("look")
    if dvlpr then
        -- DrawCross at lookPosGoal and lookPos
        TTTBots.DebugServer.DrawCross(self.lookPosGoal, 10, Color(255, 255, 255), 0.15, "lookPosGoal-" .. self.bot:Nick())
        TTTBots.DebugServer.DrawCross(self.lookPos, 10, Color(255, 0, 0), 0.15, "lookPos-" .. self.bot:Nick())
    end
end

--- Lerp look towards the goal position
function BotLocomotor:LerpMovement(factor, goal)
    if not goal then return end

    self.movementVec = LerpVector(factor, self.movementVec, goal)
    local dvlpr = lib.GetDebugFor("pathfinding")
end

function BotLocomotor:StartCommand(cmd)
    cmd:ClearButtons()
    cmd:ClearMovement()
    if self.dontmove then return end
    if not lib.IsPlayerAlive(self.bot) then return end

    local hasPath = self:HasPath()
    local dvlpr = lib.GetDebugFor("pathfinding")


    -- SetButtons to IN_DUCK if crouch is true
    cmd:SetButtons(
        (self:GetCrouching() or self:GetJumping()) and IN_DUCK or 0
    )

    -- Set buttons for jumping if :GetJumping() is true
    -- The way jumping works is a little quirky, as it cannot be held down. We must release it occasionally
    if self:GetJumping() and (self.jumpReleaseTime < CurTime()) or self.jumpReleaseTime == nil then
        cmd:SetButtons(IN_JUMP + IN_DUCK)
        self.jumpReleaseTime = CurTime() + 0.1

        if dvlpr then
            TTTBots.DebugServer.DrawText(self.bot:GetPos(), "Crouch Jumping", Color(255, 255, 255))
        end
    end

    if self:HasPath() and not self:GetPriorityGoal() then
        self:LerpMovement(0.1, self.nextPos)
    elseif self:GetPriorityGoal() then
        self:LerpMovement(0.1, self:GetPriorityGoal())
        if dvlpr then TTTBots.DebugServer.DrawCross(self.movePriorityVec, 10, Color(0, 255, 255)) end
    end



    if self.movementVec ~= Vector(0, 0, 0) then
        local ang = (self.movementVec - self.bot:GetPos()):Angle()
        -- local moveNormalOverride = self:GetMoveNormalOverride()
        -- if moveNormalOverride then
        --     ang = moveNormalOverride:Angle()
        -- end
        if dvlpr then
            TTTBots.DebugServer.DrawCross(self.movementVec, 5, Color(255, 255, 255), nil,
                self.bot:Nick() .. "movementVec")
        end
        cmd:SetViewAngles(ang) -- This is actually the movement angles, not the view angles. It's confusingly named.
    end

    if self:GetGoalPos() and self.bot:GetPos():Distance(self:GetGoalPos()) < 16 then
        self.movementVec = Vector(0, 0, 0)
    end

    self:UpdateViewAngles(cmd) -- The real view angles

    -- Set forward and side movement
    local forward = self.movementVec == Vector(0, 0, 0) and 0 or 400

    local side = cmd:GetSideMove()
    side = (self:GetStrafe() == "left" and -400)
        or (self:GetStrafe() == "right" and 400)
        or 0

    if self:IsOnLadder() then -- Ladder movement
        local strafe_dir = (self:GetStrafe() == "left" and IN_MOVELEFT) or (self:GetStrafe() == "right" and IN_MOVERIGHT) or
            0
        cmd:SetButtons(IN_FORWARD + strafe_dir)

        return
    end

    cmd:SetSideMove(side)
    cmd:SetForwardMove(not self.forceForward and forward or 400)

    -- Set up movement to always be up
    cmd:SetUpMove(400)

    if self:GetUsing() and self:DoorOpenTimer() then
        if dvlpr then
            TTTBots.DebugServer.DrawText(self.bot:GetPos(), "Opening door", Color(255, 255, 255))
        end
        cmd:SetButtons(cmd:GetButtons() + IN_USE)
    end

    self.moveNormal = cmd:GetViewAngles():Forward()
end

TTTBots.Components.Locomotor.commonStuckPositions = {}
TTTBots.Components.Locomotor.stuckBots = {}
--[[
Example stuckBots table:
{
    ["botname"] = {
        stuckPos = Vector(0, 0, 0),
        stuckTime = 0,
        ply = <Player>
    }
}

Example commonStuckPositions table: (every position within 200 units of center is considered related)
{
    {
        center = Vector(0, 0, 0), -- center of the position
        timeLost = 0, -- how much time, in man-seconds, has been lost near this position
        cnavarea = <CNavArea>, -- the CNavArea that this position is in
    }
}
]]
timer.Create("TTTBots.Locomotor.StuckTracker", 1, 0, function()
    local stuckBots = TTTBots.Components.Locomotor.stuckBots
    local commonStucks = TTTBots.Components.Locomotor.commonStuckPositions
    local bots = player.GetBots()

    ---------------------------
    -- Update stuckBots table
    ---------------------------
    for i, bot in pairs(bots) do
        if not lib.IsPlayerAlive(bot) then continue end
        local locomotor = bot.components.locomotor
        local botname = bot:Nick()

        if not locomotor then
            print("No loco for " .. bot:Nick())
            continue
        end

        local stuck = locomotor:IsStuck()
        local stuckPos = bot:GetPos()
        local stuckTime = 1

        if not stuck then
            if stuckBots[botname] then stuckBots[botname] = nil end
        else
            if not stuckBots[botname] then
                stuckBots[botname] = {
                    stuckPos = stuckPos,
                    stuckTime = stuckTime,
                    ply = bot
                }
            else
                stuckBots[botname].stuckPos = stuckPos
                stuckBots[botname].stuckTime = stuckBots[botname].stuckTime + 1

                stuckTime = stuckBots[botname].stuckTime
            end
        end

        -- local shouldUnstuck = (stuckTime > 3)

        -- if shouldUnstuck then
        --     local cnavarea = navmesh.GetNearestNavArea(stuckPos)
        --     if cnavarea then
        --         local randomPos = cnavarea:GetRandomPoint()
        --         bot:SetPos(randomPos + Vector(0, 0, 2))
        --     end
        -- end
    end

    ---------------------------
    -- Update/create commonStuckPositions table using stuckBots
    ---------------------------
    for botname, botinfo in pairs(stuckBots) do
        local stuckPos = botinfo.stuckPos

        local found = false
        for i, pos in pairs(commonStucks) do
            if pos.center:Distance(stuckPos) < 200 then
                pos.timeLost = pos.timeLost + 1
                if not table.HasValue(pos.victims, botname) then table.insert(pos.victims, botname) end
                found = true
                break
            end
        end

        if not found then
            table.insert(commonStucks, {
                center = stuckPos,
                timeLost = 1,
                victims = { botname },
                cnavarea = navmesh.GetNearestNavArea(stuckPos)
            })
        end
    end
end)


timer.Create("TTTBots.Locomotor.StuckTracker.Debug", 0.1, 0, function()
    if not lib.GetConVarBool("debug_stuckpositions") then return end
    local drawText = TTTBots.DebugServer.DrawText -- (pos, text, color)
    local f = string.format

    local commonStucks = TTTBots.Components.Locomotor.commonStuckPositions

    for i, pos in pairs(commonStucks) do
        drawText(pos.center,
            f("STUCK AREA (lost %d seconds | %d victims)", pos.timeLost, pos.victims and #pos.victims or 0),
            Color(255, 255, 255, 50))
    end
end)
