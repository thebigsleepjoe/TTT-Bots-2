--[[
This component is how the bot gets to something. It does not create the paths, it just follows them.
]]
---@class CLocomotor : Component
TTTBots.Components.Locomotor = {}

local lib = TTTBots.Lib
---@class CLocomotor : Component
local BotLocomotor = TTTBots.Components.Locomotor

-- Define constants
local COMPLETION_DIST_HORIZONTAL = 30
local COMPLETION_DIST_VERTICAL = 48


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

--- Create and return a get and set function on variable varname, defaulting to the 'default' value
---@param varname string
---@param default any
---@return function getFunc
---@return function setFunc
local function getSet(varname, default)
    local setFunc = function(self, value)
        self["m_" .. varname] = value
    end
    local getFunc = function(self)
        if self["m_" .. varname] == nil then
            self["m_" .. varname] = default
        end
        return self["m_" .. varname]
    end

    return getFunc, setFunc
end

---@package
function BotLocomotor:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.locomotor = self

    self.componentID = string.format("locomotor (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                        -- Tick counter
    self.bot = bot

    self.pathRequest = nil            -- Current path

    self.goalPos = nil                -- Current goal position, if any. If nil, then bot is not moving.

    self.isTryingPath = false         -- If true, then the bot is trying to move to the goal position.
    self.posLastSecond = nil          -- Position of the bot one second ago. Used for pathfinding.

    self.lookGoal = nil               -- Override look position, this is only used from outside of this component. Like aiming at a player.
    self.pathingLookGoal = nil        -- The current goal position to look at
    self.lookPos = nil                -- Current look position, gets interpolated to Override, or to self.lookPosGoal.

    self.movePriorityVec = nil        -- Current movement priority vector, overrides movementVec if not nil
    self.movementVec = nil            -- Current movement position
    self.moveInterpRate = 0.3         -- Current movement speed (rate of lerp)
    self.moveNormal = Vector(0, 0, 0) -- Current movement normal, functionally this is read-only.

    self.strafe = nil                 -- "left" or "right" or nil
    self.strafeTimeout = 0            -- The next tick our strafe will time out on, which is when it will be set to nil.
    self.forceForward = false         -- If true, then the bot will always move forward

    self.stopLookingAround = false    -- If true, then the bot will stop looking around

    self.crouch = false
    self.jump = false
    self.dontmove = false

    self.doorStandPos = nil
    self.targetDoor = nil

    self.GetClimbDir, self.SetClimbDir = getSet("ClimbDir", "none")
    self.GetDismount, self.SetDismount = getSet("Dismount", true)

    self:EnableCanADS()
end

---@package
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
    return self.moveNormal
end

function BotLocomotor:GetPriorityGoal()
    return self.movePriorityVec or false
end

--- Functionally assigns movePriorityVec to the given vector, if not within a certain range
---@param vec Vector
---@param range number? defaults to 32
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
---@return PathRequest|nil
function BotLocomotor:GetPathRequest()
    return self.pathRequest
end

---@return boolean
function BotLocomotor:HasPath()
    return type(self.pathRequest) == "table" and type(self.pathRequest.pathInfo) == "table"
end

function BotLocomotor:GetPathLength()
    if not self:HasPath() then return 0 end
    if type(self:GetPathRequest()) ~= "table" then return 0 end
    if not (self.pathRequest and self.pathRequest.pathInfo and self.pathRequest.pathInfo.path and type(self.pathRequest.pathInfo.path) == "table") then return 0 end
    -- # operator does not work here for some reason so count the old way
    return table.Count(self.pathRequest.pathInfo.path)
end

---@return boolean
function BotLocomotor:IsWaitingForPath()
    return self.pathRequestWaiting
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
--- Decays the lookSpeedMultiplier value by LOOKSPEEDMULT_DECAYRATE to the bot's decay goal (usually 1). Used internally.
---@package
function BotLocomotor:DecayLookSpeedMultiplier()
    local current = (self.lookSpeedMultiplier or 1)
    local decayGoal = 1
    if current == decayGoal then return decayGoal end -- very minor optimization
    self.lookSpeedMultiplier = math.max(current * LOOKSPEEDMULT_DECAYRATE, decayGoal)

    return self.lookSpeedMultiplier
end

---@package
function BotLocomotor:OnNewTarget(target)
    if not (target and IsValid(target)) then return end

    -- REACTION DELAY
    local REACTION_SPEED_BASE = lib.GetConVarFloat("reaction_speed")
    local DIFFICULTY = lib.GetConVarInt("difficulty")
    local DIFFICULTY_MULTIPLIERS = {
        [1] = 3,
        [2] = 2,
        [3] = 1,
        [4] = 0.6,
        [5] = 0,
    }
    local TRAITORS_REACT_QUICKER = lib.GetConVarBool("cheat_traitor_reactionspd")
    if TRAITORS_REACT_QUICKER and self.bot:GetTeam() == TEAM_TRAITOR then
        REACTION_SPEED_BASE = REACTION_SPEED_BASE * 0.5
    end
    local DIFFICULTY_MULT = DIFFICULTY_MULTIPLIERS[DIFFICULTY] or 1
    local reactionSpeed = REACTION_SPEED_BASE * DIFFICULTY_MULT
    self.reactionDelay = CurTime() + reactionSpeed

    -- Simulate a 'flick'
    local BOTS_FLICK = lib.GetConVarBool("flicking")
    if BOTS_FLICK then
        self.lookSpeedMultiplier = 5
    end
end

---Rotates the current eye angles to face targetPos. This is used internally and should not be called from outside of this component.
---@param targetPos Vector
---@package
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

--- This is the function responsible for properly changing the eye angles of the bot on the server's side.
---@package
function BotLocomotor:UpdateEyeAnglesFinal()
    if self.pathingLookGoal == nil then return end
    self.lookPos = self:GetLookGoal() or self:GetPathingLookGoal() or self.lookPos

    -- self:LerpEyeAnglesFinal()
    self:RotateEyeAnglesTo(self.lookPos)
end

--- Aims at a given pos for "time" seconds (optional). If no time, then one-time set.
---@param pos Vector
---@param time number|nil
function BotLocomotor:LookAt(pos, time)
    if not time then time = 1 end
    self:SetLookGoal(pos)
    self.lookGoalStopTime = CurTime() + time
end

-- Getters and setters, just for formality and easy reading.
function BotLocomotor:Crouch(bool) self.crouch = bool end

function BotLocomotor:Jump(bool) self.jump = bool end

--- Order the bot to stop where it is.
---@param bool boolean
function BotLocomotor:SetHalt(bool) self.dontmove = bool end

--- Sets the current look target. Use :LookAt to set this from outside of this component.
---@see LookAt
---@package
function BotLocomotor:SetLookGoal(pos) self.lookGoal = pos end

---@package
function BotLocomotor:ClearLookGoal() self.lookGoal = nil end

--- Set the direction of our strafing to either "left", "right", or nil. Non-nil values timeout after 2 ticks.
---@param direction string|nil the strafe direction, or nil for none.
function BotLocomotor:Strafe(direction)
    if type(direction) == "number" then
        print("Strafe direction cannot be a number")
        return
    end
    if direction then self.strafeTimeout = self.tick + (TTTBots.Tickrate) end -- expire after 1 second
    self.strafe = direction
end

function BotLocomotor:SetForceForward(value)
    if value then self.forceForwardTimeout = self.tick + (TTTBots.Tickrate) end -- expire after 1 second
    self.forceForward = value
end

function BotLocomotor:SetRandomStrafe()
    local options = {
        "left", "right"
    }
    self:Strafe(table.Random(options))
end

function BotLocomotor:SetGoal(pos) self.goalPos = pos end

function BotLocomotor:SetUse(bool) self.emulateInUse = bool end

function BotLocomotor:IsTryingCrouch() return self.crouch end

function BotLocomotor:IsTryingJump() return self.jump end

function BotLocomotor:IsHalted() return not self.dontmove end

function BotLocomotor:GetLookGoal() return self.lookGoal end

function BotLocomotor:GetPathingLookGoal() return self.pathingLookGoal end

--- Returns the current position we are looking at by performing an eyetrace. Returns HitPos or nil if none.
---@return Vector|unknown
function BotLocomotor:GetCurrentLookPos() return self.lookPos or self.bot:GetEyeTrace().HitPos end

--- Sets self.strafe to nil if strafeTimeout has been reached; returns self.strafe
---@return string|nil
function BotLocomotor:VerifyStrafeTimeout()
    if (self.strafeTimeout or 0) < self.tick then
        self:Strafe(nil)
        -- print(string.format("strafe timeout; %d vs %d", self.strafeTimeout, self.tick))
    end
    return self.strafe
end

--- Sets self.forceForward to nil if forceForwardTimeout has been reached; returns self.forceForward
---@return boolean|nil
function BotLocomotor:VerifyForwardTimeout()
    if (self.forceForwardTimeout or 0) < self.tick then
        self:SetForceForward(nil)
        -- print(string.format("ForceForward timeout; %d vs %d", self.ForceForwardTimeout, self.tick))
    end
    return self.forceForward
end

---@return string|nil
function BotLocomotor:GetStrafe()
    return self:VerifyStrafeTimeout()
end

---@return boolean|nil
function BotLocomotor:GetForceForward()
    return self:VerifyForwardTimeout()
end

function BotLocomotor:SetForceBackward(value)
    self.forceBackward = value
end

function BotLocomotor:GetForceBackward()
    return self.forceBackward
end

function BotLocomotor:GetGoal()
    return self.goalPos
end

function BotLocomotor:StopMoving()
    self:SetGoal(nil)
    self:SetUse(false)
    self:Strafe(nil)
    self:Jump(false)
    self:Crouch(false)
    self:SetLookGoal(nil)
    self.pathRequest = nil
    self.randomLookEntityStopTime = nil
    self.randomLook = nil
    self.movePriorityVec = nil
    self.movementVec = nil
end

function BotLocomotor:GetUsing() return self.emulateInUse end

--- Prop and player avoidance
function BotLocomotor:EnableAvoid()
    self.dontAvoid = false
end

--- Prop and player avoidance
function BotLocomotor:DisableAvoid()
    self.dontAvoid = true
end

function BotLocomotor:IsAvoid()
    return not self.dontAvoid
end

function BotLocomotor:WithinCompleteRange(pos)
    return self.bot:GetPos():Distance(pos) < TTTBots.PathManager.completeRange
end

---Return the nearest ladder and distance to
---@return CNavLadder ladder
---@return number distance
function BotLocomotor:GetClosestLadder()
    return lib.GetClosestLadder(self.bot:GetPos())
end

function BotLocomotor:IsOnLadder()
    return self.bot:GetMoveType() == MOVETYPE_LADDER
end

--- Performs a trace to check if the bot's feet are obstructed by anything, according to the movement direction (not facing dir)
---@return boolean
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

    return trce.Hit and not (trce.Entity and (trce.Entity:IsPlayer() or lib.IsDoor(trce.Entity)))
end

function BotLocomotor:ShouldJump()
    return self:CheckFeetAreObstructed() or (math.random(1, 100) == 1 and self:IsStuck())
end

function BotLocomotor:ShouldCrouchBetween(a, b)
    if not a or not b then return false end
    local area1 = navmesh.GetNearestNavArea(a)
    local area2 = navmesh.GetNearestNavArea(b)

    return (area1 and area1:IsCrouch()) or (area2 and area2:IsCrouch())
end

--- Test if the bot is close enough to pos to stop maneuvering to it.
---@param pos Vector
---@return boolean
function BotLocomotor:IsCloseEnough(pos)
    return TTTBots.PathManager.BotIsCloseEnough(self.bot, pos)
end

--- Detect if there is a door ahead of us. Runs a trace towards where we are currently moving towards.
-- TODO: Use view angles instead of movement angles?
function BotLocomotor:DetectDoorAhead()
    local off = Vector(0, 0, 16)
    local npTrace = util.TraceLine({
        start = self.bot:GetPos() + off,
        endpos = (self.bot:GetPos() + self:GetMoveNormal() * 100) + off,
        filter = self.bot
    })

    if npTrace.Hit then
        local ent = npTrace.Entity

        if IsValid(ent) and lib.IsDoor(ent) then
            return ent
        end
    end

    return false
end

---Tries to find any doors in a sphere around ourselves. Returns the closest elsewhere nil.
---@return Entity|nil
function BotLocomotor:DetectDoorNearby()
    local range = 100
    local pos = self.bot:GetPos()
    local doors = {}
    for i, ent in pairs(ents.FindInSphere(pos, range)) do
        if IsValid(ent) and lib.IsDoor(ent) then
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
---@package
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
---@package
function BotLocomotor:GetSetTimedVariable(name, value, time)
    if self[name] then return true end

    self:TimedVariable(name, value, time)
    return false
end

--- Used to prevent spamming of doors.
--- Calling this function returns a bool. True if can use again. If it returns true, it starts the timer.
--- Otherwise it returns false, and does nothing
---@package
function BotLocomotor:TestDoorTimer()
    -- if self.cantUseAgain then return false end

    -- self:TimedVariable("cantUseAgain", true, 1.2)
    -- return true
    return not self:GetSetTimedVariable("cantUseAgain", true, 1.2)
end

function BotLocomotor:UpdateADS()
    local bot = self.bot
    if IsValid(bot) and IsValid(bot.attackTarget) then
        local target = bot.attackTarget
        local shouldAim = bot:Visible(target)
        local distToTarget = bot:GetPos():Distance(target:GetPos())
        local pitchDiff, yawDiff = self:GetEyeAngleDiffTo(target:GetPos())
        if distToTarget < 200 or yawDiff > 25 then shouldAim = false end
        self:SetIsADS(shouldAim)
    else
        self:SetIsADS(false)
    end
end

--- Tick periodically. Do not tick per GM:StartCommand
function BotLocomotor:Think()
    self.tick = self.tick + 1
    local status = self:UpdatePathRequest() -- Update the path that the bot is following, so that we can move along it.
    self.status = status
    self:UpdateMovement()                   -- Update the invisible angle that the bot moves at, and make it move.
    self:TickViewAngles()                   -- The real view angles
    self:UpdateADS()
end

--- Gets nearby players then determines the best direction to strafe to avoid them.
function BotLocomotor:AvoidPlayers()
    if self.dontAvoid then return end
    if self:IsCliffed() then return end -- don't let trolls push us off the map...
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

        if dist < 45 then
            nearbyClumpCenter = nearbyClumpCenter + plypos
            nearbyClumpCount = nearbyClumpCount + 1
        end
    end

    if nearbyClumpCount == 0 then return end

    -- Get the clump position & try to navigate away from it
    local clumpPos = nearbyClumpCenter / nearbyClumpCount
    local clumpBackward = -self:GetNormalBetween(pos, clumpPos)

    self:SetRepelForce(clumpBackward, 0.3)
end

--- Returns the normal vector from pos1 to pos2. Basically this is just a normalized vector pointing from A to B.
---@param pos1 Vector
---@param pos2 Vector
---@return Vector normal
function BotLocomotor:GetNormalBetween(pos1, pos2)
    local dir = (pos2 - pos1):GetNormalized()
    return dir
end

--- Pause all repel-related behaviors. AKA, stop moving away from nearby players.
function BotLocomotor:PauseRepel()
    self.pauseRepel = true
end

--- Resume all repel-related behaviors.
function BotLocomotor:ResumeRepel()
    self.pauseRepel = false
end

---@package
function BotLocomotor:SetRepelForce(normal, duration)
    if self.pauseRepel then
        self:StopRepel()
        return
    end
    self.repelDir = normal
    self.repelStopTime = CurTime() + (duration or 1.0)
    self.repelled = true
end

---@package
function BotLocomotor:StopRepel()
    self.repelDir = nil
    self.repelStopTime = nil
    self.repelled = false
end

function BotLocomotor:CanADS()
    return self.ads
end

function BotLocomotor:DisableCanADS()
    self.ads = false
end

function BotLocomotor:EnableCanADS()
    self.ads = true
end

--- Determine if we're "Cliffed" (i.e., on the edge of something)
--- by doing two traces to our right and left, starting from EyePos and ending 100 units down, offset by 50 units to the right or left.
---@return boolean Cliffed True if we're cliffed (on the edge of something), false if we're not.
---@package
function BotLocomotor:SetCliffed()
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
function BotLocomotor:IsCliffed()
    return self.isCliffed
end

---@package
function BotLocomotor:TryUnstick()
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

    self:Jump(false)
    self:Crouch(false)

    self:Jump(trce1.Hit and not (trce1.Entity and (trce1.Entity:IsPlayer() or lib.IsDoor(trce1.Entity))))
    self:Strafe(
        (trce2.Hit and "left") or
        (trce3.Hit and "right") or
        nil
    )

    if math.random(1, 5) == 3 then
        self:Jump(true)
    end

    if not (trce1.Hit or trce2.Hit or trce3.Hit) then
        -- We are still stuck but we can't figure out why. Just strafe in a random direction based off of the current tick.
        local direction = (self.tick % 20 == 0) and "left" or "right"
        self:Strafe(direction)
    end
end

---An UpdateMovement function that is passes a door entity and will set a priority goal to evade it if it is in the way.
---@param door any
---@package
function BotLocomotor:AvoidDoor(door)
    if self.dontAvoid then return end
    local dvlpr_door = lib.GetConVarBool("debug_doors")
    if dvlpr_door then print(self.bot:Nick() .. " opening door") end

    self:SetUse(true)
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

---Order the locomotor to path directly towards goal if we are close enough (aka on the same nav area). Uses the priority goal system.
---@param goal Vector
---@package
function BotLocomotor:MoveDirectlyIfClose(goal)
    -- check goal navarea is same as bot:GetPos() nav area
    local botArea = navmesh.GetNearestNavArea(self.bot:GetPos())
    local goalArea = navmesh.GetNearestNavArea(goal)
    if (botArea == goalArea) then
        --self:LerpMovement(0.1, goal)
        self:SetPriorityGoal(goal)
        self.isTryingPath = true
    end
end

function BotLocomotor:ValidateGoalProx()
    local goal = self:GetGoal()

    if not IsValid(goal) then return end

    if self:IsCloseEnough(goal) then
        self:SetGoal(nil)
    end
end

--- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
---@package
function BotLocomotor:UpdateMovement()
    self:Jump(false)
    self:Crouch(false)
    self:SetUse(false)
    self:StopPriorityMovement()
    self.isTryingPath = false
    self:SetCliffed()
    self:ValidateGoalProx()
    if self.dontmove then return end

    self:SetDismount(self:ShouldDismountLadder())

    local followingPath = self:FollowPath() -- true if doing proper pathing
    self.isTryingPath = followingPath
    -- Walk straight towards the goal if it doesn't require complex pathing.
    local goal = self:GetGoal()

    if goal and not followingPath and not self:IsCloseEnough(goal) then
        self:MoveDirectlyIfClose(goal)
    end

    self:AvoidPlayers()
    -----------------------
    -- Unstuck code
    -----------------------

    if not self.isTryingPath then return end

    -- If we're stuck, try to get unstuck.
    if self.tick % 3 == 1 then self:RecordPosition() end
    if self:IsStuck() then
        self:TryUnstick()
    end

    -- self:AvoidObstacles()

    -----------------------
    -- Door code
    -----------------------

    local door = self:DetectDoorAhead()
    if door then
        self:AvoidDoor(door)
    end
end

--- Record the bot's position. This is used for getting the bot unstuck from weird situations.
---@package
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

---Test if any segments along the path are within the given range.
---@param path table
---@param range number
---@return boolean
---@package
function BotLocomotor:AnySegmentsNearby(path, range)
    for i, nav in pairs(path) do
        -- extra safety check
        if not IsValid(nav) then continue end
        local center = nav:GetCenter()
        if self.bot:VisibleVec(center) and (center:Distance(self.bot:GetPos()) < range) then
            return true
        end
    end
    return false
end

---@enum LocoStatus
BotLocomotor.PATH_STATUSES = {
    DONTMOVE = "dont_move",
    NOGOALPOS = "no_goalpos",
    BOTDEAD = "bot_dead",
    PATHTOOFAR = "path_too_far",
    PATHINGCURRENTLY = "pathing_currently",
    IMPOSSIBLE = "path_impossible",
    PENDING = "path_pending",
    READY = "path_ready",
}

--- Represents a request for a path.
---@class PathRequest
---@field pathInfo PathInfo The information about the path being requested.
---@field pathid number The ID of the path.
---@field processedPath table<PathNode> The processed path nodes.
---@field pathIndex number The current index in the path.
---@field owner Player The owner of the path request.

---@class PathNode
---@field area CNavArea|CNavLadder
---@field completed boolean
---@field pos Vector
---@field type string e.g. "walk" or "fall"

---@class PathInfo
---@field TimeSince function A callback that returns the time since the path was generated
---@field generatedAt number The timestamp the path was generated at
---@field path table<CNavArea|CNavLadder> The raw path itself
---@field processedPath table<PathNode> The processed path, with additional information


--- Update the path. Requests a path from our current position to our goal position. Internal function.
---@return LocoStatus status Status of the pathing, mostly flavor/debugging text.
---@package
function BotLocomotor:UpdatePathRequest()
    local STAT = BotLocomotor.PATH_STATUSES
    self.cantReachGoal = false
    self.pathRequestWaiting = false

    if self.dontmove then
        return STAT.DONTMOVE
    end

    local goalPos = self:GetGoal()
    if not goalPos then
        return STAT.NOGOALPOS
    end

    if not lib.IsPlayerAlive(self.bot) then
        return STAT.BOTDEAD
    end

    local pathRequest = self:GetPathRequest() -- can be nil
    local goalNav = navmesh.GetNearestNavArea(goalPos)
    local pathLength = self:GetPathLength()
    local hasPath = self:HasPath()

    local endIsGoal = hasPath and pathRequest and pathRequest.pathInfo.path[pathLength] == goalNav
    if pathRequest and hasPath and endIsGoal and not self:AnySegmentsNearby(pathRequest.pathInfo.path, 500) then
        if lib.GetConVarBool("debug_pathfinding") then
            print(self.bot:Nick() .. " path is too far")
        end
    elseif hasPath and pathLength > 0 and endIsGoal then
        return STAT.PATHINGCURRENTLY
    end

    -- If we don't have a path, request one
    local pathid, pathInfo, status = TTTBots.PathManager.RequestPath(self.bot, self.bot:GetPos(), goalPos, false)

    if not pathInfo then -- path is impossible
        self.cantReachGoal = true
        self.pathRequestWaiting = false
        self.pathRequest = nil
        return STAT.IMPOSSIBLE
    elseif pathInfo == true then
        self.pathRequestWaiting = true
        return STAT.PENDING
    else -- path is a table
        self.pathRequest = {
            pathInfo = pathInfo,
            pathid = pathid,
            processedPath = pathInfo.processedPath,
            pathIndex = 1, -- the index of the next path node to go to
            owner = self.bot,
        }
        self.pathRequestWaiting = false
        return STAT.READY
    end
end


--- Do a traceline from startPos to endPos, with no specific mask (hit anything). Filter out ourselves.
--- Returns if we can see the endPos without interruption
--TODO: Move to botlib
function BotLocomotor:TestVisionNoMask(startPos, endPos)
    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = self.bot,
    })
    return not trace.Hit -- true if we can see the endPos
end

--TODO: Move to botlib
function BotLocomotor:TestVisionWorldMask(startPos, endPos)
    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        mask = MASK_SOLID_BRUSHONLY,
        filter = self.bot,
    })
    return not trace.Hit -- true if we can see the endPos
end

--TODO: Move to botlib
function BotLocomotor:DivideIntoSegments(startPos, endPos, units)
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

--TODO: Move to botlib
function BotLocomotor:CanStandAt(pos)
    if util.IsInWorld(pos) then return false end

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

    return not tr.Hit
end

--- Determine the next pos along our current path
---@package
function BotLocomotor:FindNextPos()
    local pathinfo = self:GetPathRequest().pathInfo
    if not pathinfo or not pathinfo.path or not pathinfo.processedPath then return nil end
    local prepPath = pathinfo.processedPath

    local bot = self.bot
    local botPos = bot:GetPos()
    local botEyePos = bot:GetShootPos()

    local nextNode = nil
    local lastCompleted = nil
    for i, v in ipairs(prepPath) do
        if not v.completed then
            nextNode = v
            lastCompleted = prepPath[i - 1]
            break
        end
    end
    if not nextNode then return nil end -- no more nodes to go to

    local nextPos = nextNode.pos
    local distXY = lib.DistanceXY(botPos, nextPos)
    local distZ = math.abs(botPos.z - nextPos.z)

    if (distZ < COMPLETION_DIST_VERTICAL and distXY < COMPLETION_DIST_HORIZONTAL) then
        nextNode.completed = true
        return self:FindNextPos()
    end

    return nextPos, nextNode
end

-- Determines how the bot navigates through its path once it has one.
---@package
function BotLocomotor:FollowPath()
    local hasPath = self:HasPath()
    if not (hasPath) then return false end
    if self.goalPos and self:GetXYDist(self.goalPos, self.bot:GetPos()) < 32 then return false end
    local dvlpr = lib.GetDebugFor("pathfinding")
    local bot = self.bot
    local pathRequest = self:GetPathRequest()

    assert(pathRequest, "pathRequest must NOT be nil")

    local processedPath = pathRequest.processedPath
    if not processedPath or #processedPath == 0 then return false end

    -- Check if impossible
    local isImpossible = TTTBots.PathManager.impossiblePaths[pathRequest.pathid] ~= nil
    -- print(self.bot:Nick(), pathRequest.pathid, isImpossible)
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

    local nextPos, nextPosI = self:FindNextPos()
    self.nextPos = nextPos
    self.nextPosI = nextPosI

    if not self.nextPos then return false end

    if self:ShouldJump() then
        self:Jump(true)
    end

    if self:ShouldCrouchBetween(bot:GetPos(), nextPos) then
        self:Crouch(true)
    end

    if dvlpr then
        assert(nextPos, "nextPos must NOT be nil")
        local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
        TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
    end

    return true
end

function BotLocomotor:IsFalling()
    local vel = self.bot:GetVelocity()
    return vel.z < -100
end

---Functionally sets loco.pathingLookGoal, used for low-priority looking around.
---@param goal Vector
---@package
function BotLocomotor:SetPathingLookGoal(goal)
    self.pathingLookGoal = goal
end

---Return if the bot's face is within 100 units of a wall (or other obstruction).
---@return boolean
function BotLocomotor:IsWallClose()
    local eyeTrace = self.bot:GetEyeTrace()
    local eyeTracePos = eyeTrace.HitPos
    local eyeTraceDist = eyeTracePos and eyeTracePos:Distance(self.bot:GetPos())
    local wallClose = eyeTraceDist and eyeTraceDist < 100

    return wallClose
end

---@return boolean
---@package
function BotLocomotor:HandleFallingLook()
    if self:IsFalling() and not self:IsOnLadder() then
        self.pathingLookGoal = self.nextPos
        return true
    end

    return false
end

--- Sets SetIronsights and SetZoom on the bot's active weapon to bool
---@param bool boolean Whether or not to enable/disable the weapon's ironsights
function BotLocomotor:SetIsADS(bool)
    if not IsValid(self.bot) then return end
    local wep = self.bot:GetActiveWeapon()
    if not IsValid(wep) then return end
    if not wep.SetIronsights then return end
    wep:SetIronsights(bool)
    if not wep.SetZoom then return end
    wep:SetZoom(bool)
end

---@package
function BotLocomotor:SetRandomLookPlayer()
    if self.randomLookEntity or self.randomLookEntityStopTime then
        return false
    end
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
        local ply = table.Random(plysNearby)
        local firstWithin = lib.GetFirstCloserThan(plysNearby, self.bot:GetPos(), 200)
        if firstWithin then ply = firstWithin end

        self:TimedVariable("randomLookEntity", ply, math.random(10, 30) / 10)
        self:TimedVariable("randomLookEntityStopTime", true, math.random(4, 30))

        return true
    end

    return false
end

--- Finds and then looks at a random player in sight
---@return boolean success If we found a player to look at
---@package
function BotLocomotor:TryRandomPlayerLook()
    local success = self:SetRandomLookPlayer()

    if success then
        self.randomLook = self.randomLookEntity:GetPos() + Vector(0, 0, 64)
        if not self.bot:Visible(self.randomLookEntity) then self.randomLookEntity = nil end
    end

    return success
end

--- Wander around with our eyes while we are walking around.
---@return boolean
---@package
function BotLocomotor:HandleRandomWalkLook()
    if not self.nextPos then return false end

    local nextPosNormal = (self.nextPos - self.bot:GetPos()):GetNormal()
    local outwards = self.bot:GetPos() + nextPosNormal * 1200
    self:GetSetTimedVariable("randomLook", outwards, math.random(0.5, 2))

    local wallClose = self:IsWallClose()

    if wallClose then self.randomLook = nil end

    self:TryRandomPlayerLook()

    self.pathingLookGoal = (
        (self.randomLookEntity and self.randomLook)
        or (not wallClose and self.randomLook)
        or self.nextPos + Vector(0, 0, 64)
    )

    return true
end

---@return boolean
---@package
function BotLocomotor:HandleLadderLook()
    if self:IsOnLadder() then
        self.pathingLookGoal = self.nextPos
        return true
    end

    return false
end

---@return boolean
---@package
function BotLocomotor:HandleDoorLook()
    local dvlpr_door = lib.GetDebugFor("doors")
    if IsValid(self.targetDoor) then
        local doorCenter = self.targetDoor:WorldSpaceCenter()
        if dvlpr_door then print(self.bot:Nick() .. " is looking at blocking door " .. self.targetDoor:EntIndex()) end
        self.pathingLookGoal = doorCenter

        return true
    end

    return false
end

---@return boolean
---@package
function BotLocomotor:HandleOverrideLook()
    local override = self:GetLookGoal()
    if override then
        self.pathingLookGoal = override
        return true
    end

    return false
end

---@return boolean
---@package
function BotLocomotor:HandleRandomIdleLook()
    local foundPlayer = self:TryRandomPlayerLook()
    if foundPlayer then return false end

    lib.CallEveryNTicks(self.bot, function()
        local myPos = self.bot:EyePos()
        local randomOpenNormal = lib.GetRandomOpenNormal(myPos, 500)
        if not randomOpenNormal then return end
        local randomLook = myPos + randomOpenNormal * 1000

        self.pathingLookGoal = randomLook
    end, TTTBots.Tickrate * 2)

    return true
end

---@package
function BotLocomotor:TickViewAngles()
    -- This is a set of package functions that will be called in order until one of them returns true. Each is set up to update pathingLookGoal internally.
    -- Local functions would *probably* make more sense, but it already works and I kind of like how this looks more.
    local priorityTree = {
        self.HandleOverrideLook,
        self.HandleLadderLook,
        self.HandleDoorLook,
        self.HandleFallingLook,
        self.HandleRandomWalkLook,
        self.HandleRandomIdleLook,
    }

    for i, func in pairs(priorityTree) do
        if func(self) then
            break
        end
    end
end

--- Lerp look towards the goal position
---@package
function BotLocomotor:InterpolateMovement(factor, goal)
    if not goal then return end

    self.movementVec = (self.movementVec and LerpVector(factor, self.movementVec, goal)) or goal
end

--- Start attacking with the currently held item.
function BotLocomotor:StartAttack()
    self.attack = true
end

--- Stop attacking with the current held item.
function BotLocomotor:StopAttack()
    self.attack = false
end

function BotLocomotor:StartAttack2() self.attack2 = true end

function BotLocomotor:StopAttack2() self.attack2 = false end

--- Sets self.reload to true, queuing a reload the next frame.
function BotLocomotor:Reload()
    self.reload = true
end

local LADDER_THRESH_TOP = 30
local LADDER_THRESH_BOTTOM = 64
--- Functionally similar to IsNearEndOfLadder, but checks the current navigational goal to see if it agrees.
---
--- In other words, it checks if we're supposed to be going up/down AND we are close to the top/bottom respectively before dismounting
---@return boolean
function BotLocomotor:ShouldDismountLadder()
    if (math.random(1, 5) == 1) then return true end -- Just in case.
    local ladder, distTo = self:GetClosestLadder()
    if not (ladder and distTo < 1000) then return self:IsOnLadder() end
    local climbDir = self:GetClimbDir()

    -- if climbDir == "none" then return self:IsNearEndOfLadder() end -- We don't know what's going on so just default to this action instead.

    if climbDir == "up" then
        local distTop = self.bot:GetPos():Distance(ladder:GetTop())
        return distTop < LADDER_THRESH_TOP
    elseif climbDir == "down" then
        local distBottom = self.bot:GetPos():Distance(ladder:GetBottom())
        return distBottom < LADDER_THRESH_BOTTOM
    end

    return false
end

--- Gets if the bot is within a certain distance of the top of bottom of a ladder.
--- Primarily useful for func_useableladder
---@return boolean
function BotLocomotor:IsNearEndOfLadder()
    local bot = self.bot
    if not self:IsOnLadder() then return false end
    local ladder = self:GetClosestLadder()
    local distTop = bot:GetPos():Distance(ladder:GetTop())
    local distBottom = bot:GetPos():Distance(ladder:GetBottom())

    return (distTop < LADDER_THRESH_TOP or distBottom < LADDER_THRESH_BOTTOM) or false
end

--- Explciity disables "attack compatibility" until resumed -- this prevents the script from stopping an attack prematurely
--- for compatibility with certain modded guns. This is specifically useful to pause for utility weapons.
function BotLocomotor:PauseAttackCompat()
    self.attackCompat = false
end

--- Resumes the attack compatibility mechanic.
--- See PauseAttackCompat for more info.
function BotLocomotor:ResumeAttackCompat()
    self.attackCompat = true
end

---@see PauseAttackCompat
---@see ResumeAttackCompat
---@package
function BotLocomotor:TestShouldPreventFire()
    local attackCompat = self.attackCompat

    if (attackCompat == false) then return false end -- explicit false-check so we don't have to define attackCompat in the first place
    return (self.tick % TTTBots.Tickrate == 1)
end

---Basically manages the locomotor of the locomotor
---@package
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
        (self:IsTryingCrouch() or self:IsTryingJump()) and IN_DUCK or 0
    )

    --- 🦘 Set buttons for jumping if :GetJumping() is true
    --- The way jumping works is a little quirky, as it cannot be held down. We must release it occasionally
    if self:IsTryingJump() and (self.jumpReleaseTime < TIMESTAMP) or self.jumpReleaseTime == nil then
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
        self:InterpolateMovement(self.moveInterpRate, self.nextPos)
    elseif self:GetPriorityGoal() then
        self:InterpolateMovement(self.moveInterpRate, self:GetPriorityGoal())
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
            self:InterpolateMovement(self.moveInterpRate * 1.5, repelPos) -- Much more emphasis on the repel than normal movement patterns.
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

    --- 📷 SET VIEW ANGLES USING HELPER FUNCTION
    self:UpdateEyeAnglesFinal()

    --- 🏃 STRAFESTR FOR LADDER + STRAFE CALCS
    local strafeStr = self:GetStrafe()

    --- 🪜 MANAGE LADDER MOVEMENT
    local dismount = self:GetDismount()
    local climbDir = self:GetClimbDir()
    if self:IsOnLadder() then -- Ladder movement
        local strafe_dir = (strafeStr == "left" and IN_MOVELEFT) or (strafeStr == "right" and IN_MOVERIGHT) or
            0
        cmd:SetButtons(IN_FORWARD + strafe_dir)

        if dismount then
            cmd:SetButtons(cmd:GetButtons() + IN_USE)
        end

        return
    end
    cmd:SetUpMove(
        (climbDir == "up" and 500)
        or (climbDir == "down" and -500)
        or 0
    )

    --- 🏃 STRAFE CALCULATIONS
    local side = cmd:GetSideMove()
    side = (strafeStr == "left" and -400)
        or (strafeStr == "right" and 400)
        or 0
    local forceForward = self:GetForceForward() or self.repelled
    local forceBackward = self:GetForceBackward()
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
    local hasMoveVec = self.movementVec ~= nil
    cmd:SetSideMove(side)
    local forwardDir = (
        ((hasMoveVec or forceForward) and 400)
        or (forceBackward and -400)
        or 0
    )
    cmd:SetForwardMove(forwardDir)

    --- 🚪 MANAGE BOT DOOR HANDLING
    if self:GetUsing() and self:TestDoorTimer() then
        if DVLPR_PATHFINDING then
            TTTBots.DebugServer.DrawText(MYPOS, "Opening door", Color(255, 255, 255))
        end
        cmd:SetButtons(cmd:GetButtons() + IN_USE)
    end

    --- 🔫 MANAGE ATTACKING OF THE BOT
    if (
            (self.reactionDelay or 0) < TIMESTAMP
            and (self.attack or self.attack2)
        ) then
        -- stop attack from interrupting reload
        local currentWep = self.bot.components.inventory:GetHeldWeaponInfo() ---@type WeaponInfo
        local preventFire = self:TestShouldPreventFire() -- For compatibility with modded guns, sometimes we need to let go for a second to fire again.
        local needsReload = (currentWep and currentWep.needs_reload) or false
        if (
                not preventFire
                and not needsReload
                or not currentWep
            ) then
            cmd:SetButtons(
                cmd:GetButtons() + (self.attack and IN_ATTACK or 0) + (self.attack2 and IN_ATTACK2 or 0)
            )
        end
    end

    --- 🔫 MANAGE RELOADING OF THE BOT
    if self.reload then
        cmd:SetButtons(cmd:GetButtons() + IN_RELOAD)
        self.reload = false
    end

    -- TODO: use IN_SPEED to sprint around. cannot be held down constantly or else it won't work.
    cmd:SetButtons(cmd:GetButtons())

    self.moveNormal = cmd:GetViewAngles():Forward()
end

---@type table<CommonStuckPosition>
TTTBots.Components.Locomotor.commonStuckPositions = {}
---@type table<StuckBot>
TTTBots.Components.Locomotor.stuckBots = {}

timer.Create("TTTBots.Locomotor.StuckTracker", 1, 0, function()
    local stuckBots = TTTBots.Components.Locomotor.stuckBots
    local commonStucks = TTTBots.Components.Locomotor.commonStuckPositions
    local bots = TTTBots.Bots

    ---------------------------
    -- Update stuckBots table
    ---------------------------
    for _, bot in pairs(bots) do ---@cast bot Player
        if not (bot and lib.IsPlayerAlive(bot)) then continue end
        local locomotor = bot:BotLocomotor()

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
    if not TTTBots.DebugServer then return end
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
        if not (bot and bot.components and bot:BotLocomotor()) then continue end
        local loco = bot:BotLocomotor()
        local endTime = loco.lookGoalStopTime
        if endTime and endTime < CurTime() then
            loco.lookGoal = nil
            loco.lookGoalStopTime = nil
        end
    end
end)

---@class Player
local plyMeta = FindMetaTable("Player")

function plyMeta:SetAttackTarget(target)
    if self.attackTarget == target then return end
    if (IsValid(target) and TTTBots.Roles.IsAllies(self, target)) then return end
    if (hook.Run("TTTBotsCanAttack", self, target) == false) then return end
    self.attackTarget = target
    local loco = self:BotLocomotor()
    local personality = self:BotPersonality()
    if not (loco and personality) then return end
    loco:OnNewTarget(target)
    personality:OnPressureEvent("NewTarget")
end

---@return CLocomotor
function plyMeta:BotLocomotor()
    ---@cast self Bot
    return self.components.locomotor
end
