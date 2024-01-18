--- This is a more fluff-related module that make bots feel more alive.
--- It lets them nod, shake their head, and do silly actions next to one another/humans.

TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BInteract
TTTBots.Behaviors.Interact = {}

local lib = TTTBots.Lib

---@class BInteract
local Interact = TTTBots.Behaviors.Interact
Interact.Name = "Interact"
Interact.Description = "Interact with another bot or player we can see"
Interact.Interruptible = true

Interact.MinTimeBetween = 8 -- Minimum seconds between all interactions.
Interact.MaxDistance = 200  -- Maximum distance before an interaction is considered
Interact.BaseChancePct = 10 -- Base chance of interacting with a player within our range, considered per tick

---@enum BStatus
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

local intensity = 12

---@class KeyFrame
---@field target string
---@field direction string?
---@field amount number?
---@field action string?
---@field minTime number
---@field maxTime number

---@type table<table<KeyFrame>>
Interact.Animations = {
    Nod = {
        { target = "head", direction = "up",   amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "down", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "up",   amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "down", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", minTime = 0.7,      maxTime = 1.2 }, -- stare for a sec or so
    },
    Shake = {
        { target = "head", direction = "left",  amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "right", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "left",  amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "right", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", minTime = 0.7,       maxTime = 1.2 }, -- stare for a sec or so
    },
    LookUpDown = {
        { target = "head", minTime = 0.6, maxTime = 1.0 },
        { target = "feet", minTime = 0.6, maxTime = 1.0 },
        { target = "head", minTime = 0.6, maxTime = 1.0 },
        { target = "feet", minTime = 0.6, maxTime = 1.0 },
        { target = "head", minTime = 0.7, maxTime = 1.2 }, -- stare for a sec or so
    },
    Jump = {
        { target = "head", action = "jump", minTime = 0.3, maxTime = 0.4 },
        { target = "head", minTime = 0.4,   maxTime = 6 },                  -- stop jumping for a sec
        { target = "head", action = "jump", minTime = 0.3, maxTime = 0.4 }, -- jump again
        { target = "head", minTime = 0.4,   maxTime = 6 },                  -- finish it off with a stare
    },
    Crouch = {
        { target = "head", action = "crouch", minTime = 0.3, maxTime = 0.4 },
        { target = "head", minTime = 0.4,     maxTime = 6 },                  -- stop crouching for a sec
        { target = "head", action = "crouch", minTime = 0.3, maxTime = 0.4 }, -- crouch again
        { target = "head", minTime = 0.4,     maxTime = 6 },                  -- finish it off with a stare
    }
}

function Interact.GetNextKeyframeTime(keyframe)
    return CurTime() + (math.random(keyframe.minTime * 100, keyframe.maxTime * 100) / 100)
end

function Interact.SetAnimation(bot, value)
    if not value then
        bot.interactAnimation = nil
        bot.interactAnimationKeyframe = nil
        bot.nextKeyframeTime = nil
        return
    end

    local animation = type(value) == "string" and Interact.Animations[value] or value
    local keyframe = 1
    local minTime, maxTime = animation[keyframe].minTime, animation[keyframe].maxTime
    local nextKeyframeTime = Interact.GetNextKeyframeTime(animation[keyframe])

    bot.interactAnimation = animation
    bot.interactAnimationKeyframe = keyframe
    bot.nextKeyframeTime = nextKeyframeTime

    return animation, keyframe, nextKeyframeTime
end

function Interact.GetBotAnimation(bot)
    return bot.interactAnimation, bot.interactAnimationKeyframe, bot.nextKeyframeTime
end

function Interact.IsAnimationOver(bot)
    local animation, keyframe, nextKeyframeTime = Interact.GetBotAnimation(bot)

    if not (animation) then return true end
    if keyframe > #animation then return true end
    if (keyframe == #animation and nextKeyframeTime < CurTime() + 0.1) then return true end

    return false
end

function Interact.GetKeyframePos(other, keyframe)
    local direction = keyframe.direction or "up"
    local magnitude = keyframe.amount or 1

    local originHash = {
        head = lib.GetHeadPos(other) or other:EyePos(),
        feet = other:GetPos()
    }

    local right = other:GetRight()
    local forward = other:GetForward()

    local directionHash = {
        up = Vector(0, 0, 1),
        down = Vector(0, 0, -1),
        left = right * -1,
        right = right,
        forward = forward,
        backward = forward * -1
    }

    local origin = originHash[keyframe.target] or other:EyePos()
    local direction = directionHash[direction] or Vector(0, 0, 1)

    return origin + (direction * magnitude)
end

function Interact.TestTimer(bot)
    local lastTime = bot.lastInteractionTime or 0
    local interval = Interact.MinTimeBetween

    return (lastTime + interval) < CurTime()
end

function Interact.TestLookingAtEachOther(bot, other)
    local eyeTraceBot = bot:GetEyeTrace()
    local eyeTraceOther = other:GetEyeTrace()

    return (eyeTraceBot.Entity == other) or (eyeTraceOther.Entity == bot)
end

---Returns the first other that is close enough and/or looking at us. Prefers those we are looking at, or vice versa.
---@param bot Player
---@return Player target?
---@return number targetDist?
function Interact.FindOther(bot)
    local target, targetDist = nil, math.huge
    local others = TTTBots.Match.AlivePlayers
    local maxDist = Interact.MaxDistance
    local maxDistSqr = maxDist * maxDist

    for _, other in pairs(others) do
        if other == bot then continue end
        if not lib.CanSee(bot, other) then continue end

        local distTo = bot:GetPos():DistToSqr(other:GetPos())
        if distTo > maxDistSqr then continue end
        if Interact.TestLookingAtEachOther(bot, other) then
            return other, distTo -- Always prefer those that are looking at us, or vice versa
        end

        if not target or distTo < targetDist then
            target = other
            targetDist = distTo
        end
    end

    return target, targetDist
end

function Interact.ValidateTarget(target)
    local valid = IsValid(target) and lib.IsPlayerAlive(target)
    if not valid then return false end

    local dist = bot:GetPos():DistToSqr(target:GetPos())
    local TOOFAR = Interact.MaxDistance * Interact.MaxDistance * 1.5
    if dist > TOOFAR then return false end

    return true
end

function Interact.HasTarget(bot)
    return Interact.ValidateTarget(bot.interactTarget)
end

function Interact.TestChance(_bot)
    return lib.TestPercent(Interact.BaseChancePct)
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Player
---@return boolean
function Interact.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not Interact.TestTimer(bot) then return false end
    if Interact.HasTarget(bot) then return true end
    if not Interact.TestChance(bot) then return false end -- can't get a new target bc failed random chance

    local target = Interact.FindOther(bot)
    if not Interact.ValidateTarget(target) then return false end
    return true
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function Interact.OnStart(bot)
    Interact.SetAnimation(bot, nil)
    local target = Interact.FindOther(bot)
    if not Interact.ValidateTarget(target) then return STATUS.FAILURE end

    bot.interactTarget = target
    Interact.SetAnimation(bot, table.Random(Interact.Animations))
    return STATUS.RUNNING
end

---do actions
---@param loco CLocomotor
---@param keyObj KeyFrame
function Interact.DoAction(loco, keyObj)
    local shouldJump = keyObj.action == "jump"
    local shouldCrouch = keyObj.action == "crouch"

    loco:Jump(shouldJump)
    loco:Crouch(shouldCrouch)
end

function Interact.StopActions(loco)
    loco:Jump(false)
    loco:Crouch(false)
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function Interact.OnRunning(bot)
    if Interact.IsAnimationOver(bot) then
        -- print("Animation has concluded for " .. bot:Nick())
        return STATUS.SUCCESS
    end

    local animation, keyframe, nextKeyframeTime = Interact.GetBotAnimation(bot)
    local target = bot.interactTarget

    if not Interact.ValidateTarget(target) then
        -- print("Target is no longer valid for " .. bot:Nick())
        return STATUS.FAILURE
    end

    local keyTbl = animation[keyframe]
    local keyframePos = Interact.GetKeyframePos(target, keyTbl)
    local loco = bot:BotLocomotor()

    if not loco then
        -- print("Locomotor is nil for " .. bot:Nick())
        return STATUS.FAILURE
    end

    loco:LookAt(keyframePos)
    loco:SetGoal(nil) -- Stay in place

    Interact.DoAction(loco, keyTbl)

    if nextKeyframeTime < CurTime() then
        bot.interactAnimationKeyframe = keyframe + 1
        bot.nextKeyframeTime = Interact.GetNextKeyframeTime(animation[keyframe + 1])
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Player
function Interact.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Player
function Interact.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function Interact.OnEnd(bot)
    Interact.SetAnimation(bot, nil)
    bot.lastInteractionTime = CurTime()
    local loco = bot:BotLocomotor()
    Interact.StopActions(loco)
end
