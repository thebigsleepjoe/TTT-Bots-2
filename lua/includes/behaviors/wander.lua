TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Wander = {}

local lib = TTTBots.Lib

local Wander = TTTBots.Behaviors.Wander
Wander.Name = "Wander"
Wander.Description = "Wanders around the map"
Wander.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Validate the behavior
function Wander:Validate(bot)
    return true
end

--- Called when the behavior is started
function Wander:OnStart(bot)
    bot.wander = {
        tick = 0,
        destArea = self:GetWanderableArea(bot),
        wanderTime = 200, -- Maximum time before re-generating a destination
    }
    return STATUS.Running
end

--- Called when the behavior's last state is running
function Wander:OnRunning(bot)
    if not bot.wander.destArea then bot.wander.destArea = self:GetWanderableArea(bot) end

    local dest = bot.wander.destArea:GetCenter()
    local withinRange = self:DestinationWithinRange(bot, 100)
    bot.wander.tick = bot.wander.tick + 1
    if bot.wander.tick > bot.wander.wanderTime or withinRange then
        bot.wander.tick = 0
        bot.wander.destArea = self:GetWanderableArea(bot)
        return STATUS.Success
    end

    local wanderPos = dest
    bot.components.locomotor:SetGoalPos(wanderPos)

    return STATUS.Running
end

--- Called when the behavior returns a success state
function Wander:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Wander:OnFailure(bot)
end

--- Called when the behavior ends
function Wander:OnEnd(bot)
    bot.wander = {}
end

function Wander:DestinationWithinRange(bot, range)
    local dest = bot.wander.destArea:GetCenter()
    local pos = bot:GetPos()
    local dist = pos:Distance(dest)
    return dist < range
end

function Wander:GetWanderableArea(bot)
    -- relevant personality traits: loner, lovescrowds
    local isLoner = bot:HasPTrait("loner")
    local lovesCrowds = bot:HasPTrait("lovescrowds")

    local popularNavs = TTTBots.Lib.PopularNavsSorted
    local adhereToPersonality = (isLoner and not lovesCrowds) and math.random(1, 5) <= 4

    local area = table.Random(navmesh.GetAllNavAreas())
    if adhereToPersonality and #popularNavs > 10 then
        local top10Navs = {}
        local bottom10Navs = {}

        for i = 1, 10 do
            if not popularNavs[i] then break end
            table.insert(top10Navs, popularNavs[i])
        end
        for i = #popularNavs - 10, #popularNavs do
            if not popularNavs[i] then break end
            table.insert(bottom10Navs, popularNavs[i])
        end

        if lovesCrowds then
            area = navmesh.GetNavAreaByID(table.Random(top10Navs)[1])
        else
            area = navmesh.GetNavAreaByID(table.Random(bottom10Navs)[1])
        end
    end

    return area
end
