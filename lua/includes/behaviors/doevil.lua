TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.DoEvil = {}

local lib = TTTBots.Lib

local DoEvil = TTTBots.Behaviors.DoEvil
DoEvil.Name = "DoEvil"
DoEvil.Description = "Follow commands from the Evil Coordinator module."
DoEvil.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function DoEvil:Validate(bot)
    return lib.IsPlayerAlive and lib.IsEvil(bot)
end

--- Called when the behavior is started
function DoEvil:OnStart(bot)
end

--- Called when the behavior's last state is running
function DoEvil:OnRunning(bot)
end

--- Called when the behavior returns a success state
function DoEvil:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function DoEvil:OnFailure(bot)
end

--- Called when the behavior ends
function DoEvil:OnEnd(bot)
end
