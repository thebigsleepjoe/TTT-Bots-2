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
        print("Initialized locomotor for bot " .. bot:Nick())
    end

    return newLocomotor
end

function BotLocomotor:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.locomotor = self

    self.componentID = string.format("locomotor (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0 -- Tick counter
    self.bot = bot

    self.path = nil -- Current path
    self.pathingRandomAngle = Angle() -- Random angle used for viewangles when pathing
    self.pathLookSpeed = 0.05 -- Movement angle turn speed when following a path

    self.goalPos = nil -- Current goal position, if any. If nil, then bot is not moving.

    self.tryingMove = false -- If true, then the bot is trying to move to the goal position.
    self.posOneSecAgo = nil -- Position of the bot one second ago. Used for pathfinding.

    self.lookPosOverride = nil -- Override look position, this is only used from outside of this component. Like aiming at a player.
    self.lookLerpSpeed = 0.05 -- Current look speed (rate of lerp)
    self.lookPosGoal = nil -- The current goal position to look at
    self.lookPos = nil -- Current look position, gets lerped to Override, or to self.lookPosGoal.

    self.movementVec = Vector(0, 0, 0) -- Current look position, gets lerped to Override
    self.moveLerpSpeed = 0 -- Current look speed (rate of lerp)

    self.strafe = nil -- "left" or "right" or nil
    self.forceForward = false -- If true, then the bot will always move forward

    self.crouch = false
    self.jump = false
    self.dontmove = false
end

--- Returns a table of the path generation info. The actual path is stored in a key called "path"
---@return table
function BotLocomotor:GetPath()
    return self.path
end

---@return boolean
function BotLocomotor:HasPath()
    return self.path ~= nil
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
    local bodyfacingdir = self.moveNormal or Vector(0, 0, 0)
    -- disregard z
    bodyfacingdir.z = 0

    local startpos = pos + Vector(0, 0, 16)
    local endpos = pos + Vector(0, 0, 16) + bodyfacingdir * 30

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
-- function BotLocomotor:ShouldJumpBetweenPoints(a, b)
--     local verticalCondition = (b.z - a.z) > 8


--     local condition = verticalCondition or self:CheckFeetAreObstructed()
--     return condition
-- end

function BotLocomotor:ShouldJump()
    return self:CheckFeetAreObstructed()
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

--- Detect if there is a door ahead of us. Runs two traces, one for moveangles and one for viewangles. If so, then return the door.
function BotLocomotor:DetectDoorAhead()
    local pos = self.bot:EyePos()
    local bodyfacingdir = self.moveNormal or Vector(0, 0, 0)
    local lookPos = self:GetCurrentLookPos()

    local movetrace = util.TraceLine({
        start = pos,
        endpos = pos + bodyfacingdir * 80,
        filter = self.bot,
        mask = MASK_ALL
    })

    if movetrace.Hit and movetrace.Entity and movetrace.Entity:IsDoor() then
        return movetrace.Entity
    end

    local viewtrace = util.TraceLine({
        start = pos,
        endpos = lookPos,
        filter = self.bot,
        mask = MASK_ALL
    })

    if viewtrace.Hit and viewtrace.Entity and viewtrace.Entity:IsDoor() then
        return viewtrace.Entity
    end

    return false
end

--- Used to prevent spamming of doors.
--- Calling this function returns a bool. True if can use again. If it returns true, it starts the timer.
--- Otherwise it returns false, and does nothing
function BotLocomotor:UseTimer()
    local useTimer = (self.canUseAgain == nil and true) or self.canUseAgain

    if useTimer then
        self.canUseAgain = false
        timer.Simple(2, function()
            self.canUseAgain = true
        end)

        return true
    end

    return false
end

-----------------------------------------------
-- Tick-level functions
-----------------------------------------------

-- Tick periodically. Do not tick per GM:StartCommand
function BotLocomotor:Think()
    self.tick = self.tick + 1
    local status = self:UpdatePath() -- Update the path that the bot is following, so that we can move along it.
    self:UpdateMovement() -- Update the invisible angle that the bot moves at, and make it move.
    print("<Locomotor> Status is " .. status)
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
    self:SetUsing(false)
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
            self:LerpMovement(self.pathLookSpeed, goal)
            self.forceForward = true
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

    -----------------------
    -- Door code
    -----------------------

    local door = self:DetectDoorAhead()
    if door then
        self:SetUsing(true)
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

--- Update the path. Requests a path from our current position to our goal position.
---@return string status Status of the pathing, mostly flavor/debugging text.
function BotLocomotor:UpdatePath()
    self.cantReachGoal = false
    self.pathWaiting = false
    if self.dontmove then return "dont_move" end
    if self:GetGoalPos() == nil then return "no_goalpos" end
    if not lib.IsBotAlive(self.bot) then return "bot_dead" end

    local path = self:GetPath()
    local goalNav = navmesh.GetNearestNavArea(self:GetGoalPos())

    if (self:HasPath() and path[#path] ~= goalNav) then
        return "pathing_currently"
    end

    -- If we don't have a path, request one
    local pathid, path, status = TTTBots.PathManager.RequestPath(self.bot, self.bot:GetPos(), self:GetGoalPos(), false)

    local fr = string.format
    -- print(fr("<Locomotor> Path status for bot %s: %s", self.bot:Nick(), status))

    if (path == false) then -- path is impossible
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

function BotLocomotor:DetermineNextPos()
    local preparedPath = self:HasPath() and self:GetPath().preparedPath
    local purePath = self:GetPath()
    if not preparedPath then return nil end

    --[[
        A prepared path is a table of tables. Each element is formatted, so:
        {
            pos = Vector(0, 0, 0)
            area = navarea
            type = "jump" or "ladder" or "walk" or "fall" or "swim" or "crouch"
            ladder_dir = "up" or "down" (if ladder, else nil)
        }
    ]]
    --local nextPos = preparedPath[1].pos
    local closestPos = nil
    local closestDist = nil
    local closestI = nil
    local botPos = self.bot:GetPos()
    local tooCloseDist = 32

    for i = 1, #preparedPath do
        local pos = preparedPath[i].pos
        local dist = botPos:Distance(pos)
        local visionCheck = util.TraceLine({
                start = botPos,
                endpos = pos + Vector(0, 0, 24),
                filter = self.bot
            }).Hit == false

        if (closestDist == nil or (dist < closestDist and visionCheck)) then
            closestPos = pos
            closestDist = dist
            closestI = i
        end

        if not visionCheck then break end
    end

    if (closestI <= purePath.pathIndex) then
        closestI = purePath.pathIndex + 1
        purePath.pathIndex = closestI
    end

    -- closestI = (closestI or 1) + 1

    -- local nextPos = closestI and #preparedPath ~= closestI and preparedPath[closestI + 1].pos or closestPos
    local nextPosI = closestI and #preparedPath ~= closestI and closestI + 1 or closestI
    local nextPos = closestI and preparedPath[closestI] or closestPos
    if type(nextPos) == "table" then nextPos = nextPos.pos end

    return nextPos, nextPosI
end

-- Determines how the bot navigates through its path once it has one.
function BotLocomotor:FollowPath()
    if not self:HasPath() then return false end
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

    if not nextPos then return false end

    if self:ShouldJump() then
        self:SetJumping(true)
    end

    if self:ShouldCrouchBetweenPoints(bot:GetPos(), nextPos) then
        self:SetCrouching(true)
    end

    self:LerpMovement(self.pathLookSpeed, nextPos)

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
    local override = self:GetLookPosOverride()
    local lookLerpSpeed = self.lookLerpSpeed or 0
    local preparedPath = self:HasPath() and self:GetPath().preparedPath
    local goal = self.goalPos

    if override then
        self.lookPosGoal = override
        return
    end

    self.lookPosGoal = goal

    if self.nextPos then
        if not preparedPath then
            self.lookPosGoal = goal
        else
            local nextPos = self.nextPos
            if #preparedPath > self.nextPosI + 2 then
                local off = lib.OffsetForGround

                local secondPos = preparedPath[self.nextPosI + 1].pos
                local thirdPos = preparedPath[self.nextPosI + 2].pos
                self.lookPosGoal = lib.WeightedVectorMean({
                    { vector = off(nextPos),   weight = 1.5 },
                    { vector = off(secondPos), weight = 0.9 },
                    { vector = off(thirdPos),  weight = 0.6 },
                    { vector = off(goal),      weight = 0.5 }
                })
            else -- If there are less than 3 points left in the path
                --self.lookPosGoal = goal
                -- Let's look in the direction of the goal, as if it were outwards another few hundred units.
                local dir = (goal - self.bot:GetPos()):GetNormalized()
                self.lookPosGoal = self.bot:GetPos() + dir * 500
            end
        end
        -- self.lookPosGoal = lib.WeightedVectorMean({
        --     { vector = self.nextPos, weight = 0.5 },
        --     { vector = goal,         weight = 1.5 }
        -- })

        if self:IsStuck() then
            self.lookPosGoal = self.nextPos
        end
    end

    local closestLadder = self:GetClosestLadder()
    if self:IsOnLadder() and closestLadder then
        -- Average the positions of the next 3 points in the smoothPath
        -- local average = Vector(0, 0, 0)
        -- for i = 1, 3 do
        --     if smoothPath[i] then
        --         average = average + smoothPath[i]
        --     end
        -- end
        -- average = average / 3
        -- TTTBots.DebugServer.DrawSphere(average, 10, Color(255, 0, 0))

        -- -- Check if the average is above or below the center of the ladder
        -- local pointIsBelow = (average.z < closestLadder:GetCenter().z)

        local offset = Vector(0, 0, 500)
        -- if pointIsBelow then
        --     offset = offset * -1
        -- end

        -- self.lookPosGoal = (closestLadder:GetTop() + offset)
        self.lookPosGoal = (self.nextPos or closestLadder:GetTop()) + offset
    end

    if not self.lookPosGoal then return end

    self:UpdateLookPos()
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

    local movementVec = self.movementVec
    if movementVec ~= Vector(0, 0, 0) then
        local ang = (movementVec - self.bot:GetPos()):Angle()
        cmd:SetViewAngles(ang) -- This is actually the movement angles, not the view angles. It's confusingly named.
    end

    self:UpdateViewAngles(cmd)

    -- Set forward and side movement
    local forward = hasPath and 400 or 0

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

    if self:GetUsing() and self:UseTimer() then
        if dvlpr then
            TTTBots.DebugServer.DrawText(self.bot:GetPos(), "Opening door", Color(255, 255, 255))
        end
        cmd:SetButtons(cmd:GetButtons() + IN_USE)
    end

    self.moveNormal = cmd:GetViewAngles():Forward()
end

---------------------------------
-- Other utils
---------------------------------

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
        if not lib.IsBotAlive(bot) then continue end
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

        local shouldUnstuck = (stuckTime > 3)

        if shouldUnstuck then
            local cnavarea = navmesh.GetNearestNavArea(stuckPos)
            local randomPos = cnavarea:GetRandomPoint()
            bot:SetPos(randomPos + Vector(0, 0, 2))
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
    local drawText = TTTBots.DebugServer.DrawText -- (pos, text, color)
    local f = string.format

    local commonStucks = TTTBots.Components.Locomotor.commonStuckPositions

    for i, pos in pairs(commonStucks) do
        drawText(pos.center,
            f("STUCK AREA (lost %d seconds | %d victims)", pos.timeLost, pos.victims and #pos.victims or 0),
            Color(255, 255, 255, 50))
    end
end)
