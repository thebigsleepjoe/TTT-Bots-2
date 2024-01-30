--- This file is a MingeCrowbar behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta

TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BMingeCrowbar
TTTBots.Behaviors.MingeCrowbar = {}

local lib = TTTBots.Lib

---@class BMingeCrowbar
local MingeCrowbar = TTTBots.Behaviors.MingeCrowbar
MingeCrowbar.Name = "MingeCrowbar"
MingeCrowbar.Description = "Minge (mostly push-related) with the crowbar."
MingeCrowbar.Interruptible = true

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
function MingeCrowbar.Validate(bot)
    return true
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function MingeCrowbar.OnStart(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function MingeCrowbar.OnRunning(bot)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Player
function MingeCrowbar.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Player
function MingeCrowbar.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function MingeCrowbar.OnEnd(bot)
end
