--[[

This component is how the bot gets to something. It does not create the paths, it just follows them.

How this is used:
    1) Create a new locomotor component and assign it to the bot. This is done automatically when a bot is created.
    2) Every GM:StartCommand, Locomotor:StartCommand(CMD) is ran. This will set the bot's movement and look angles.
    3) Every TTT Bot tick, Locomotor:Think() is ran. This will set the bot's movement and look angles.
            Movement and look angles are INDEPENDENT as of now. This means that the bot can be moving and looking at different things.

To update the path goal, use Locomotor:SetGoalPos(pos). This will set the goal position to the given position. This will override the look position.
    This is used for pathfinding. If this is nil, then the bot will not move.
    If the bot is already moving to the given position, then this will do nothing.
    If the bot is already moving to a different position, then this will change the goal position to the given position.



]]

-----------------------------------------------
-- Utility functions
-----------------------------------------------
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

    local dbg = lib.GetDebugFor("all")
    if dbg then
        print("Initialized locomotor for bot ".. bot:Nick())
    end

    return newLocomotor
end

function BotLocomotor:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.locomotor = self

    self.componentID = string.format("locomotor (%s)", lib.GenerateID() ) -- Component ID, used for debugging

    self.tick = 0 -- Tick counter
    self.bot = bot

    self.path = nil -- Current path
    self.pathinfo = nil
    self.pathTurnSpeed = 0.7 -- Look speed when following a path

    self.goalPos = nil -- Current goal position, if any. If nil, then bot is not moving.

    self.tryingMove = false -- If true, then the bot is trying to move to the goal position.
    self.posOneSecAgo = nil -- Position of the bot one second ago. Used for pathfinding.

    self.lookPosOverride = nil -- Override look position, this is only used from outside of this component. Like aiming at a player.
    self.lookLerpSpeed = 0 -- Current look speed (rate of lerp)
    self.lookPos = nil -- Current look position, gets lerped to Override, or to another location if no override is set.

    self.movementVec = Vector(0, 0, 0) -- Current look position, gets lerped to Override
    self.moveLerpSpeed = 0 -- Current look speed (rate of lerp)

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
        self.path = nil
        self.pathinfo = nil
        return false
    end
    return true
end

-- Getters and setters, just for formality and easy reading.
function BotLocomotor:SetCrouching(bool) self.crouch = bool end
function BotLocomotor:SetJumping(bool) self.jump = bool end
function BotLocomotor:SetCanMove(bool) self.dontmove = not bool end
-- Set a look override, we will use the look override to override viewangles. Actual look angle is lerped to the override using moveLerpSpeed.
function BotLocomotor:SetLookPosOverride(pos) self.lookPosOverride = pos end
function BotLocomotor:SetCurrentLookPos(pos) self.lookPos = pos end
function BotLocomotor:ClearLookPosOverride() self.lookPosOverride = nil end
function BotLocomotor:SetMoveLerpSpeed(speed) self.moveLerpSpeed = speed end
function BotLocomotor:SetStrafe(value) self.strafe = value end
function BotLocomotor:SetGoalPos(pos) self.goalPos = pos end

function BotLocomotor:GetCrouching() return self.crouch end
function BotLocomotor:GetJumping() return self.jump end
function BotLocomotor:GetCanMove() return not self.dontmove end
function BotLocomotor:GetLookPosOverride() return self.lookPosOverride end
function BotLocomotor:GetCurrentLookPos() return self.lookPos end
function BotLocomotor:GetMoveLerpSpeed() return self.moveLerpSpeed end
function BotLocomotor:GetStrafe() return self.strafe end
function BotLocomotor:GetGoalPos() return self.goalPos end

function BotLocomotor:WithinCompleteRange(pos)
    return self.bot:GetPos():Distance(pos) < TTTBots.PathManager.completeRange
end

function BotLocomotor:GetClosestLadder()
    local closestLadder = nil
    local closestDist = 99999
    for i = 1, 100 do
        local ladder = navmesh.GetNavLadderByID(i)
        if ladder then
            local dist = ladder:GetCenter():Distance(self.bot:GetPos())
            if dist < closestDist then
                closestLadder = ladder
                closestDist = dist
            end
        end
    end
    return closestLadder, closestDist
end

function BotLocomotor:IsOnLadder()
    return self.bot:GetMoveType() == MOVETYPE_LADDER
end
-- Do a trace to check if our feet are obstructed, but our head is not.
function BotLocomotor:CheckFeetAreObstructed()
    local pos = self.bot:GetPos()
    local bodyfacingdir = self.moveNormal or Vector(0, 0, 0)
    -- disregard z
    bodyfacingdir.z = 0

    local startpos = pos + Vector(0, 0, 16)
    local endpos = pos + bodyfacingdir*30

    local trce = util.TraceLine({
        start = startpos,
        endpos = endpos,
        filter = self.bot,
        mask = MASK_SOLID_BRUSHONLY
    })

    -- draw debug line
    TTTBots.DebugServer.DrawLineBetween(startpos, endpos, Color(255, 0, 255))

    return trce.Hit
end

-- Return true if we should jump between vectors a and b. This is used for pathfinding.
function BotLocomotor:ShouldJumpBetweenPoints(a, b)
    local verticalCondition = (b.z - a.z) > 8


    local condition = verticalCondition or self:CheckFeetAreObstructed()
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
    self.tick = self.tick + 1
    self:UpdatePath()       -- Update the path that the bot is following, so that we can move along it.
    self:UpdateMovement()   -- Update the invisible angle that the bot moves at, and make it move.
    --self:UpdateViewAngles() -- Update the visible angle that the bot looks at. This is for cosmetic and aiming purposes.
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
    TTTBots.DebugServer.DrawLineBetween(kneePos, forward, Color(255, 0, 255))
    TTTBots.DebugServer.DrawLineBetween(kneePos, left, Color(255, 0, 255))
    TTTBots.DebugServer.DrawLineBetween(kneePos, right, Color(255, 0, 255))

    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetStrafe(nil)

    self:SetJumping(trce1.Hit)
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

-- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function BotLocomotor:UpdateMovement()
    self:SetJumping(false)
    self:SetCrouching(false)
    self:SetStrafe(nil)
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
            self:LerpMovement(self.pathTurnSpeed, goal)
            self.forceForward = true
            self.tryingMove = true
        end
    end

    -----------------------
    -- Unstuck code
    -----------------------

    if not self.tryingMove then return end

    -- If we're stuck, try to get unstuck.
    self:RecordPosition()
    if self:IsStuck() then
        self:Unstuck()
    end
end

-- Record the bot's position. This is used for getting the bot unstuck from weird situations.
function BotLocomotor:RecordPosition()
    if self.lastPositions == nil then self.lastPositions = {} end
    table.insert(self.lastPositions, self.bot:GetPos())

    if #self.lastPositions > 10 then
        table.remove(self.lastPositions, 1)
    end
end

-- Check if the bot is stuck. This is used for getting the bot unstuck from weird situations.
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

-- Update the path. Requests a path from our current position to our goal position. Done as a tick-level function for performance reasons.
function BotLocomotor:UpdatePath()
    -- if self:ValidatePath() then return end THIS IS NOT NECESSARY, as we will just update the path if it is invalid.
    if self:GetGoalPos() == nil then return end

    -- If we don't have a path, request one
    self.pathinfo = TTTBots.PathManager.RequestPath(self.bot:GetPos(), self:GetGoalPos())
    self.smoothPath = nil
    if self.pathinfo and type(self.pathinfo.path) == "table" then
        self.path = self.pathinfo.path
        self.smoothPath = TTTBots.PathManager.SmoothPath2(self.path, 3)
    else
        self.pathinfo = nil
        self.path = nil
        self.smoothPath = nil
    end
end

function BotLocomotor:DetermineNextPos(pathVecs, areas)
    if pathVecs == nil or areas == nil or #pathVecs == 0 then
        return false
    end
    local bot = self.bot

    -- start by just pathing towards the closest vector to us
    local closestVec = pathVecs[1]
    local closestDist = bot:GetPos():Distance(closestVec)
    local closestIndex = 1
    for i = 2, #pathVecs do
        local dist = bot:GetPos():Distance(pathVecs[i])
        if dist < closestDist and not TTTBots.PathManager.BotIsCloseEnough(bot, pathVecs[i]) then
            closestDist = dist
            closestVec = pathVecs[i]
            closestIndex = i
        end
    end

    -- Re-add every point after closestIndex
    local updatedPathVecs = {}
    local updatedAreas = {}
    for i = closestIndex, #pathVecs do
        table.insert(updatedPathVecs, pathVecs[i])
        table.insert(updatedAreas, areas[i])
    end

    local selected = 2

    -- check if following point is within a crouch navarea. if so, then nextpos is the following point.
    if #updatedPathVecs > selected + 1 and navmesh.GetNearestNavArea(updatedPathVecs[selected + 1]):IsCrouch() then
        selected = selected + 1
    end

    if
        updatedAreas[selected + 1]
        and not updatedAreas[selected + 1]:IsLadder()
        and updatedAreas[selected]:GetConnectionTypeBetween(updatedAreas[selected + 1]) == "jump"
    then
        selected = selected + 1
    end

    if self:IsOnLadder() then
        local ladder = self:GetClosestLadder()
        if ladder then return ladder:GetTop() end
    end

    -- if self:IsOnLadder() then
    --     selected = selected + 1
    -- end

    return updatedPathVecs[selected]
end

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    if not self:ValidatePath() then return false end
    local dvlpr = lib.GetDebugFor("pathfinding")
    local bot = self.bot

    if not self:ValidatePath() then return false end

    if (self.smoothPath == nil or self.areas == nil) then
        local sp, ars = TTTBots.PathManager.SmoothPath2(self.path, 3)
        self.smoothPath = sp
        self.areas = ars
    end

    local smoothPath = self.smoothPath --TTTBots.PathManager.SmoothPath2(path, 3)
    local areas = self.areas

    if dvlpr then
        for i = 1, #smoothPath - 1 do
            TTTBots.DebugServer.DrawLineBetween(smoothPath[i], smoothPath[i + 1], Color(0, 125, 255))
        end
    end
    -- Walk towards the next node in the smoothPath that we can see
    local nextPos = self:DetermineNextPos(smoothPath, areas)
    self.nextPos = nextPos

    if not nextPos then return false end

    -- check if we should jump between our current position and nextPos
    if self:ShouldJumpBetweenPoints(bot:GetPos(), nextPos) then
        self:SetJumping(true)
    end

    if self:ShouldCrouchBetweenPoints(bot:GetPos(), nextPos) then
        self:SetCrouching(true)
    end

    self:LerpMovement(self.pathTurnSpeed, nextPos)

    if dvlpr then
        -- TTTBots.DebugServer.DrawSphere(nextPos, TTTBots.PathManager.completeRange, Color(255, 255, 0, 50))
        local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
        TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
        -- TTTBots.DebugServer.DrawLineBetween(bot:GetPos(), nextPos, Color(255, 255, 255))
    end
    
    return true
end

-----------------------------------------------
-- CMoveData-related functions
-----------------------------------------------

function BotLocomotor:UpdateViewAngles(cmd)
    -- self.lookPosOverride = nil -- Override look position, this is only used from outside of this component. Like aiming at a player.
    -- self.lookLerpSpeed = 0 -- Current look speed (rate of lerp)
    -- self.lookPos = nil -- Current look position, gets lerped to Override, or to another location if no override is set.


    -- TODO: Make this work with pathfinding
    local override = self:GetLookPosOverride()
    local lookLerpSpeed = self.lookLerpSpeed or 0
    local smoothPath = self.smoothPath or {}
    local goal = self.goalPos

    self.lookPos = self.lookPos

    if override then
        self.lookPos = override
        return
    end

    self.lookPos = goal

    local closestLadder = self:GetClosestLadder()
    if self:IsOnLadder() and closestLadder then self.lookPos = (closestLadder:GetTop() + Vector( 0, 0, 500)) end

    if not self.lookPos then return end

    self.bot:SetEyeAngles((self.lookPos - self.bot:GetPos()):Angle())
    --cmd:SetViewAngles((self.lookPos - self.bot:GetPos()):Angle())
end

--- Lerp look towards the goal position
function BotLocomotor:LerpMovement(factor, goal)
    self.movementVec = LerpVector(factor, self.movementVec, goal)
end

function BotLocomotor:StartCommand(cmd)
    cmd:ClearButtons()
    cmd:ClearMovement()
    if self.dontmove then return end
    if not lib.IsBotAlive(self.bot) then return end

    local hasPath = self:ValidatePath()
    local dvlpr = lib.GetDebugFor("pathfinding")


    -- SetButtons to IN_DUCK if crouch is true
    cmd:SetButtons(
        (self:GetCrouching() or self:GetJumping()) and IN_DUCK or 0
    )

    -- Set buttons for jumping if :GetJumping() is true
    -- The way jumping works is a little quirky, as it cannot be held down. We must release it occasionally
    if self:GetJumping() and (self.jumpReleaseTime < CurTime()) or self.jumpReleaseTime == nil then
        cmd:SetButtons(IN_JUMP, IN_DUCK)
        self.jumpReleaseTime = CurTime() + 0.1
        
        if dvlpr then
            TTTBots.DebugServer.DrawText(self.bot:GetPos(), "Crouch Jumping", Color(255, 255, 255))
        end
    end

    local movementVec = self.movementVec
    if movementVec ~= Vector(0, 0, 0) then
        local ang = (movementVec - self.bot:GetPos()):Angle()
        --cmd:SetViewAngles(LerpAngle(0.5, cmd:GetViewAngles(), ang))
        cmd:SetViewAngles(ang)
        -- self.bot:SetEyeAngles(LerpAngle(0.1, self.bot:EyeAngles(), ang))
    end

    self:UpdateViewAngles(cmd)

    -- Set forward and side movement
    local forward = hasPath and 400 or 0

    local side = cmd:GetSideMove()
    side = (self:GetStrafe() == "left" and -400)
        or (self:GetStrafe() == "right" and 400)
        or 0

    if self:IsOnLadder() then -- Ladder movement
        cmd:SetButtons(IN_FORWARD)

        return
    end

    cmd:SetSideMove(side)
    cmd:SetForwardMove(not self.forceForward and forward or 400)

    -- Set up movement to always be up
    cmd:SetUpMove(400)



    self.moveNormal = cmd:GetViewAngles():Forward()
end