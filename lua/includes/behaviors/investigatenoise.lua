---@class InvestigateNoise
TTTBots.Behaviors.InvestigateNoise = {}

local lib = TTTBots.Lib

---@class InvestigateNoise
local InvestigateNoise = TTTBots.Behaviors.InvestigateNoise

InvestigateNoise.INVESTIGATE_CATEGORIES = {
    Gunshot = true,
    Death = true,
    C4Beep = true,
    Explosion = true
}

function InvestigateNoise:GetInterestingSounds(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local sounds = memory:GetRecentSounds()
    local interesting = {}
    for i, v in pairs(sounds) do
        local wasme = v.ent == bot or v.ply == bot
        if not wasme and InvestigateNoise.INVESTIGATE_CATEGORIES[v.name] then
            table.insert(interesting, v)
        end
    end
    return interesting
end

function InvestigateNoise:OnStart(bot) end

function InvestigateNoise:OnRunning(bot) end

function InvestigateNoise:Validate(bot) end

function InvestigateNoise:OnFailure(bot) end

function InvestigateNoise:OnSuccess(bot) end

function InvestigateNoise:OnEnd(bot) end
