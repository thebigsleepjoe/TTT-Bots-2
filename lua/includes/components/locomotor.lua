--[[

This component is how the bot gets to something. It does not create the paths, it just follows them.

How this is used:
    1) Create a new locomotor component and assign it to the bot. This is done automatically when a bot is created.
    2) Every GM:StartCommand, Locomotor:StartCommand(CMD) is ran. This will set the bot's movement and look angles.
    3) Every TTT Bot tick, Locomotor:Think() is ran. This will set the bot's movement and look angles.

To update look angles:
    1) Locomotor:SetLookPosOverride(pos) will set the look position to the given position. This will override the look position. T
        This is used for aiming at players or objects. If this is nil, then the look position will be the goal position.
    2) Locomotor:ClearLookPosOverride() will clear the look position override, and the bot will look at the goal position.
        Sets lookPosOverride to nil.

To update the path goal, use Locomotor:SetGoalPos(pos). This will set the goal position to the given position. This will override the look position.
    This is used for pathfinding. If this is nil, then the bot will not move.
    If the bot is already moving to the given position, then this will do nothing.
    If the bot is already moving to a different position, then this will change the goal position to the given position.



]]

-----------------------------------------------
-- Utility functions
-----------------------------------------------

-- Component to manage the movement and look angles of the bot.

TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.Locomotor = {}

local lib = TTTBots.Lib
local BotLocomotor = TTTBots.Components.Locomotor

function BotLocomotor:New(bot)
    local newLocomotor = {}
    setmetatable(newLocomotor, self)
    self.__index = self
    self:Initialize(bot)
    return newLocomotor
end

function BotLocomotor:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.locomotor = self

    self.bot = bot

    self.path = nil -- Current path
    self.pathinfo = nil
    self.pathLookSpeed = 0.5 -- Look speed when following a path

    self.goalPos = nil -- Current goal position, if any. If nil, then bot is not moving.

    self.lookPosOverride = nil -- Override look position, used for looking at people or objects, ! do not use for pathfinding !
    self.lookPos = Vector(0, 0, 0) -- Current look position, gets lerped to Override
    self.lookSpeed = 0 -- Current look speed (rate of lerp)

    self.strafe = nil -- "left" or "right" or nil
    self.forceForward = false -- If true, then the bot will always move forward

    self.crouch = false
    self.jump = false
    self.dontmove = false
end
-- Validate the path's integrity. Returns false if path is invalid, info is invalid, or path is too old. Then, sets path and pathinfo to nil.
-- Else returns true.
function BotLocomotor:ValidatePath()

    -- This is ugly, but it works and it is easy to read.
    local failReason = ""
    if not self.path then -- No path
        failReason = "No path"
    elseif type(self.path) == "boolean" then -- Path is a boolean
        failReason = "Path is a boolean"
    -- elseif not IsValid(self.path) then -- Path is invalid
    --     failReason = "Path is invalid; value is " .. tostring(self.path)
    -- elseif not IsValid(self.pathinfo) then -- Path info is invalid
    --     failReason = "Path info is invalid"
    -- elseif self.pathinfo:TimeSince() > TTTBots.PathManager.cullSeconds then -- Path info is too old
    --     failReason = "Path info is too old"
    end

    if failReason ~= "" then
        -- print("Path failed: " .. failReason)
        self.path = nil
        self.pathinfo = nil
        return false
    end
    return true
end

-- Getters and setters, just for external neatness and ease of use.
function BotLocomotor:SetCrouching(bool) self.crouch = bool end
function BotLocomotor:SetJumping(bool) self.jump = bool end
function BotLocomotor:SetCanMove(bool) self.dontmove = not bool end
-- Set a look override, we will use the look override to override viewangles. Actual look angle is lerped to the override using lookSpeed.
function BotLocomotor:SetLookPosOverride(pos) self.lookPosOverride = pos end
function BotLocomotor:ClearLookPosOverride() self.lookPosOverride = nil end
function BotLocomotor:SetLookSpeed(speed) self.lookSpeed = speed end
function BotLocomotor:SetStrafe(value) self.strafe = value end
function BotLocomotor:SetGoalPos(pos) self.goalPos = pos end

function BotLocomotor:GetCrouching() return self.crouch end
function BotLocomotor:GetJumping() return self.jump end
function BotLocomotor:GetCanMove() return not self.dontmove end
function BotLocomotor:GetLookPosOverride() return self.lookPosOverride end
function BotLocomotor:GetLookSpeed() return self.lookSpeed end
function BotLocomotor:GetStrafe() return self.strafe end
function BotLocomotor:GetGoalPos() return self.goalPos end

function BotLocomotor:WithinCompleteRange(pos)
    return self.bot:GetPos():Distance(pos) < TTTBots.PathManager.completeRange
end

-- Return true if we should jump between vectors a and b. This is used for pathfinding.
function BotLocomotor:ShouldJumpBetweenPoints(a, b)
    local verticalCondition = (b.z - a.z) > 8

    local trce = util.TraceLine({
        start = a,
        endpos = b,
        filter = self.bot,
        mask = MASK_SOLID_BRUSHONLY
    })
    local obstructedCondition1 = (trce.HitPos:Distance(b) < 1)

    -- draw debug line
    TTTBots.DebugServer.DrawLineBetween(a, trce.HitPos, Color(255, 0, 255))

    local condition = verticalCondition-- or obstructedCondition1
    -- print(string.format("jumping=%s because verticalCondition=%s and not obstructedCondition1=%s", tostring(condition), tostring(verticalCondition), tostring(not canSee)))
    return condition
end

function BotLocomotor:ShouldCrouchBetweenPoints(a, b)
    -- mostly just check if the closest area to a or b has a crouch flag
    local area1 = navmesh.GetNearestNavArea(a)
    local area2 = navmesh.GetNearestNavArea(b)

    return (area1 and area1:IsCrouch()) or (area2 and area2:IsCrouch())
end

-- Wrapper for TTTBots.PathManager.BotIsCloseEnough(bot, pos)
function BotLocomotor:CloseEnoughTo(pos)
    return TTTBots.PathManager.BotIsCloseEnough(self.bot, pos)
end

-----------------------------------------------
-- Tick-level functions
-----------------------------------------------

-- Tick periodically. Do not tick per GM:StartCommand
function BotLocomotor:Think()
    self:UpdatePath()
    self:UpdateMovement()
end

-- Pretty much a wrapper for LerpLook, but may be more complex in the future.
-- This is used to orient the movement/view angles towards a certain point. It does not handle any other movement alone.
function BotLocomotor:OrientTowardsPoint(vec)
    self:LerpLook(self.pathLookSpeed, vec)
end

-- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function BotLocomotor:UpdateMovement()
    self:SetJumping(false)
    self:SetCrouching(false)
    self.forceForward = false
    if self.dontmove then return end

    local followingPath = self:FollowPath() -- true if doing proper pathing

    -- Walk straight towards the goal if it doesn't require complex pathing.
    local goal = self:GetGoalPos()

    if goal and not followingPath and not self:CloseEnoughTo(goal)then
        self:OrientTowardsPoint(goal)
        self.forceForward = true
    end
end

-- Update the path. Requests a path from our current position to our goal position. Done as a tick-level function for performance reasons.
function BotLocomotor:UpdatePath()
    -- if self:ValidatePath() then return end THIS IS NOT NECESSARY, as we will just update the path if it is invalid.
    if self:GetGoalPos() == nil then return end

    -- If we don't have a path, request one
    self.pathinfo = TTTBots.PathManager.RequestPath(self.bot:GetPos(), self:GetGoalPos())
    if self.pathinfo then
        self.path = self.pathinfo.path
    end
end

function BotLocomotor:DetermineNextPos(pathVecs)
    local bot = self.bot

    -- start by just pathing towards the closest vector to us
    local closestVec = pathVecs[1]
    local closestDist = bot:GetPos():Distance(closestVec)
    local closestIndex = 1
    for i = 2, #pathVecs do
        local dist = bot:GetPos():Distance(pathVecs[i])
        if dist < closestDist then
            closestDist = dist
            closestVec = pathVecs[i]
            closestIndex = i
        end
    end

    -- Re-add every point after closestIndex
    local updatedPathVecs = {}
    for i = closestIndex, #pathVecs do
        table.insert(updatedPathVecs, pathVecs[i])
    end

    -- TODO: Cut corners if we can see the next point
    local selected = 2

    -- check if following point is within a crouch navarea. if so, then nextpos is the following point.
    if #updatedPathVecs > selected + 1 and navmesh.GetNearestNavArea(updatedPathVecs[selected + 1]):IsCrouch() then
        selected = selected + 1
    end

    return updatedPathVecs[selected]
end

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    if not self:ValidatePath() then return false end
    local dvlpr = GetConVar("ttt_bot_debug_pathfinding"):GetBool()
    local path = self.path
    local bot = self.bot

    if not self:ValidatePath() then return false end

    local smoothPath = TTTBots.PathManager.SmoothPathEdges(path)

    if dvlpr then
        for i = 1, #smoothPath - 1 do
            TTTBots.DebugServer.DrawLineBetween(smoothPath[i], smoothPath[i + 1], Color(0, 125, 255))
        end
    end

    -- Walk towards the next node in the smoothPath that we can see
    local nextPos = self:DetermineNextPos(smoothPath)

    if not nextPos then return false end

    -- check if we should jump between our current position and nextPos
    if self:ShouldJumpBetweenPoints(bot:GetPos(), nextPos) then
        self:SetJumping(true)
    end

    if self:ShouldCrouchBetweenPoints(bot:GetPos(), nextPos) then
        self:SetCrouching(true)
    end

    self:OrientTowardsPoint(nextPos)

    if dvlpr then
        -- TTTBots.DebugServer.DrawSphere(nextPos, TTTBots.PathManager.completeRange, Color(255, 255, 0, 50))
        local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
        TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
        TTTBots.DebugServer.DrawLineBetween(bot:GetPos(), nextPos, Color(255, 255, 255))
    end
    
    return true
end

-----------------------------------------------
-- CMoveData-related functions
-----------------------------------------------

--- Lerp look towards the goal position
function BotLocomotor:LerpLook(factor, goal)
    if self.lookPosOverride and self.lookPosOverride ~= goal then return end
    self.lookPos = LerpVector(factor, self.lookPos, goal)
end


function BotLocomotor:StartCommand(cmd)
    cmd:ClearButtons()
    cmd:ClearMovement()
    if self.dontmove then return end
    if not lib.IsBotAlive(self.bot) then return end

    local hasPath = self:ValidatePath()
    local dvlpr = GetConVar("ttt_bot_debug_pathfinding"):GetBool()

    if self.bot:GetMoveType() == MOVETYPE_LADDER then
        cmd:SetButtons(IN_FORWARD)
        return
    end

    -- SetButtons to IN_DUCK if crouch is true
    cmd:SetButtons(
        (self:GetCrouching() or self:GetJumping()) and IN_DUCK or 0
    )

    -- Set buttons for jumping if :GetJumping() is true
    -- The way jumping works is a little quirky, as it cannot be held down. We must release it occasionally
    if self:GetJumping() and (self.jumpReleaseTime < CurTime()) or self.jumpReleaseTime == nil then
        cmd:SetButtons(IN_JUMP, IN_DUCK)
        self.jumpReleaseTime = CurTime() + 0.5
        
        if dvlpr then
            TTTBots.DebugServer.DrawText(self.bot:GetPos(), "Crouch Jumping", Color(255, 255, 255))
        end
    end

    -- Set viewangles to lookPos, and lerp to override if not nil
    local lookPos = self.lookPos
    if self.lookPosOverride then
        lookPos = LerpVector(FrameTime() * self.lookSpeed, lookPos, self.lookPosOverride)
    end

    -- if lookPos is (0, 0, 0) then skip
    if lookPos ~= Vector(0, 0, 0) then
        local ang = (lookPos - self.bot:GetPos()):Angle()
        cmd:SetViewAngles(LerpAngle(0.5, cmd:GetViewAngles(), ang))
        self.bot:SetEyeAngles(LerpAngle(0.1, self.bot:EyeAngles(), ang))
    end

    -- Set forward and side movement
    local forward = hasPath and 400 or 0

    local side = cmd:GetSideMove()
    side = (-400 and self.strafe == "left")
        or (400 and self.strafe == "right")
        or 0

    cmd:SetSideMove(side)
    cmd:SetForwardMove(not self.forceForward and forward or 400)

    -- Set up movement to always be up
    cmd:SetUpMove(400)




end