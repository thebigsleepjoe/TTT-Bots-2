TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BStalk
TTTBots.Behaviors.Stalk = {}

local lib = TTTBots.Lib

---@class BStalk
local Stalk = TTTBots.Behaviors.Stalk
Stalk.Name = "Stalk"
Stalk.Description = "Stalk a player (or random player) and ultimately kill them."
Stalk.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to stalk.
---A higher isolation means the player is more isolated, and thus a better target for stalking.
---@param bot Bot
---@param other Player
---@return number
function Stalk.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to stalk, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function Stalk.FindTarget(bot)
    return lib.FindIsolatedTarget(bot)
end

function Stalk.ClearTarget(bot)
    bot.StalkTarget = nil
end

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Stalk.ClearTarget.
---@see Stalk.ClearTarget
---@param bot Bot
---@param target Player?
---@param isolationScore number?
function Stalk.SetTarget(bot, target, isolationScore)
    bot.StalkTarget = target or Stalk.FindTarget(bot)
    bot.StalkScore = isolationScore or Stalk.RateIsolation(bot, bot.StalkTarget)
end

function Stalk.GetTarget(bot)
    return bot.StalkTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function Stalk.ValidateTarget(bot, target)
    local target = target or Stalk.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    return valid
end

---Should we start stalking? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function Stalk.ShouldStartStalking(bot)
    -- local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() -- and chance
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function Stalk.CheckForBetterTarget(bot)
    local currentScore = bot.StalkScore or -math.huge
    local alternative, altScore = Stalk.FindTarget(bot)

    if not alternative then return end
    if not Stalk.ValidateTarget(bot, alternative) then return end

    -- check for a difference of at least +1
    if altScore and altScore - currentScore >= 1 then
        Stalk.SetTarget(bot, alternative, altScore)
    end
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Stalk.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end -- Do not stalk if we're killing someone already.
    return Stalk.ValidateTarget(bot) or Stalk.ShouldStartStalking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnStart(bot)
    if not Stalk.ValidateTarget(bot) then
        Stalk.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnRunning(bot)
    -- Stalk.CheckForBetterTarget(bot)
    if not Stalk.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = Stalk.GetTarget(bot)
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
    if table.Count(witnesses) <= 1 then
        if math.random(1, 3) == 1 then -- Just some extra randomness for fun!
            bot:SetAttackTarget(target)
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Stalk.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Stalk.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Stalk.OnEnd(bot)
    Stalk.ClearTarget(bot)
end
