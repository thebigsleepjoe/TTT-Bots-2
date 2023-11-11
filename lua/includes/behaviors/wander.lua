TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Wander = {}

local lib = TTTBots.Lib

local Wander = TTTBots.Behaviors.Wander
Wander.Name = "Wander"
Wander.Description = "Wanders around the map"
Wander.Interruptible = true
Wander.Debug = false

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

local function printf(...)
    print(string.format(...))
end

--- Validate the behavior
function Wander:Validate(bot)
    return true
end

--- Called when the behavior is started
function Wander:OnStart(bot)
    Wander:UpdateWanderGoal(bot) -- sets bot.wander
    return STATUS.Running
end

--- Called when the behavior's last state is running
function Wander:OnRunning(bot)
    if not bot.wander then return Wander:OnStart() end -- force reboot :P

    local hasExpired = self:HasExpired(bot)
    if hasExpired then return STATUS.SUCCESS end

    local wanderPos = bot.wander.targetPos
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
    bot.wander = nil
end

function Wander:DestinationCloseEnough(bot)
    if not bot.wander then return true end
    local dest = bot.wander.targetPos
    local pos = bot:GetPos()
    local dist = pos:Distance(dest)
    return dist < 100
end

function Wander:HasExpired(bot)
    local wander = bot.wander
    if not wander then return true end
    local ctime = CurTime()
    local DIST_CLOSE_THRESH = 100
    local closeEnough = (ctime > wander.timeEndClose) and (bot:GetPos():Distance(wander.targetPos))
    return closeEnough or (wander.timeEndFar < ctime)
end

--- Returns a random nav area in the nearest region to the bot
function Wander:GetRandomNavInRegion(bot)
    return lib.GetRandomNavInNearestRegion(bot:GetPos())
end

--- Gets a random nav area from the entire navmesh
function Wander:GetRandomNav()
    return table.Random(navmesh.GetAllNavAreas())
end

--- Returns a random nav with preference to the current area
function Wander:GetAnyRandomNav(bot)
    return (math.random(1, 5) <= 4 and Wander:GetRandomNavInRegion(bot))
        or
        Wander:GetRandomNav() -- 80% chance of getting a random nav in the nearest region, 20% chance of getting a random nav from the entire navmesh
end

function Wander:UpdateWanderGoal(bot)
    local targetArea
    local targetPos
    local isSpot = false
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return end

    ---------------------------------------------
    -- relevant personality traits: loner, lovescrowds
    ---------------------------------------------
    local isLoner = personality:GetTraitBool("loner")
    local lovesCrowds = personality:GetTraitBool("lovesCrowds")
    local popularNavs = TTTBots.Lib.PopularNavsSorted
    local adhereToPersonality = (isLoner or lovesCrowds) and math.random(1, 5) <= 4
    if adhereToPersonality and #popularNavs > 10 then
        local topNNavs = {}
        local bottomNNavs = {}
        local N = 4

        for i = 1, N do
            if not popularNavs[i] then break end
            table.insert(topNNavs, popularNavs[i])
        end
        for i = #popularNavs - N, #popularNavs do
            if not popularNavs[i] then break end
            table.insert(bottomNNavs, popularNavs[i])
        end

        if lovesCrowds then
            targetArea = navmesh.GetNavAreaByID(table.Random(topNNavs)[1])
            if Wander.Debug then
                printf("Bot %s wandering to a popular area", bot:Nick())
            end
        else
            targetArea = navmesh.GetNavAreaByID(table.Random(bottomNNavs)[1])
            if Wander.Debug then
                printf("Bot %s wandering to an unpopular area", bot:Nick())
            end
        end
    end

    ---------------------------------------------
    -- relevant personality traits: hider, sniper
    -- everyone can hide or go to a sniper spot, but the above traits do it more
    ---------------------------------------------
    local canHide =
        personality:GetTraitBool("hider")
        or math.random(1, 6) == 1
    local canSnipe =
        personality:GetTraitBool("sniper")
        or math.random(1, 6) == 1
    local shouldSpot = math.random(1, 5) <= 4

    if (canHide or canSnipe) and shouldSpot then
        isSpot = true
        local kindStr = (canHide and "hiding") or "sniper"
        local spot = TTTBots.Spots.GetNearestSpotOfCategory(bot:GetPos(), kindStr)
        if spot then
            targetPos = spot
            if Wander.Debug then
                printf("Bot %s wandering to a %s spot", bot:Nick(), kindStr)
            end
        end
    end

    if not targetArea then
        targetArea = Wander:GetAnyRandomNav(bot)
    end

    if targetArea and not targetPos then
        targetPos = targetArea:GetRandomPoint()
    elseif targetPos and not targetArea then
        targetArea = navmesh.GetNearestNavArea(targetPos)
    end

    local time = CurTime()

    local wanderTbl = {
        targetArea = targetArea,
        targetPos = targetPos,
        timeStart = time,
        timeEndFar = time + math.random(6, 24) * (isSpot and 1.5 or 1),
        timeEndClose = time + math.random(3, 12) * (isSpot and 1.5 or 1),
    }

    bot.wander = wanderTbl

    return wanderTbl
end
