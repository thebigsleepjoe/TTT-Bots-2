--[[

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

-- Component to manage the movement and look angles of the bot.

TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.Locomotor = {}

function TTTBots.Components.Locomotor:New(bot)
    local newLocomotor = {}
    setmetatable(newLocomotor, self)
    self.__index = self
    self:Initialize(bot)
    return newLocomotor
end

function TTTBots.Components.Locomotor:Initialize(bot)
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
function TTTBots.Components.Locomotor:ValidatePath()

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
function TTTBots.Components.Locomotor:SetCrouching(bool) self.crouch = bool end
function TTTBots.Components.Locomotor:SetJumping(bool) self.jump = bool end
function TTTBots.Components.Locomotor:SetCanMove(bool) self.dontmove = not bool end
-- Set a look override, we will use the look override to override viewangles. Actual look angle is lerped to the override using lookSpeed.
function TTTBots.Components.Locomotor:SetLookPosOverride(pos) self.lookPosOverride = pos end
function TTTBots.Components.Locomotor:ClearLookPosOverride() self.lookPosOverride = nil end
function TTTBots.Components.Locomotor:SetLookSpeed(speed) self.lookSpeed = speed end
function TTTBots.Components.Locomotor:SetStrafe(value) self.strafe = value end
function TTTBots.Components.Locomotor:SetGoalPos(pos) self.goalPos = pos end

function TTTBots.Components.Locomotor:GetCrouching() return self.crouch end
function TTTBots.Components.Locomotor:GetJumping() return self.jump end
function TTTBots.Components.Locomotor:GetCanMove() return not self.dontmove end
function TTTBots.Components.Locomotor:GetLookPosOverride() return self.lookPosOverride end
function TTTBots.Components.Locomotor:GetLookSpeed() return self.lookSpeed end
function TTTBots.Components.Locomotor:GetStrafe() return self.strafe end
function TTTBots.Components.Locomotor:GetGoalPos() return self.goalPos end

-----------------------------------------------
-- Tick-level functions
-----------------------------------------------

-- Tick periodically. Do not tick per GM:StartCommand
function TTTBots.Components.Locomotor:Think()
    self:UpdatePath()
    self:UpdateMovement()
end

-- Manage the movement; do not use CMoveData, use the bot's movement functions and fields instead.
function TTTBots.Components.Locomotor:UpdateMovement()
    if self.dontmove then return end

    -- If we have a path, follow it
    if self:ValidatePath() then
        self:FollowPath()
    end
end

-- Update the path. Requests a path from our current position to our goal position. Done as a tick-level function for performance reasons.
function TTTBots.Components.Locomotor:UpdatePath()
    -- if self:ValidatePath() then return end THIS IS NOT NECESSARY, as we will just update the path if it is invalid.
    if self:GetGoalPos() == nil then return end

    -- If we don't have a path, request one
    self.pathinfo = TTTBots.PathManager.RequestPath(self.bot:GetPos(), self:GetGoalPos())
    if self.pathinfo then
        self.path = self.pathinfo.path
    end
end

function TTTBots.Components.Locomotor:FollowPath()
    local path = self.path
    local bot = self.bot

    -- If we have a path, follow it
    if self:ValidatePath() then
        local nextN = 1

        -- Determine the area furthest along the path that is visible to the character
        for i = 1, #path do
            local area = path[i]
            if not bot:VisibleVec(area:GetCenter()) then
                nextN = i - 1
                break
            end
        end

        local nextArea = path[nextN]
        if nextArea then
            self:LerpLook(self.pathLookSpeed, nextArea:GetCenter())
            TTTBots.DebugServer.DrawLineBetween(bot:GetPos(), nextArea:GetCenter(), Color(255, 255, 255))
        end
    end
end

-----------------------------------------------
-- CMoveData-related functions
-----------------------------------------------

--- Lerp look towards the goal position
function TTTBots.Components.Locomotor:LerpLook(factor, goal)
    if self.lookPosOverride and self.lookPosOverride ~= goal then return end
    self.lookPos = LerpVector(factor, self.lookPos, goal)
end


function TTTBots.Components.Locomotor:StartCommand(cmd)
    if self.dontmove then return end
    local hasPath = self:ValidatePath()

    -- SetButtons to IN_DUCK if crouch, and IN_JUMP if jump
    cmd:SetButtons(
        self:GetCrouching() and IN_DUCK or 0,
        self:GetJumping() and IN_JUMP or 0
    )

    -- Set viewangles to lookPos, and lerp to override if not nil
    local lookPos = self.lookPos
    if self.lookPosOverride then
        lookPos = LerpVector(FrameTime() * self.lookSpeed, lookPos, self.lookPosOverride)
    end

    -- if lookPos is (0, 0, 0) then skip
    if lookPos ~= Vector(0, 0, 0) then
        local ang = (lookPos - self.bot:GetPos()):Angle()
        cmd:SetViewAngles(ang)
        self.bot:SetEyeAngles(ang)
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