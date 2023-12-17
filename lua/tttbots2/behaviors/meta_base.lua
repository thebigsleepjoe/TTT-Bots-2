--- This file is a base behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta

TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BBase
TTTBots.Behaviors.Base = {}

local lib = TTTBots.Lib

---@class BBase
local BehaviorBase = TTTBots.Behaviors.Base
BehaviorBase.Name = "Base"
BehaviorBase.Description = "Change me"
BehaviorBase.Interruptible = true

---@enum BStatus
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Player
---@return boolean
function BehaviorBase.Validate(bot)
    return true
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function BehaviorBase.OnStart(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function BehaviorBase.OnRunning(bot)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Player
function BehaviorBase.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Player
function BehaviorBase.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function BehaviorBase.OnEnd(bot)
end
