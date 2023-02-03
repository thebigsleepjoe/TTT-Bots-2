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
    local canSee = trce.HitPos:Distance(b) < 1

    return verticalCondition and not canSee
end

function BotLocomotor:ShouldCrouchBetweenPoints(a, b)
    -- mostly just check if the closest area to a or b has a crouch flag
    local area1 = navmesh.GetNearestNavArea(a)
    local area2 = navmesh.GetNearestNavArea(b)

    return (area1 and area1:IsCrouch()) or (area2 and area2:IsCrouch())
end

-----------------------------------------------
-- Tick-level functions
-----------------------------------------------

-- Tick periodically. Do not tick per GM:StartCommand
function BotLocomotor:Think()
    self:UpdatePath()
    self:UpdateMovement()
end

-- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function BotLocomotor:UpdateMovement()
    if self.dontmove then return end

    -- If we have a path, follow it
    if self:ValidatePath() then
        self:FollowPath()
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

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    local dvlpr = GetConVar("ttt_bot_debug_pathfinding"):GetBool()
    local path = self.path
    local bot = self.bot

    local nextPos = self:GetGoalPos()

    -- If we have a path, follow it
    if self:ValidatePath() then
        self:SetJumping(false)
        self:SetCrouching(false)
        local smoothPath = TTTBots.PathManager.SmoothPath(path, 4)

        if dvlpr then
            for i = 1, #smoothPath - 1 do
                TTTBots.DebugServer.DrawLineBetween(smoothPath[i], smoothPath[i + 1], Color(0, 125, 255))
            end
        end

        ----------------------------
        -- Begin following path
        ----------------------------

        -- Walk towards the next node in the smoothPath that we can see
        for i = 1, #smoothPath do
            local nodePos = smoothPath[i]

            local trace = lib.TraceVisibilityLine(bot, true, nodePos)
            local traceFoot = lib.TraceVisibilityLine(bot, false, nodePos)

            if not trace.Hit and not traceFoot.Hit then -- If we can see the node, walk towards it
                nextPos = smoothPath[i + 1]
                if smoothPath[i + 2] then
                    nextPos = smoothPath[i + 2]
                end
                break
            end
        end

        if not nextPos then return end

        -- check if we should jump between our current position and nextPos
        if self:ShouldJumpBetweenPoints(bot:GetPos(), nextPos) then
            self:SetJumping(true)
        end

        self:LerpLook(self.pathLookSpeed, nextPos)

        if dvlpr then
            -- TTTBots.DebugServer.DrawSphere(nextPos, TTTBots.PathManager.completeRange, Color(255, 255, 0, 50))
            local nextpostxt = string.format("NextPos (height difference is %s)", nextPos.z - bot:GetPos().z)
            TTTBots.DebugServer.DrawText(nextPos, nextpostxt, Color(255, 255, 255))
            TTTBots.DebugServer.DrawLineBetween(bot:GetPos(), nextPos, Color(255, 255, 255))
        end
    end
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

    -- Set viewangles to lookPos, and lerp to override if not nil
    local lookPos = self.lookPos
    if self.lookPosOverride then
        lookPos = LerpVector(FrameTime() * self.lookSpeed, lookPos, self.lookPosOverride)
    end

    -- if lookPos is (0, 0, 0) then skip
    if lookPos ~= Vector(0, 0, 0) then
        local ang = (lookPos - self.bot:GetPos()):Angle()
        cmd:SetViewAngles(LerpAngle(0.5, cmd:GetViewAngles(), ang))
        --self.bot:SetEyeAngles(ang)
        self.bot:SetEyeAngles(LerpAngle(0.1, self.bot:EyeAngles(), ang))
    end

    -- Set forward and side movement
    local forward = hasPath and 400 or 0

    local side = cmd:GetSideMove()
    side = (-400 and self.strafe == "left")
        or (400 and self.strafe == "right")
        or 0

    cmd:SetSideMove(side)
    cmd:SetForwardMove(forward)

    -- Set up movement to always be up
    cmd:SetUpMove(400)




end