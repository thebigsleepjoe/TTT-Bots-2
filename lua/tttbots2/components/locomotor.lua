--[[

This component is how the bot gets to something. It does not create the paths, it just follows them.

TODO: rewrite instructions on how to use this component

]]
---@class CLocomotor
TTTBots.Components.Locomotor = {}

local lib = TTTBots.Lib
---@class CLocomotor
local BotLocomotor = TTTBots.Components.Locomotor

-- Define constants
local NEXTPOS_COMPLETE_DIST_CANSEE = 32
local NEXTPOS_COMPLETE_DIST_CANTSEE = 16
local NEXTPOS_COMPLETE_DIST_VERTICAL_RANGE = 64  --- The range considered, irrespective of visual range, when above NEXTPOS_COMPLETE_DIST_VERTICAL_THRESH
local NEXTPOS_COMPLETE_DIST_VERTICAL_THRESH = 64 --- The Z axis must have a difference of this value to consider NEXTPOS_COMPLETE_DIST_VERTICAL_RANGE


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

    self.pathInfo = nil                   -- Current path
    self.pathInfoingRandomAngle = Angle() -- Random angle used for viewangles when pathing

    self.goalPos = nil                    -- Current goal position, if any. If nil, then bot is not moving.

    self.tryingMove = false               -- If true, then the bot is trying to move to the goal position.
    self.posOneSecAgo = nil               -- Position of the bot one second ago. Used for pathfinding.

    self.lookPosOverride = nil            -- Override look position, this is only used from outside of this component. Like aiming at a player.
    self.lookLerpSpeed = 0.05             -- Current look speed (rate of lerp)
    self.lookPosGoal = nil                -- The current goal position to look at
    self.lookPos = nil                    -- Current look position, gets lerped to Override, or to self.lookPosGoal.

    self.movePriorityVec = nil            -- Current movement priority vector, overrides movementVec if not nil
    self.movementVec = nil                -- Current movement position, gets lerped to Override
    self.moveLerpSpeed = 0                -- Current movement speed (rate of lerp)
    self.moveNormal = Vector(0, 0, 0)     -- Current movement normal, functionally this is read-only.
    self.moveNormalOverride = nil         -- Override movement normal, mostly used within this component.

    self.strafe = nil                     -- "left" or "right" or nil
    self.strafeTimeout = 0                -- The next tick our strafe will time out on, which is when it will be set to nil.
    self.forceForward = false             -- If true, then the bot will always move forward

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

function BotLocomotor:GetXYDist(a, b)
    local dist = a:Distance(Vector(b.x, b.y, a.z))
    return dist
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
    if dist < range then return true end

    self.movePriorityVec = vec
end

--- Functionally sets movePriorityVec to nil.
function BotLocomotor:StopPriorityMovement()
    self.movePriorityVec = nil
end

--- Returns a table of the path generation info. The actual path is stored in a key called "path"
---@return table
function BotLocomotor:GetPath()
    return self.pathInfo
end

---@return boolean
function BotLocomotor:HasPath()
    return type(self.pathInfo) == "table" and type(self.pathInfo.path) == "table"
end

function BotLocomotor:GetPathLength()
    if not self:HasPath() then return 0 end
    if type(self:GetPath()) ~= "table" then return 0 end
    if not (self.pathInfo and self.pathInfo.path and self.pathInfo.path.path and type(self.pathInfo.path.path) == "table") then return 0 end
    -- # operator does not work here for some reason so count the old way
    return table.Count(self.pathInfo.path.path)
end

---@return boolean
function BotLocomotor:WaitingForPath()
    return self.pathInfoWaiting
end

---@deprecated
---@see TTTBots.Components.Locomotor.HasPath
function BotLocomotor:ValidatePath()
    error("Deprecated function. Use HasPath instead.")
end

--- Legacy functionn to lerp eyeangles. This is not used anymore because it doesn't look realistic enough.
--- It's still here just in case.
---@see BotLocomotor.UpdateEyeAnglesFinal
---@deprecated
function BotLocomotor:LerpEyeAnglesFinal()
    local targetAngles = (self.lookPos - self.bot:EyePos()):Angle()
    local currentAngles = self.bot:EyeAngles()
    local rotationSpeed = 4 * (self.lookPosOverride and 1.75 or 1) -- Modify this value to change rotation speed
    local deltaTime = FrameTime()                                  -- Add frame time for frame rate independence

    local yawDiff = math.AngleDifference(targetAngles.y, currentAngles.y)
    local pitchDiff = math.AngleDifference(targetAngles.p, currentAngles.p)

    local yawFraction = math.Clamp(rotationSpeed * deltaTime, 0, 1)
    local pitchFraction = math.Clamp(rotationSpeed * deltaTime, 0, 1)

    local newYaw = Lerp(yawFraction, currentAngles.y, currentAngles.y + yawDiff)
    local newPitch = Lerp(pitchFraction, currentAngles.p, currentAngles.p + pitchDiff)

    self.bot:SetEyeAngles(Angle(newPitch, newYaw, 0))
end

--- Return the angle, in degrees, to the target from where we are currently looking.
---@param pos Vector
---@return number yawDiff, number pitchDiff
function BotLocomotor:GetEyeAngleDiffTo(pos)
    local currentAngles = self.bot:EyeAngles()
    local targetAngles = (pos - self.bot:EyePos()):Angle()
    local yawDiff = math.AngleDifference(targetAngles.y, currentAngles.y)
    local pitchDiff = math.AngleDifference(targetAngles.p, currentAngles.p)
    return yawDiff, pitchDiff
end

local LOOKSPEEDMULT_DECAYRATE = 0.96
--- [CALCULATED PER-FRAME] Decays the lookSpeedMultiplier value by LOOKSPEEDMULT_DECAYRATE to the bot's decay goal (usually 1)
function BotLocomotor:DecayLookSpeedMultiplier()
    local current = (self.lookSpeedMultiplier or 1)
    local decayGoal = 1
    if current == decayGoal then return decayGoal end -- very minor optimization
    self.lookSpeedMultiplier = math.max(current * LOOKSPEEDMULT_DECAYRATE, decayGoal)

    return self.lookSpeedMultiplier
end

function BotLocomotor:OnNewTarget(target)
    if not (target and IsValid(target)) then return end

    -- REACTION DELAY
    local ttt_bot_reaction_speed = lib.GetConVarFloat("reaction_speed")
    local ttt_bot_difficulty = lib.GetConVarInt("difficulty")
    local DIFFICULTY_MULT_HASH = {
        [1] = 3,   -- e.g. 0.3 x 3 = 0.9s
        [2] = 2,   -- e.g. 0.3 x 2 = 0.6s
        [3] = 1,   -- e.g. 0.3 x 1 = 0.3s
        [4] = 0.8, -- e.g. 0.3 x 0.8 = 0.24s
        [5] = 0,   -- e.g. 0.3 x 0 = 0s
    }
    local ttt_bot_cheat_traitor_reactionspd = lib.GetConVarBool("cheat_traitor_reactionspd")
    if ttt_bot_cheat_traitor_reactionspd and lib.IsEvil(self.bot) then
        ttt_bot_reaction_speed = ttt_bot_reaction_speed * 0.5
    end
    local DIFFICULTY_MULT = DIFFICULTY_MULT_HASH[ttt_bot_difficulty] or 1
    local reactionSpeed = ttt_bot_reaction_speed * DIFFICULTY_MULT
    self.reactionDelay = CurTime() + reactionSpeed

    -- Simulate a 'flick'
    local ttt_bot_flicking = lib.GetConVarBool("flicking")
    if ttt_bot_flicking then
        self.lookSpeedMultiplier = 5
    end
end

function BotLocomotor:RotateEyeAnglesTo(targetPos)
    local speedMult = self:DecayLookSpeedMultiplier()
    -- Settings for easier tweaking
    local RPS = 360 -- Max rotation speed per second (degrees)
    local MIN_ROTATION_SPEED = 0.15
    local MAX_ROTATION_SPEED = 1 * speedMult

    -- Calculate dependent variables
    local delta = FrameTime()
    local rotationSpeedLimit = RPS * delta

    local currentAngles = self.bot:EyeAngles()
    local yawDiffDeg, pitchDiffDeg = self:GetEyeAngleDiffTo(targetPos)

    -- The average difference of yaw and pitch to the target
    local avgDiffDeg = (math.abs(yawDiffDeg) + math.abs(pitchDiffDeg)) / 2

    -- Normalize the difference to range [0, 1]
    local factor = avgDiffDeg / 180 -- Since avgDiffDeg will be between 0 to 180 degrees

    -- Scale this by the min and max rotation speeds
    local adjustedSpeed = (MIN_ROTATION_SPEED + (MAX_ROTATION_SPEED - MIN_ROTATION_SPEED) * factor)

    -- Determine how much we should change our pitch and yaw this frame
    local pitchChange = math.Clamp(pitchDiffDeg * adjustedSpeed, -rotationSpeedLimit, rotationSpeedLimit)
    local yawChange = math.Clamp(yawDiffDeg * adjustedSpeed, -rotationSpeedLimit, rotationSpeedLimit)

    self.bot:SetEyeAngles(Angle(currentAngles.p + pitchChange, currentAngles.y + yawChange, 0))
end

--- This is the function responsible for actually changing the eye angles of the bot on the server's side.
--- It uses lookPosOverride/lookPosGoal to determine where to look.
function BotLocomotor:UpdateEyeAnglesFinal()
    if self.lookPosOverride then
        self.lookPos = self:GetLookPosOverride()
    else
        if self.lookPosGoal then
            self.lookPos = self:GetLookPosGoal()
        end
    end

    -- self:LerpEyeAnglesFinal()
    self:RotateEyeAnglesTo(self.lookPos)
end

--- Aims at a given pos for "time" seconds (optional). If no time, then one-time set.
---@param pos Vector
---@param time number|nil
function BotLocomotor:AimAt(pos, time)
    if not time then time = 1 end
    self.lookPosOverride = pos
    self.lookPosOverrideEnd = CurTime() + time
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

--- Set the direction of our strafing to either "left", "right", or nil. Non-nil values timeout after 2 ticks.
---@param value string|nil the strafe direction, or nil for none.
function BotLocomotor:SetStrafe(value)
    if type(value) == "number" then
        print("Strafe direction cannot be a number")
        return
    end
    if value then self.strafeTimeout = self.tick + (TTTBots.Tickrate) end -- expire after 1 second
    self.strafe = value
end

function BotLocomotor:SetForceForward(value)
    if value then self.forceForwardTimeout = self.tick + (TTTBots.Tickrate) end -- expire after 1 second
    self.forceForward = value
end

function BotLocomotor:SetRandomStrafe()
    local options = {
        "left", "right"
    }
    self:SetStrafe(table.Random(options))
end

function BotLocomotor:SetGoalPos(pos) self.goalPos = pos end

function BotLocomotor:SetUsing(bool) self.emulateInUse = bool end

function BotLocomotor:GetCrouching() return self.crouch end

function BotLocomotor:GetJumping() return self.jump end

function BotLocomotor:GetCanMove() return not self.dontmove end

function BotLocomotor:GetLookPosOverride() return self.lookPosOverride end

function BotLocomotor:GetLookPosGoal() return self.lookPosGoal end

function BotLocomotor:GetCurrentLookPos() return self.lookPos or self.bot:GetEyeTrace().HitPos end

function BotLocomotor:GetMoveLerpSpeed() return self.moveLerpSpeed end

--- Sets self.strafe to nil if strafeTimeout has been reached; returns self.strafe
---@return string|nil
function BotLocomotor:CancelStrafeIfTimeout()
    if (self.strafeTimeout or 0) < self.tick then
        self:SetStrafe(nil)
        -- print(string.format("strafe timeout; %d vs %d", self.strafeTimeout, self.tick))
    end
    return self.strafe
end

--- Sets self.forceForward to nil if forceForwardTimeout has been reached; returns self.forceForward
---@return boolean|nil
function BotLocomotor:CancelForceForwardIfTimeout()
    if (self.forceForwardTimeout or 0) < self.tick then
        self:SetForceForward(nil)
        -- print(string.format("ForceForward timeout; %d vs %d", self.ForceForwardTimeout, self.tick))
    end
    return self.forceForward
end

---@return string|nil
function BotLocomotor:GetStrafe()
    return self:CancelStrafeIfTimeout()
end

---@return boolean|nil
function BotLocomotor:GetForceForward()
    return self:CancelForceForwardIfTimeout()
end

function BotLocomotor:GetGoalPos()
    -- BotLocomotor:GetXYDist(a, b)
    if self.goalPos == nil then return nil end

    local distTo = self:GetXYDist(self.bot:GetPos(), self.goalPos)
    if distTo < 32 then
        self.goalPos = nil
    end
    return self.goalPos
end

function BotLocomotor:Stop()
    self:SetGoalPos(nil)
    self:SetUsing(false)
    self:SetStrafe(nil)
    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetLookPosOverride(nil)
    self.pathInfo = nil
    self.RLOStop = nil
    self.randomLook = nil
    self.movePriorityVec = nil
    self.movementVec = nil
end

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
    local off = Vector(0, 0, 16)
    local npTrace = util.TraceLine({
        start = self.bot:GetPos() + off,
        endpos = (self.bot:GetPos() + self:GetMoveNormal() * 100) + off,
        filter = self.bot
    })

    if npTrace.Hit then
        local ent = npTrace.Entity

        if IsValid(ent) and ent:IsDoor() then
            return ent
        end
    end

    return false
end

function BotLocomotor:DetectDoorNearby()
    local range = 100
    local pos = self.bot:GetPos()
    local doors = {}
    for i, ent in pairs(ents.FindInSphere(pos, range)) do
        if IsValid(ent) and ent:IsDoor() then
            table.insert(doors, ent)
        end
    end

    local closest = TTTBots.Lib.GetClosest(doors, pos)
    return closest
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
    self.status = status
    self:UpdateMovement()            -- Update the invisible angle that the bot moves at, and make it move.
end

--- Gets nearby players then determines the best direction to strafe to avoid them.
function BotLocomotor:AvoidPlayers()
    if self.dontAvoid then return end
    if self:GetIsCliffed() then return end -- don't let trolls push us off the map...
    local plys = player.GetAll()
    local pos = self.bot:GetPos()
    local nearbyClumpCenter = Vector(0, 0, 0)
    local nearbyClumpCount = 0

    for _, other in pairs(plys) do
        if other == self.bot then continue end
        if self.bot.attackTarget == other then continue end -- Don't try to avoid someone we want to kill. Duh!
        if not lib.IsPlayerAlive(other) then continue end

        local plypos = other:GetPos()
        local dist = pos:Distance(plypos)

        if dist < 50 then
            nearbyClumpCenter = nearbyClumpCenter + plypos
            nearbyClumpCount = nearbyClumpCount + 1
        end
    end

    if nearbyClumpCount == 0 then return end

    -- Get the clump position & try to navigate away from it
    local clumpPos = nearbyClumpCenter / nearbyClumpCount
    local clumpBackward = -self:GetNormalFacing(pos, clumpPos)

    self:SetRepelForce(clumpBackward, 0.3)
end

--- Returns the normal vector from pos1 to pos2. Basically this is just a normalized vector pointing from A to B.
---@param pos1 Vector
---@param pos2 Vector
---@return Vector normal
function BotLocomotor:GetNormalFacing(pos1, pos2)
    local dir = (pos2 - pos1):GetNormalized()
    return dir
end

function BotLocomotor:SetRepelForce(normal, duration)
    self.repelDir = normal
    self.repelStopTime = CurTime() + (duration or 1.0)
    self.repelled = true
end

function BotLocomotor:StopRepel()
    self.repelDir = nil
    self.repelStopTime = nil
    self.repelled = false
end

--- Determine if we're "Cliffed" (i.e., on the edge of something)
--- by doing two traces to our right and left, starting from EyePos and ending 100 units down, offset by 50 units to the right or left.
---@return boolean Cliffed True if we're cliffed (on the edge of something), false if we're not.
function BotLocomotor:SetIsCliffed()
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

    self.isCliffed = not (rightTrace.Hit and leftTrace.Hit)
    self.isCliffedDirection = (rightTrace.Hit and "left") or (leftTrace.Hit and "right") or false

    return self.isCliffed
end

--- Check if we're "cliffed" this tick. Basically this just means "is one of our strafe directions next to an edge?"
---@return boolean
function BotLocomotor:GetIsCliffed()
    return self.isCliffed
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

    self:SetJumping(trce1.Hit and not (trce1.Entity and (trce1.Entity:IsPlayer() or trce1.Entity:IsDoor())))
    self:SetStrafe(
        (trce2.Hit and "left") or
        (trce3.Hit and "right") or
        nil
    )

    if math.random(1, 5) == 3 then
        self:SetJumping(true)
    end

    if not (trce1.Hit or trce2.Hit or trce3.Hit) then
        -- We are still stuck but we can't figure out why. Just strafe in a random direction based off of the current tick.
        local direction = (self.tick % 20 == 0) and "left" or "right"
        self:SetStrafe(direction)
    end
end

--- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function BotLocomotor:UpdateMovement()
    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetUsing(false)
    self:OverrideMoveNormal(nil)
    self:StopPriorityMovement()
    self.tryingMove = false
    self:SetIsCliffed()
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
        local dvlpr_door = lib.GetConVarBool("debug_doors")
        if dvlpr_door then print(self.bot:Nick() .. " opening door") end

        self:SetUsing(true)
        if not self.doorStandPos then
            local vec = self:GetWhereStandForDoor(door)
            local duration = 0.9
            self:TimedVariable("doorStandPos", vec, duration)
            self:TimedVariable("targetDoor", door, duration)
        end

        -- Above if sttement ensures doorStandPos is not nil
        local res = self:SetPriorityGoal(self.doorStandPos, 8)
        if res then
            self:TimedVariable('dontmove', true, 0.4)
        end
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

function BotLocomotor:CanSeeAnyNodesWithinDist(path, range)
    for i, nav in pairs(path) do
        local center = nav:GetCenter()
        if self.bot:VisibleVec(center) and (center:Distance(self.bot:GetPos()) < range) then
            return true
        end
    end
    return false
end

--- Update the path. Requests a path from our current position to our goal position.
---@return string status Status of the pathing, mostly flavor/debugging text.
function BotLocomotor:UpdatePath()
    self.cantReachGoal = false
    self.pathInfoWaiting = false
    if self.dontmove then return "dont_move" end
    local goalPos = self:GetGoalPos()
    if goalPos == nil then return "no_goalpos" end
    if not lib.IsPlayerAlive(self.bot) then return "bot_dead" end

    local path = self:GetPath()
    local goalNav = navmesh.GetNearestNavArea(goalPos)
    local pathLength = self:GetPathLength()

    local hasPath = self:HasPath()
    local endIsGoal = hasPath
        and path.path.path[self:GetPathLength()] == goalNav -- true if we already have a path to the goal
    if hasPath and endIsGoal and not self:CanSeeAnyNodesWithinDist(path.path.path, 500) then
        local dvlpr = lib.GetConVarBool("debug_pathfinding")
        if dvlpr then print(self.bot:Nick() .. " path is too far") end
        -- return "path_too_far"
    elseif (hasPath and pathLength > 0 and endIsGoal) then
        return "pathing_currently"
    end


    if not lib.IsPlayerAlive(self.bot) then return "bot_dead" end
    -- If we don't have a path, request one
    local pathid, path, status = TTTBots.PathManager.RequestPath(self.bot, self.bot:GetPos(), goalPos, false)

    local fr = string.format

    if (path == false or path == nil) then -- path is impossible
        self.cantReachGoal = true
        self.pathInfoWaiting = false
        self.pathInfo = nil
        return "path_impossible"
    elseif (path == true) then
        self.pathInfoWaiting = true
        return "path_pending"
    else -- path is a table
        self.pathInfo = {
            path = path,
            pathid = pathid,
            processedPath = path.processedPath,
            pathIndex = 1, -- the index of the next path node to go to
            owner = self.bot,
        }
        self.pathInfoWaiting = false
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

function BotLocomotor:VisionTestWorldMask(startPos, endPos)
    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        mask = MASK_SOLID_BRUSHONLY,
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
    if not pathinfo or not pathinfo.path or not pathinfo.processedPath then return nil end
    local purePath = pathinfo.path
    local prepPath = pathinfo.processedPath

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
    -- if lastCompleted and not self:VisionTestWorldMask(botEyePos, lastCompleted.pos + Vector(0, 0, 16)) and not self:VisionTestWorldMask(botEyePos, nextUncompleted.pos + Vector(0, 0, 16)) then
    --     lastCompleted.completed = false
    --     if dvlpr then print("Bot " .. self.bot:Nick() .. " is stuck, marking last completed node as uncompleted") end
    --     return nil, lastCompleted -- return nil because if we return DetermineNextPos we will soft lock
    -- end

    local nextPos = nextUncompleted.pos

    local distXY = lib.DistanceXY(botPos, nextPos)
    local distZ = math.abs(botPos.z - nextPos.z)
    -- local dist = self:GetXYDist(botPos, nextPos)
    local canSee = self:VisionTestWorldMask(botEyePos, nextPos + Vector(0, 0, 16))
    if
        (distZ > NEXTPOS_COMPLETE_DIST_VERTICAL_THRESH and distXY < NEXTPOS_COMPLETE_DIST_VERTICAL_RANGE)
        or (distXY < NEXTPOS_COMPLETE_DIST_CANSEE and canSee)
        or distXY < NEXTPOS_COMPLETE_DIST_CANTSEE
    then
        nextUncompleted.completed = true
        return self:DetermineNextPos()
    end

    return nextPos, nextUncompleted
end

--- If there are any blocking entities, aim our crowbar and IN_ATTACK at them
---@deprecated This should be a behavior and should not be in the locomotor
function BotLocomotor:DestroyBlockingEntities()
    local bot = self.bot
    local obtracker = bot.components.obstacletracker
    local breakable = obtracker:GetBlockingBreakable()

    if not breakable or not IsValid(breakable) then return end

    self:AimAt(breakable:GetPos(), 0.5)
    self:SetAttack(true, 0.5)
    bot.components.inventorymgr:EquipMelee()
end

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    local hasPath = self:HasPath()
    if not (hasPath) then return false end
    if self.goalPos and self:GetXYDist(self.goalPos, self.bot:GetPos()) < 32 then return false end
    -- TTTBots.DebugServer.DrawCross(self.goalPos, 10, Color(255, 0, 255), 0.15, "GoalFor" .. self.bot:Nick())
    -- TTTBots.DebugServer.DrawLineBetween(self.bot:GetPos(), self.goalPos, Color(255, 0, 255), 0.15,
    --     "GoalLineFor" .. self.bot:Nick())
    local dvlpr = lib.GetDebugFor("pathfinding")
    local bot = self.bot
    local pathInfo = self:GetPath()

    local processedPath = pathInfo.processedPath
    if not processedPath or #processedPath == 0 then return false end

    -- Check if impossible
    local isImpossible = TTTBots.PathManager.impossiblePaths[pathInfo.pathid] ~= nil
    -- print(self.bot:Nick(), pathInfo.pathid, isImpossible)
    if isImpossible then
        return false
    end
    -- PrintTable(self:GetPath())

    if dvlpr and processedPath then
        for i = 1, #processedPath - 1 do
            local p1 = i == 1 and bot:GetPos() or processedPath[i].pos
            TTTBots.DebugServer.DrawLineBetween(p1, processedPath[i + 1].pos, Color(0, 125, 255))
            -- Instead draw a vertical red line of length 72:
            TTTBots.DebugServer.DrawLineBetween(processedPath[i].pos, processedPath[i].pos + Vector(0, 0, 32),
                Color(255, 0, 0))
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
        local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
        TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
    end

    -- self:DestroyBlockingEntities()

    return true
end

function BotLocomotor:IsFalling()
    local vel = self.bot:GetVelocity()
    return vel.z < -100
end

function BotLocomotor:UpdateViewAngles(cmd)
    local override = self:GetLookPosOverride()
    if override then
        self.lookPosGoal = override
        self:UpdateEyeAnglesFinal()
        return
    end

    local processedPath = self:HasPath() and self:GetPath().processedPath
    local goal = self.goalPos

    if self.nextPos then
        if self:IsFalling() and not self:IsOnLadder() then
            self.lookPosGoal = self.nextPos
            self:UpdateEyeAnglesFinal()
            return
        end

        local nextPosNormal = (self.nextPos - self.bot:GetPos()):GetNormal()
        local outwards = self.bot:GetPos() + nextPosNormal * 1200
        self:GetSetTimedVariable("randomLook", outwards, math.random(0.5, 2))

        -- do an eyetrace to see if there is something directly ahead of us
        local eyeTrace = self.bot:GetEyeTrace()
        local eyeTracePos = eyeTrace.HitPos
        local eyeTraceDist = eyeTracePos and eyeTracePos:Distance(self.bot:GetPos())
        local wallClose = eyeTraceDist and eyeTraceDist < 100

        if wallClose then self.randomLook = nil end

        -- Check if there are any plys nearby and look at the closest one if there are, instead of looking at the random look pos
        if not self.randomLookOverride and not self.RLOStop and not self.stopLookingAround then
            local plys = player.GetAll()
            local plysNearby = {}
            for i, ply in pairs(plys) do
                if not lib.IsPlayerAlive(ply) then continue end
                if ply == self.bot then continue end
                if self.bot:Visible(ply) then
                    table.insert(plysNearby, ply)
                end
            end
            if #plysNearby > 0 then
                -- local ply, plyDist = lib.GetClosest(plysNearby, self.bot:GetPos())
                local ply = table.Random(plysNearby)
                local firstWithin = lib.GetFirstCloserThan(plysNearby, self.bot:GetPos(), 200)
                if firstWithin then ply = firstWithin end

                self:TimedVariable("randomLookOverride", ply, math.random(10, 30) / 10)
                self:TimedVariable("RLOStop", true, math.random(4, 30))
            end
        end

        if self.randomLookOverride ~= nil and IsValid(self.randomLookOverride) then
            self.randomLook = self.randomLookOverride:GetPos() + Vector(0, 0, 64)
            if not self.bot:Visible(self.randomLookOverride) then self.randomLookOverride = nil end
        end

        self.lookPosGoal = (
            (self.randomLookOverride and self.randomLook)
            or (not wallClose and self["randomLook"])
            or (wallClose and self.nextPos + Vector(0, 0, 64))
            or goal
        )
    end

    local dvlpr_door = lib.GetDebugFor("doors")

    if self:IsOnLadder() then
        self.lookPosGoal = self.nextPos
    elseif IsValid(self.targetDoor) then
        local doorCenter = self.targetDoor:WorldSpaceCenter()
        if dvlpr_door then print(self.bot:Nick() .. " is looking at blocking door " .. self.targetDoor:EntIndex()) end
        self.lookPosGoal = doorCenter
        -- else
        --     local nearbyDoor = self:DetectDoorNearby()
        --     if nearbyDoor then
        --         if dvlpr_door then print(self.bot:Nick() .. " is looking at nearby door " .. nearbyDoor:EntIndex()) end
        --         self.lookPosGoal = nearbyDoor:WorldSpaceCenter()
        --     end
    end

    if not self.lookPosGoal then return end

    self:UpdateEyeAnglesFinal()

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

    self.movementVec = (self.movementVec and LerpVector(factor, self.movementVec, goal)) or goal
end

function BotLocomotor:StartAttack()
    self.attack = true
end

function BotLocomotor:StopAttack()
    self.attack = false
end

--- Sets self.reload to true, queuing a reload the next frame.
function BotLocomotor:Reload()
    self.reload = true
end

---@deprecated see StartAttack and StopAttack: these are untimed and generally neater.
function BotLocomotor:SetAttack(attack, time)
    self.attack = attack
    if time then
        self.attackReleaseTime = CurTime() + time
    end
end

function BotLocomotor:StartCommand(cmd) -- aka StartCmd
    cmd:ClearButtons()
    cmd:ClearMovement()
    if self.dontmove then return end
    if not lib.IsPlayerAlive(self.bot) then return end

    local hasPath = self:HasPath()
    local DVLPR_PATHFINDING = lib.GetDebugFor("pathfinding")

    local TIMESTAMP = CurTime()
    local MYPOS = self.bot:GetPos()


    -- SetButtons to IN_DUCK if crouch is true 🦆
    cmd:SetButtons(
        (self:GetCrouching() or self:GetJumping()) and IN_DUCK or 0
    )

    --- 🦘 Set buttons for jumping if :GetJumping() is true
    --- The way jumping works is a little quirky, as it cannot be held down. We must release it occasionally
    if self:GetJumping() and (self.jumpReleaseTime < TIMESTAMP) or self.jumpReleaseTime == nil then
        local onGround = self.bot:OnGround()
        if not onGround then
            cmd:SetButtons(IN_JUMP + IN_DUCK)
        else
            cmd:SetButtons(IN_JUMP)
        end
        self.jumpReleaseTime = TIMESTAMP + 0.1

        if DVLPR_PATHFINDING then
            TTTBots.DebugServer.DrawText(MYPOS, "Crouch Jumping", Color(255, 255, 255))
        end
    end

    --- 🏃 WALK TOWARDS NEXT POSITION ON PATH (OR IMMEDIATE PRIORITY GOAL), IF WE HAVE ONE
    if self:HasPath() and not self:GetPriorityGoal() then
        self:LerpMovement(0.1, self.nextPos)
    elseif self:GetPriorityGoal() then
        self:LerpMovement(0.1, self:GetPriorityGoal())
        if DVLPR_PATHFINDING then TTTBots.DebugServer.DrawCross(self.movePriorityVec, 10, Color(0, 255, 255)) end
    end

    --- 🏃 MANAGE REPEL FORCES
    if self.repelled then
        local normal = self.repelDir
        local endTime = self.repelStopTime
        local repelPos = (normal * 75) + MYPOS

        if endTime < TIMESTAMP then
            self.repelled = false
        else
            self:LerpMovement(0.15, repelPos) -- Much more emphasis on the repel than normal movement patterns.
        end
    end

    -- If there is a movement vector,
    if self.movementVec then
        local dist = self:GetXYDist(self.movementVec, MYPOS)
        -- If the distance is less than 16, set the movement vector to nil. We have reached our destination.
        if dist < 16 then
            self.movementVec = nil
        else
            -- Calculate the movement angles using the movement vector and the bot's position
            local ang = (self.movementVec - MYPOS):Angle()
            -- If debug mode is enabled, draw a cross at the movement vector
            if DVLPR_PATHFINDING then
                TTTBots.DebugServer.DrawCross(self.movementVec, 5, Color(255, 255, 255), nil,
                    self.bot:Nick() .. "movementVec")
            end
            -- Set the view angles using the movement angles
            cmd:SetViewAngles(ang)
        end
    end

    --- 📷 SET VIEW ANGLES USING UpdateViewAngles HELPER FUNCTION
    self:UpdateViewAngles(cmd) -- The real view angles

    --- 🏃 STRAFESTR FOR LADDER + STRAFE CALCS
    local strafeStr = self:GetStrafe()

    --- 🪜 MANAGE LADDER MOVEMENT
    if self:IsOnLadder() then -- Ladder movement
        local strafe_dir = (strafeStr == "left" and IN_MOVELEFT) or (strafeStr == "right" and IN_MOVERIGHT) or
            0
        cmd:SetButtons(IN_FORWARD + strafe_dir)

        return
    end

    --- 🏃 STRAFE CALCULATIONS
    local side = cmd:GetSideMove()
    side = (strafeStr == "left" and -400)
        or (strafeStr == "right" and 400)
        or 0
    local forceForward = self:GetForceForward() or self.repelled
    local dbgStrafe = lib.GetConVarBool("debug_strafe")
    if dbgStrafe then
        if strafeStr ~= nil then
            -- Draw a line towards the direction of our strafe, out 100 units.
            local strafePos = MYPOS + (self.bot:GetRight() * 100 * (side == -400 and -1 or 1))
            TTTBots.DebugServer.DrawLineBetween(MYPOS, strafePos, Color(255, 0, 0))
        end

        if forceForward and self.movementVec then
            -- Draw a line forward 100 units
            local forwardPos = MYPOS + (self.bot:GetForward() * 100)
            TTTBots.DebugServer.DrawLineBetween(MYPOS, forwardPos, Color(0, 255, 0))
        end
    end

    --- 🏃 MANAGE MOVEMENT SIDE/FORWARD
    local forward = self.movementVec == nil and 0 or 400
    cmd:SetSideMove(side)
    cmd:SetForwardMove((not forceForward and forward) or 400)

    -- Set up movement to always be up. This doesn't seem to do much tbh
    cmd:SetUpMove(400)

    --- 🚪 MANAGE BOT DOOR HANDLING
    if self:GetUsing() and self:DoorOpenTimer() then
        if DVLPR_PATHFINDING then
            TTTBots.DebugServer.DrawText(MYPOS, "Opening door", Color(255, 255, 255))
        end
        cmd:SetButtons(cmd:GetButtons() + IN_USE)
    end

    --- 🔫 MANAGE ATTACKING OF THE BOT
    if ((self.reactionDelay or 0) < TIMESTAMP) then
        if (self.attack and not self.attackReleaseTime) or                                       -- if we are attacking and we don't have an attack release time
            (self.attack and self.attackReleaseTime and self.attackReleaseTime > TIMESTAMP) then -- or if we are attacking and we have an attack release time and it's not yet time to release:
            -- stop attack from interrupting reload
            local currentWep = self.bot.components.inventorymgr:GetHeldWeaponInfo()
            if (currentWep and (not currentWep.needs_reload)) or not currentWep then
                cmd:SetButtons(cmd:GetButtons() + IN_ATTACK)
            end
        end
    end

    --- 🔫 MANAGE RELOADING OF THE BOT
    if self.reload then
        cmd:SetButtons(cmd:GetButtons() + IN_RELOAD)
        self.reload = false
    end

    -- TODO: use IN_RUN to sprint around. cannot be held down constantly or else it won't work.
    cmd:SetButtons(cmd:GetButtons())

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
    local bots = TTTBots.Bots

    ---------------------------
    -- Update stuckBots table
    ---------------------------
    for i, bot in pairs(bots) do
        if not (bot and lib.IsPlayerAlive(bot)) then continue end
        local locomotor = lib.GetComp(bot, "locomotor")
        if not locomotor then continue end
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

timer.Create("TTTBots.Locomotor.lookPosOverride.ForgetOverride", 1.0 / TTTBots.Tickrate, 0, function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (bot and bot.components and bot.components.locomotor) then continue end
        local loco = bot.components.locomotor
        local endTime = loco.lookPosOverrideEnd
        if endTime and endTime < CurTime() then
            loco.lookPosOverride = nil
            loco.lookPosOverrideEnd = nil
        end
    end
end)

local plyMeta = FindMetaTable("Player")

function plyMeta:SetAttackTarget(target)
    if self.attackTarget == target then return end
    local plyIsEvil = lib.IsEvil(self)
    local targIsEvil = lib.IsEvil(target)
    if (plyIsEvil and targIsEvil) then return end -- don't attack traitors!
    self.attackTarget = target
    local loco = lib.GetComp(self, "locomotor")
    local personality = lib.GetComp(self, "personality")
    if not (loco and personality) then return end
    loco:OnNewTarget(target)
    personality:OnPressureEvent("NewTarget")
end
