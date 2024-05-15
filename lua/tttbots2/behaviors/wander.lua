TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Wander = {}

local lib = TTTBots.Lib

local Wander = TTTBots.Behaviors.Wander
Wander.Name = "Wander"
Wander.Description = "Wanders around the map"
Wander.Interruptible = true
Wander.Debug = false

Wander.CHANCE_TO_HIDE_IF_TRAIT = 3 -- 1 in X chance of hiding (or going to sniper spot) if we have a relevant trait

local STATUS = TTTBots.STATUS

local function printf(...)
    print(string.format(...))
end

--- Validate the behavior
function Wander.Validate(bot)
    return true
end

--- Called when the behavior is started
function Wander.OnStart(bot)
    Wander.UpdateWanderGoal(bot) -- sets bot.wander
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function Wander.OnRunning(bot)
    if not bot.wander then return Wander.OnStart() end -- force reboot :P

    local hasExpired = Wander.HasExpired(bot)
    if hasExpired then return STATUS.SUCCESS end

    local wanderPos = bot.wander.targetPos
    local loco = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    loco:SetGoal(wanderPos)

    if loco:IsCloseEnough(wanderPos) then
        Wander.StareAtNearbyPlayers(bot, loco)
    end

    return STATUS.RUNNING
end

---Make the bot stare at the nearest player. Useful for when the bot is standing still.
---@param bot Bot
---@param locomotor CLocomotor
function Wander.StareAtNearbyPlayers(bot, locomotor)
    local players = lib.GetAllVisible(bot:GetPos(), false)
    local closest = lib.GetClosest(players, bot:GetPos())

    if closest then
        locomotor:LookAt(closest:GetPos())
    end
end

--- Called when the behavior returns a success state
function Wander.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Wander.OnFailure(bot)
end

--- Called when the behavior ends
function Wander.OnEnd(bot)
    bot.wander = nil
end

function Wander.DestinationCloseEnough(bot)
    if not bot.wander then return true end
    local dest = bot.wander.targetPos
    local pos = bot:GetPos()
    local dist = pos:Distance(dest)
    return dist < 100
end

function Wander.HasExpired(bot)
    local wander = bot.wander
    if not wander then return true end
    local ctime = CurTime()
    local DIST_CLOSE_THRESH = 100
    local closeEnough = (ctime > wander.timeEndClose) and (bot:GetPos():Distance(wander.targetPos))
    return closeEnough or (wander.timeEndFar < ctime)
end

--- Returns a random nav area in the nearest region to the bot
function Wander.GetRandomNavInRegion(bot)
    if not (bot and bot.GetPos) then
        error("Unknown bot ent: " .. tostring(bot), 5)
        return nil
    end
    return lib.GetRandomNavInNearestRegion(bot:GetPos())
end

--- Gets a random nav area from the entire navmesh
function Wander.GetRandomNav()
    return table.Random(navmesh.GetAllNavAreas())
end

---Return if the role can see all C4s inherently, or if it must have someone spot it first
---@param bot Bot
---@return boolean
function Wander.BotCanSeeAllC4(bot)
    local role = TTTBots.Roles.GetRoleFor(bot)
    local canPlant = role:GetPlantsC4()

    return canPlant
end

--- Returns a random nav with preference to the current area
function Wander.GetAnyRandomNav(bot, level)
    level = level or 0
    -- 80% chance of getting a random nav in the nearest region, 20% chance of getting a random nav from the entire navmesh
    local area = (math.random(1, 5) <= 4 and Wander.GetRandomNavInRegion(bot)) or Wander.GetRandomNav()

    if level < 5 then
        -- Test if the area is near a known bomb
        local omniscient = Wander.BotCanSeeAllC4(bot)
        local bombs = (omniscient and TTTBots.Match.AllArmedC4s) or TTTBots.Match.SpottedC4s

        for bomb, _ in pairs(bombs) do
            if not IsValid(bomb) then continue end
            local bombPos = bomb:GetPos()
            local dist = bombPos:Distance(area:GetCenter())
            if dist < 1000 then
                return Wander.GetAnyRandomNav(bot, level + 1)
            end
        end
    end

    return area
end

---Finds a place to hide/snipe at. Returns if we found a spot and where it is (or nil)
---@param bot Bot
---@return boolean foundSpot
---@return Vector? pos pos or nil if we didn't find a spot
function Wander.FindSpotFor(bot)
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return false, nil end

    local randomChance = math.random(1, 10) == 1

    local isHidingRole = TTTBots.Roles.GetRoleFor(bot):GetCanHide()
    local canHide = isHidingRole and (personality:GetTraitBool("hider") or randomChance)

    local isSnipingRole = TTTBots.Roles.GetRoleFor(bot):GetCanSnipe()
    local canSnipe = isSnipingRole and (personality:GetTraitBool("sniper") or randomChance)

    local randomChanceTrait = math.random(1, Wander.CHANCE_TO_HIDE_IF_TRAIT) == 1

    if (canHide or canSnipe) and randomChanceTrait then
        local kindStr = (canHide and "hiding") or "sniper"
        local spot = TTTBots.Spots.GetNearestSpotOfCategory(bot:GetPos(), kindStr)
        if spot then
            if Wander.Debug then
                printf("Bot %s wandering to a %s spot", bot:Nick(), kindStr)
            end
            return true, spot + Vector(0, 0, 64)
        end
    end
    return false, nil
end

function Wander.UpdateWanderGoal(bot)
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
    local isSpot, newPos = Wander.FindSpotFor(bot)
    if newPos then targetPos = newPos end

    if not targetArea then
        targetArea = Wander.GetAnyRandomNav(bot)
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
