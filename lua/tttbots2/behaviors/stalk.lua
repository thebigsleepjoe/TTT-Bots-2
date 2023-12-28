TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BStalk
TTTBots.Behaviors.Stalk = {}

local lib = TTTBots.Lib

---@class BStalk
local Stalk = TTTBots.Behaviors.Stalk
Stalk.Name = "Stalk"
Stalk.Description = "Stalk a player (or random player) and ultimately kill them."
Stalk.Interruptible = true

---@enum BStatus
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

---Give a weight to how isolated 'other' is to us. This is used to determine who to stalk.
---A higher isolation means the player is more isolated, and thus a better target for stalking.
---@param bot Player
---@param other Player
---@return number
function Stalk.RateIsolation(bot, other)
    if not IsValid(bot) or not IsValid(other) then return -math.huge end
    local isolation = 0

    local VISIBLE_FACTOR = -0.5    -- Penalty per visible player to other
    local VISIBLE_ME_FACTOR = 0.5  -- Bonus if we can already see other
    local DISTANCE_FACTOR = -0.001 -- Distance penalty per hammer unit to bot

    local witnesses = lib.GetAllWitnessesBasic(other:EyePos(), TTTBots.Roles.GetNonAllies(bot), bot)
    isolation = isolation + (VISIBLE_FACTOR * table.Count(witnesses))
    isolation = isolation + (DISTANCE_FACTOR * bot:GetPos():Distance(other:GetPos()))
    isolation = isolation + (VISIBLE_ME_FACTOR * (bot:Visible(other) and 1 or 0))
    isolation = isolation + (math.random(-3, 3) / 10) -- Add a bit of randomness to the isolation

    return isolation
end

---Find the best target to stalk, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Player
---@return Player?
---@return number
function Stalk.FindTarget(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local bestIsolation = -math.huge
    local bestTarget = nil

    for _, other in ipairs(nonAllies) do
        local isolation = Stalk.RateIsolation(bot, other)
        if isolation > bestIsolation then
            bestIsolation = isolation
            bestTarget = other
        end
    end

    return bestTarget, bestIsolation
end

function Stalk.ClearTarget(bot)
    bot.StalkTarget = nil
end

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Stalk.ClearTarget.
---@see Stalk.ClearTarget
---@param bot Player
---@param target Player?
function Stalk.SetTarget(bot, target)
    bot.StalkTarget = target or Stalk.FindTarget(bot)
end

function Stalk.GetTarget(bot)
    return bot.StalkTarget
end

function Stalk.ValidateTarget(bot)
    local target = Stalk.GetTarget(bot)
    return target and IsValid(target) and lib.IsPlayerAlive(target)
end

---Should we start stalking? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Player
---@return boolean
function Stalk.ShouldStartStalking(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Player
---@return boolean
function Stalk.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end -- Do not stalk if we're killing someone already.
    return Stalk.ValidateTarget(bot) or Stalk.ShouldStartStalking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function Stalk.OnStart(bot)
    if not Stalk.ValidateTarget(bot) then
        Stalk.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function Stalk.OnRunning(bot)
    local target = Stalk.GetTarget(bot)
    if not Stalk.ValidateTarget(bot) then return STATUS.FAILURE end
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    if not loco then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()

    local witnesses = lib.GetAllWitnessesBasic(targetPos, TTTBots.Roles.GetNonAllies(bot), bot)
    if table.IsEmpty(witnesses) then
        if math.random(1, TTTBots.Tickrate) == 1 then -- Just some extra randomness for fun!
            bot.attackTarget = target
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Player
function Stalk.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Player
function Stalk.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function Stalk.OnEnd(bot)
    Stalk.ClearTarget(bot)
end
