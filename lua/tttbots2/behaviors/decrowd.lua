--- Similar to BWander's decrowding mechanic, 
--- but this behavior is specifically focused on preventing overcrowding.



---@class BDecrowd : BBase
TTTBots.Behaviors.Decrowd = {}

local lib = TTTBots.Lib

---@class BDecrowd
local Decrowd = TTTBots.Behaviors.Decrowd
Decrowd.Name = "Decrowd"
Decrowd.Description = "Try to prevent overcrowding."
Decrowd.Interruptible = true
Decrowd.MaxNearbyPlayers = 3

---@class Bot
---@field targetRetreatArea CNavArea?

local STATUS = TTTBots.STATUS

---@param bot Bot
function Decrowd.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Always fail if the bot loves crowding.
    local personality = bot:BotPersonality()
    if personality:GetTraitBool("lovesCrowds") then return false end

    -- Only return true if there are too many people around us.
    local memory = bot:BotMemory()
    local visiblePlys = memory:GetRecentlySeenPlayers(5)

    return (#visiblePlys > Decrowd.MaxNearbyPlayers)
end

function Decrowd.FindRetreatArea(bot)
    local botRegion = TTTBots.Lib.GetNearestRegion(bot:GetPos())
    for i = 1, 5 do
        local randomArea = TTTBots.Lib.GetRandomNavInRegion(botRegion)
        local nWitnesses = TTTBots.Lib.GetAllWitnessesBasic(
            randomArea:GetCenter(),
            TTTBots.Match.AlivePlayers,
            bot
        )

        if #nWitnesses <= 1 then
            return randomArea
        end
    end

    -- Fallback just in case.
    return table.Random(navmesh.GetAllNavAreas())
end

---@param bot Bot
function Decrowd.OnStart(bot)
    bot.targetRetreatArea = Decrowd.FindRetreatArea(bot)
    return STATUS.RUNNING
end

---@param bot Bot
function Decrowd.OnRunning(bot)
    local targetPos = bot.targetRetreatArea:GetCenter()
    bot:BotLocomotor():SetGoal(targetPos)

    return STATUS.RUNNING
end

---@param bot Bot
function Decrowd.OnSuccess(bot)
end

---@param bot Bot
function Decrowd.OnFailure(bot)
end

---@param bot Bot
function Decrowd.OnEnd(bot)
    bot:BotLocomotor():StopMoving()
end
