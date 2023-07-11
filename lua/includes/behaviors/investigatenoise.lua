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
    Running = 1,
    Success = 2,
    Failure = 3,
}

function InvestigateNoise:GetInterestingSounds(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local sounds = memory:GetRecentSounds()
    print("#sounds", #sounds)
    local interesting = {}
    for i, v in pairs(sounds) do
        print("sound", v.name)
        local wasme = v.ent == bot or v.ply == bot
        if not wasme and InvestigateNoise.INVESTIGATE_CATEGORIES[v.name] then
            table.insert(interesting, v)
        end
    end
    return interesting
end

function InvestigateNoise:FindClosestSound(bot, mustBeVisible)
    mustBeVisible = mustBeVisible or false
    local sounds = self:GetInterestingSounds(bot)
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

function InvestigateNoise:OnStart(bot)
    bot:Say("I heard that!")
    return STATUS.Running
end

function InvestigateNoise:OnRunning(bot)
    local loco = bot.components.locomotor
    local closestVisible = self:FindClosestSound(bot, true)
    if closestVisible then
        loco:AimAt(closestVisible.pos)
        return STATUS.Running
    end

    local closestHidden = self:FindClosestSound(bot, false)
    if closestHidden then
        loco:AimAt(closestHidden.pos)
        loco:SetGoalPos(closestHidden.pos)
        return STATUS.Running
    end

    return STATUS.Success
end

function InvestigateNoise:Validate(bot)
    return #self:GetInterestingSounds(bot) > 0
end

function InvestigateNoise:OnFailure(bot) end

function InvestigateNoise:OnSuccess(bot) end

function InvestigateNoise:OnEnd(bot) end
