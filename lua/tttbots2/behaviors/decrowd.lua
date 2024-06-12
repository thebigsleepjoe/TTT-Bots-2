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
Decrowd.NearbyThreshold = 800 --- How close a player has to be to be considered "nearby"

---@class Bot
---@field targetRetreatPos Vector?

local STATUS = TTTBots.STATUS

---@param bot Bot
function Decrowd.Validate(bot)
    -- Always fail if the bot loves crowding.
    local personality = bot:BotPersonality()
    if personality:GetTraitBool("lovesCrowds") then return false end

    -- Only return true if there are too many people around us.
    local memory = bot:BotMemory()
    local visiblePlys = memory:GetRecentlySeenPlayers(5)

    local count = Decrowd.CountNearby(bot, visiblePlys)

    return (count > Decrowd.MaxNearbyPlayers)
end

function Decrowd.CountNearby(bot, plyTable)
    local count = 0
    for i, ply in pairs(plyTable) do
        local plyPos = ply:GetPos()
        local dist = bot:GetPos():Distance(plyPos)
        if dist < Decrowd.NearbyThreshold then
            count = count + 1
        end
    end
    return count

end

---Returns the number of living witnesses currently that can see pos (and are close-ish to it).
---@param bot Bot
---@param pos Vector
---@return number
function Decrowd.GetWitnessesAround(bot, pos)

    local witnesses = TTTBots.Lib.GetAllWitnessesBasic(
        pos,
        TTTBots.Match.AlivePlayers,
        bot
    )

    local count = Decrowd.CountNearby(bot, witnesses)

    return count
end

---Tries to locate a hiding spot without a lot of witnesses.
---Is not guaranteed to come up with a result due to performance reasons.
---@param bot Bot
---@return Vector?
function Decrowd.FindRetreatSpot(bot)
    local spots = TTTBots.Spots.GetSpotsInCategory("hiding")

    for i = 1, 5 do
        local randomSpot = table.Random(spots)
        local nWitnesses = Decrowd.GetWitnessesAround(bot, randomSpot)

        if nWitnesses <= 1 then
            return randomSpot
        end
    end
end

function Decrowd.FindRetreatArea(bot)
    local botRegion = TTTBots.Lib.GetNearestRegion(bot:GetPos())
    for i = 1, 5 do
        local randomArea = TTTBots.Lib.GetRandomNavInRegion(botRegion)
        local nWitnesses = Decrowd.GetWitnessesAround(bot, randomArea:GetPos())

        if nWitnesses <= 1 then
            return randomArea
        end
    end

    -- Fallback just in case.
    return table.Random(navmesh.GetAllNavAreas())
end

---@param bot Bot
function Decrowd.OnStart(bot)
    bot.targetRetreatPos = (
        Decrowd.FindRetreatSpot(bot)
        or Decrowd.FindRetreatArea(bot):GetPos()
    )
    return STATUS.RUNNING
end

---@param bot Bot
function Decrowd.OnRunning(bot)
    if not bot.targetRetreatPos then return Decrowd.OnStart(bot) end
    bot:BotLocomotor():SetGoal(bot.targetRetreatPos)

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
