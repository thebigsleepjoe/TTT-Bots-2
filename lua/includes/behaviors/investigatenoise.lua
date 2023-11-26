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

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

function InvestigateNoise.GetInterestingSounds(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local sounds = memory:GetRecentSounds()
    local interesting = {}
    for i, v in pairs(sounds) do
        local wasme = v.ent == bot or v.ply == bot
        if not wasme and InvestigateNoise.INVESTIGATE_CATEGORIES[v.sound] then
            table.insert(interesting, v)
        end
    end
    return interesting
end

function InvestigateNoise.FindClosestSound(bot, mustBeVisible)
    mustBeVisible = mustBeVisible or false
    local sounds = InvestigateNoise.GetInterestingSounds(bot)
    local closestSound = nil
    local closestDist
    for i, v in pairs(sounds) do
        local dist = bot:GetPos():Distance(v.pos)
        local visible = (mustBeVisible and bot:VisibleVec(v.pos)) or not mustBeVisible
        if (closestDist == nil or dist < closestDist) and visible then
            closestDist = dist
            closestSound = v
        end
    end
    return closestSound
end

function InvestigateNoise.OnStart(bot)
    bot.components.chatter:On("InvestigateNoise", {})
    return STATUS.Running
end

function InvestigateNoise.OnRunning(bot)
    local loco = bot.components.locomotor
    local closestVisible = InvestigateNoise.FindClosestSound(bot, true)
    if closestVisible then
        loco:AimAt(closestVisible.pos + Vector(0, 0, 72))
        return STATUS.Running
    end

    -- Skip investigating if we don't want to.
    if not InvestigateNoise.ShouldInvestigateNoise(bot) then
        return STATUS.Failure
    end

    local closestHidden = InvestigateNoise.FindClosestSound(bot, false)
    if closestHidden then
        loco:AimAt(closestHidden.pos + Vector(0, 0, 72))
        loco:SetGoalPos(closestHidden.pos)
        return STATUS.Running
    end

    return STATUS.Success
end

--- Return true/false based off of a random chance. This is meant to be called every tick (5x per sec as of writing), so the chance is low by default.
---@param bot Player
function InvestigateNoise.ShouldInvestigateNoise(bot)
    local MTB = lib.GetConVarInt("noise_investigate_mtb")
    if bot.investigateNoiseTimer and bot.investigateNoiseTimer > CurTime() then
        return false
    else
        bot.investigateNoiseTimer = CurTime() + MTB
    end
    local mult = bot:GetTraitMult("investigateNoise")
    local baseChance = lib.GetConVarInt("noise_investigate_chance")
    local pct = baseChance * mult

    local passed = lib.CalculatePercentChance(pct)
    return passed
end

function InvestigateNoise.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    return #InvestigateNoise.GetInterestingSounds(bot) > 0
end

function InvestigateNoise.OnFailure(bot) end

function InvestigateNoise.OnSuccess(bot) end

function InvestigateNoise.OnEnd(bot) end
