TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.InvestigateCorpse = {}

local lib = TTTBots.Lib

local InvestigateCorpse = TTTBots.Behaviors.InvestigateCorpse
InvestigateCorpse.Name = "InvestigateCorpse"
InvestigateCorpse.Description = "If you're reading this, something went wrong."
InvestigateCorpse.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function InvestigateCorpse:Validate(bot)
end

--- Called when the behavior is started
function InvestigateCorpse:OnStart(bot)
end

--- Called when the behavior's last state is running
function InvestigateCorpse:OnRunning(bot)
end

--- Called when the behavior returns a success state
function InvestigateCorpse:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function InvestigateCorpse:OnFailure(bot)
end

--- Called when the behavior ends
function InvestigateCorpse:OnEnd(bot)
end
