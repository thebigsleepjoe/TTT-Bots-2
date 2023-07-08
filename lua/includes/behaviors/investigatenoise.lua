---@class InvestigateNoise
TTTBots.Behaviors.InvestigateNoise = {}

local lib = TTTBots.Lib

---@class InvestigateNoise
local InvestigateNoise = TTTBots.Behaviors.InvestigateNoise

InvestigateNoise.INVESTIGATE_CATEGORIES = {
    "Gunshot",
    "Death",
    "C4Beep",
    "Explosion"
}

function InvestigateNoise:GetRecentSounds(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local sounds = memory:GetRecentSounds()
end

function InvestigateNoise:OnStart(bot) end

function InvestigateNoise:OnRunning(bot) end

function InvestigateNoise:Validate(bot) end

function InvestigateNoise:OnFailure(bot) end

function InvestigateNoise:OnSuccess(bot) end

function InvestigateNoise:OnEnd(bot) end
