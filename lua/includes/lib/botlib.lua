TTTBots.Lib = TTTBots.Lib or {}

include("includes/data/usernames.lua")

-- Import components for bot creation
TTTBots.Components = {}
include("includes/components/locomotor.lua")
include("includes/components/obstacletracker.lua")
include("includes/components/inventorymgr.lua")
include("includes/components/personality.lua")
include("includes/components/memory.lua")
include("includes/components/morality.lua")
include("includes/components/chatter.lua")

local BASIC_VISIBILITY_RANGE = 4000 --- Threshold to be considred for the :VisibleVec function in a basic visibility check.

local format = string.format

local alivePlayers = {}

local function updateAlivePlayers()
    alivePlayers = {}
    for i, ply in pairs(player.GetAll()) do
        alivePlayers[ply] = (IsValid(ply) and not (ply:IsSpec()) and ply:Alive() and ply:Health() > 0)
    end
end
timer.Create("TTTBots.Lib.AlivePlayersInterval", 1 / TTTBots.Tickrate, 0, updateAlivePlayers)

-- Check if not :IsSpec and :Alive
function TTTBots.Lib.IsPlayerAlive(ply)
    return alivePlayers[ply]
end

function TTTBots.Lib.GetAlivePlayers()
    local alive = {}
    for _, ply in ipairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            table.insert(alive, ply)
        end
    end
    return alive
end

function TTTBots.Lib.GetAliveBots()
    local alive = {}
    for _, ply in ipairs(TTTBots.Bots) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            table.insert(alive, ply)
        end
    end
    return alive
end

function TTTBots.Lib.GetAliveEvilBots()
    local alive = {}
    for _, ply in ipairs(TTTBots.Bots) do
        if TTTBots.Lib.IsPlayerAlive(ply) and TTTBots.Lib.IsEvil(ply) then
            table.insert(alive, ply)
        end
    end
    return alive
end

-- Generate lowercase alphanumeric string of length 6
function TTTBots.Lib.GenerateID()
    local id = ""
    for i = 1, 6 do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

function TTTBots.Lib.PrintInitMessage()
    print("~~~~~~~~~~~~~~~~~~~~~")
    print("TTT Bots initialized!")
    print(format("Version: %s", TTTBots.Version))
    print(format("Number of players: %s/%s", #player.GetAll(), game.MaxPlayers()))
    print(format("Gamemode: %s", engine.ActiveGamemode()) ..
        " | (Compatible = " .. tostring(TTTBots.Lib.CheckCompatibleGamemode()) .. ")")
    print(
        "NOTE: If you are reading this as a dedicated server owner, you cannot use chat commands remotely, your character must be in the server for that. You may still use most concommands.")
    print("~~~~~~~~~~~~~~~~~~~~~")
end

--- Checks if there are currently any player slots available
---@return boolean
function TTTBots.Lib.CheckIfPlayerSlots()
    return not (#player.GetAll() >= game.MaxPlayers())
end

--- Like CanSee, but the traces include everything that could stop a bullet.
---@param ply1 Player
---@param ply2 Player
---@return boolean
function TTTBots.Lib.CanShoot(ply1, ply2)
    -- This is a very expensive operation. Too bad!
    if not IsValid(ply1) or not IsValid(ply2) then return false end
    local start = ply1:EyePos()
    local obstacles = TTTBots.Components.ObstacleTracker.Breakables
    local filter = table.Add({ ply1 }, obstacles)

    -- Start at the eyes
    local targetEyes = ply2:EyePos()
    local traceEyes = util.TraceLine({ start = start, endpos = targetEyes, filter = filter })
    if traceEyes.Entity == ply2 then return true end

    -- Then the feet
    local targetFeet = ply2:GetPos()
    local traceFeet = util.TraceLine({ start = start, endpos = targetFeet, filter = filter })
    if traceFeet.Entity == ply2 then return true end

    -- Then the center
    local targetCenter = ply2:GetPos() + Vector(0, 0, 32)
    local traceCenter = util.TraceLine({ start = start, endpos = targetCenter, filter = filter })
    if traceCenter.Entity == ply2 then return true end

    return false
end

local cached_navs_by_size = {}
function TTTBots.Lib.GetNavsOfGreaterArea(area)
    area = math.floor(area)
    if cached_navs_by_size[area] then return cached_navs_by_size[area] end
    local navs = navmesh.GetAllNavAreas()
    local filtered = TTTBots.Lib.FilterTable(navs, function(nav)
        return nav:GetSizeX() * nav:GetSizeY() >= area
    end)
    cached_navs_by_size[area] = filtered
    return filtered
end

function TTTBots.Lib.CallEveryNTicks(bot, callback, N)
    local tick = bot.tick or 0
    if tick % N == 0 then
        callback()
    end
end

---@param ply1 Player1
---@param ply2 Player2
function TTTBots.Lib.CanSee(ply1, ply2)
    if not IsValid(ply1) or not IsValid(ply2) then return false end
    local start = ply1:EyePos()

    -- Start at the eyes
    local targetEyes = ply2:EyePos()
    local traceEyes = util.TraceLine({ start = start, endpos = targetEyes, filter = ply1, mask = MASK_SHOT })
    if traceEyes.Entity == ply2 then return true end

    -- Then the feet
    local targetFeet = ply2:GetPos()
    local traceFeet = util.TraceLine({ start = start, endpos = targetFeet, filter = ply1, mask = MASK_SHOT })
    if traceFeet.Entity == ply2 then return true end

    -- Then the center
    local targetCenter = ply2:GetPos() + Vector(0, 0, 32)
    local traceCenter = util.TraceLine({ start = start, endpos = targetCenter, filter = ply1, mask = MASK_SHOT })
    if traceCenter.Entity == ply2 then return true end

    return false
end

---@param ply Player
---@param pos Vector
---@param arc number The arc, in degrees, that the player can see. e.g., 90* = 45* in both directions
---@return boolean CanSee
function TTTBots.Lib.CanSeeArc(ply, pos, arc)
    if not IsValid(ply) then return false end

    local start = ply:EyePos()
    local forward = ply:GetAimVector()
    local toPos = (pos - start):GetNormalized()

    -- Angle between the player's forward direction and the direction to pos
    local angle = math.deg(math.acos(forward:Dot(toPos)))

    -- Check if the position is within the player's arc of vision
    if angle > arc / 2 then
        return false
    end

    return ply:VisibleVec(pos)
end

--- Return a table of every given player within range that also have a sightline to the position.
---@param pos Vector The position to check
---@param playerTbl table<Player>|nil (optional) defaults to all living players
---@param ignorePly Player|nil a player to ignore in the check, if any
function TTTBots.Lib.GetAllWitnessesBasic(pos, playerTbl, ignorePly)
    local RANGE = BASIC_VISIBILITY_RANGE
    local witnesses = {}
    for i, ply in pairs(playerTbl) do
        if ply:GetPos():Distance(pos) <= RANGE then
            if ply == ignorePly then continue end
            local sawthat = ply:VisibleVec(pos)
            if sawthat then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

---Get a list of players/bots that can see the position. This factors in for a FOV of 90.
---@param pos Vector
---@param botsOnly boolean
---@return table
function TTTBots.Lib.GetAllWitnesses(pos, botsOnly)
    local witnesses = {}
    for _, ply in ipairs(botsOnly and TTTBots.Bots or player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            local sawthat = TTTBots.Lib.CanSeeArc(ply, pos, 90)
            if sawthat then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

function TTTBots.Lib.GetRandomAdjacent(nav)
    local adjacent = nav:GetAdjacentAreas()
    local random = math.random(1, #adjacent)
    return adjacent[random]
end

function TTTBots.Lib.GetRandomAdjacentNth(nav, N, i)
    local adjacent = nav:GetAdjacentAreas()
    local random = math.random(1, #adjacent)
    if i == N then return adjacent[random] end
    return TTTBots.Lib.GetRandomAdjacentNth(adjacent[random], N, i + 1)
end

--- A table of [key] = weight
---@class WeightedTable
---@field public key any Can be a table, number, string, any value.
---@field public weight number The weight relative to the rest of the table.

--- Creates a WeightedTable object.
---@param element any Can be a table, number, string, any value.
---@param weight number The weight relative to the rest of the table.
---@return WeightedTable
function TTTBots.Lib.SetWeight(element, weight)
    return { key = element, weight = weight }
end

--- Get all visible nav areas to the given nav, that have a center within maxdist.
---@param nav CNavArea
---@param maxdist number
function TTTBots.Lib.GetAllVisibleWithinDist(nav, maxdist)
    local allVisible = nav:GetVisibleAreas()
    local filteredDist = TTTBots.Lib.FilterTable(allVisible, function(nav2)
        return nav:GetCenter():Distance(nav2:GetCenter()) <= maxdist
    end)

    return filteredDist
end

--- Returns a weighted random result from the table.
--- This function accepts an array of WeightedTable objects, calculates the total weight,
--- selects a random number in the range of total weight, then iterates through the array
--- adding the weight of each item to a counter until it exceeds or equals to the random number.
--- At that point, it returns the key of the current item.
---@param weightedTbl WeightedTable[] An array of WeightedTable objects.
---@return any The key of the randomly selected WeightedTable item.
function TTTBots.Lib.RandomWeighted(weightedTblTbl)
    assert(#weightedTblTbl > 0, "Table is empty")

    local totalWeight = 0
    for i = 1, #weightedTblTbl do
        totalWeight = totalWeight + weightedTblTbl[i].weight
    end

    local random = math.random(0, totalWeight)
    local currentWeight = 0
    for i = 1, #weightedTblTbl do
        currentWeight = currentWeight + weightedTblTbl[i].weight
        if random <= currentWeight then
            return weightedTblTbl[i].key
        end
    end
end

--- Similar to GetAllWitnesses, but internally uses CanSee instead of CanSeeArc (so 360*)
function TTTBots.Lib.GetAllWitnesses360(pos)
    local witnesses = {}
    for _, ply in ipairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            local sawthat = TTTBots.Lib.CanSee(ply, pos)
            if sawthat then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

--- Like GetAllWitnesses360, but uses the :Visible function instead of CanSee, for greater optimization.
---@param pos Vector
---@param innocentOnly boolean Only return innocent (not lib.IsEvil) players
---@return table<Player> witnesses A table of players that can see the position.
function TTTBots.Lib.GetAllVisible(pos, innocentOnly)
    local witnesses = {}
    for _, ply in ipairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) and (not innocentOnly or not TTTBots.Lib.IsEvil(ply)) then
            local sawthat = ply:VisibleVec(pos)
            if sawthat then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

--- Iterate through players on the server and return the first player with the given nickname
---@param nick string
---@return Player|nil
function TTTBots.Lib.GetPlayerByNick(nick)
    local plys = player.GetAll()
    for i, v in ipairs(plys) do
        if not IsValid(v) then continue end
        if v:Nick() == nick then return v end
    end
    return
end

--- Get the number of free player slots
---@return number
function TTTBots.Lib.GetFreePlayerSlots()
    return game.MaxPlayers() - #player.GetAll()
end

--- Equivalent of GetConVar("ttt_bot_debug_(debugType)"):GetBool()
---@param debugType string
---@return boolean
function TTTBots.Lib.GetDebugFor(debugType)
    return GetConVar("ttt_bot_debug_" .. debugType):GetBool()
end

--- XY Distance between two Vectors
---@param pos1 any
---@param pos2 any
---@return number
function TTTBots.Lib.DistanceXY(pos1, pos2)
    return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

local isEvilCache = {}
local EVIL_CACHE_DURATION = 5 -- Duration in seconds for how long to cache results.

--- Uses built-in ply:HasEvilTeam but is nil-safe. Basically if they're a traitor.
---@param ply Player
---@param skipCache boolean|nil Optional, defaults to false
---@return boolean
function TTTBots.Lib.IsEvil(ply, skipCache)
    local currentTime = CurTime()
    if not skipCache then
        -- Cleanup expired cache entries.
        for k, v in pairs(isEvilCache) do
            if currentTime - v.time > EVIL_CACHE_DURATION then
                isEvilCache[k] = nil
            end
        end

        -- Check for cached value.
        if isEvilCache[ply] and currentTime - isEvilCache[ply].time <= EVIL_CACHE_DURATION then
            return isEvilCache[ply].value
        end
    end

    -- Compute the evil status if not in cache or expired.
    if not ply then return nil end
    if not ply:IsPlayer() then
        if not skipCache then isEvilCache[ply] = { value = false, time = currentTime } end
        return false
    end

    local isEvil = ply:HasEvilTeam()
    if not skipCache then isEvilCache[ply] = { value = isEvil, time = currentTime } end
    return isEvil
end

--- Uses built-in ply:GetDetective but is nil-safe. Basically if they're a detective.
---@param ply Player
---@return boolean
function TTTBots.Lib.IsPolice(ply)
    if not ply then return nil end
    if not ply:IsPlayer() then return false end
    return ply:GetDetective()
end

function TTTBots.Lib.IsDetective(ply)
    return TTTBots.Lib.IsPolice(ply)
end

--- Opposite of IsEvil, nil-safe. Basically if they're not a traitor.
---@param ply Player
---@return boolean
function TTTBots.Lib.IsGood(ply)
    local out = TTTBots.Lib.IsEvil(ply)
    if out == nil then return end
    return not out
end

--- Check that the nearest point on the nearest navmesh is within 32 units of the given position. Irrespective of Z/height.
--- This is intended to be used with weapons.
---@param pos any
---@return boolean
function TTTBots.Lib.BotCanReachPos(pos)
    local nav = navmesh.GetNearestNavArea(pos)
    if not nav then
        return false
    end
    local nearestPoint = nav:GetClosestPointOnArea(pos)
    return TTTBots.Lib.DistanceXY(nearestPoint, pos) <= 32
end

--- Create a bot, optionally with a name.
---@param name string Optional, defaults to random name
---@return any
function TTTBots.Lib.CreateBot(name)
    if not TTTBots.Lib.CheckIfPlayerSlots() then
        TTTBots.Chat.BroadcastInChat("Somebody tried to add a bot, but there are not enough player slots.")
        return false
    end
    name = name or TTTBots.Lib.GenerateName()
    local bot = player.CreateNextBot(name)

    bot.components = {
        locomotor = TTTBots.Components.Locomotor:New(bot),
        obstacletracker = TTTBots.Components.ObstacleTracker:New(bot),
        inventorymgr = TTTBots.Components.InventoryMgr:New(bot),
        personality = TTTBots.Components.Personality:New(bot),
        memory = TTTBots.Components.Memory:New(bot),
        morality = TTTBots.Components.Morality:New(bot),
        chatter = TTTBots.Components.Chatter:New(bot),
    }

    local dvlpr = TTTBots.Lib.GetDebugFor("misc")
    if dvlpr then
        for i, v in pairs(bot.components) do
            print(string.format("Bot %s component '%s', ID is: %s", bot:Nick(), i, v.componentID))
        end
    end

    return bot
end

--- Trace line from eyes (if fromEyes, else feet) to the given position. Returns the trace result.
--- This is used to cut corners when pathfinding.
---@param player any
---@param fromEyes boolean Optional, defaults to false
---@param finish any Vector
---@return any TraceResult
function TTTBots.Lib.TraceVisibilityLine(player, fromEyes, finish)
    local startPos = player:GetPos()
    if fromEyes then
        startPos = player:EyePos()
    end
    local trace = util.TraceLine({
        start = startPos,
        endpos = finish,
        filter = player,
        mask = MASK_ALL
    })
    return trace
end

--- Get the closest entity from a table of entities to a given position.
---@param entities table
---@param pos any Vector
---@return Entity|nil Entity the entity, else nill
---@return number ClosestDist
function TTTBots.Lib.GetClosest(entities, pos)
    if (#entities == 1) then return entities[1], 0 end
    local closest = nil
    local closestDist = 99999
    for i, v in pairs(entities) do
        if not (IsValid(v) and v:IsPlayer() and TTTBots.Lib.IsPlayerAlive(v)) then continue end
        local dist = v:GetPos():Distance(pos)
        if dist < closestDist then
            closest = v
            closestDist = dist
        end
    end
    return closest, closestDist
end

--- Get the first entity from a table of entities that is closer than a given threshold to a given position.
---@param entities table
---@param pos any Vector
---@param threshold number Distance threshold
---@return Entity|nil Closest closest ent or nil
function TTTBots.Lib.GetFirstCloserThan(entities, pos, threshold)
    for i, v in pairs(entities) do
        local dist = v:GetPos():Distance(pos)
        if dist < threshold then
            return v
        end
    end
    return nil
end

--- Return the closest CNavLadder to pos
---@param pos any Vector
---@return any CNavLadder Closest ladder
---@return number Distance Distance to closest ladder
function TTTBots.Lib.GetClosestLadder(pos)
    local closestLadder = nil
    local closestDist = 99999
    for i = 1, 100 do
        local ladder = navmesh.GetNavLadderByID(i)
        if ladder then
            local dist = ladder:GetCenter():Distance(pos)
            if dist < closestDist then
                closestLadder = ladder
                closestDist = dist
            end
        end
    end
    return closestLadder, closestDist
end

--- Functionally the same as navmesh.GetNavArea(pos), but includes ladder areas.
---@param pos any Vector
---@return CNavArea|CNavLadder nav: CNavArea CNavLadder
function TTTBots.Lib.GetNearestNavArea(pos)
    local closestCNavArea = navmesh.GetNearestNavArea(pos)
    local closestLadder = TTTBots.Lib.GetClosestLadder(pos)

    -- First, check if we are within the boundes of closestCNavArea.
    if closestCNavArea and closestCNavArea:IsOverlapping(pos, 64) then
        return closestCNavArea
    end

    -- Compare closestCNavArea and closestLadder's :GetCenter() to pos
    if closestCNavArea and closestLadder then
        local cnavDist = closestCNavArea:GetCenter():Distance(pos)
        local ladderDist = closestLadder:GetCenter():Distance(pos)
        if cnavDist < ladderDist then
            return closestCNavArea
        else
            return closestLadder
        end
    end

    if not closestCNavArea and closestLadder then
        return closestLadder
    end

    if closestCNavArea and not closestLadder then
        return closestCNavArea
    end

    if #navmesh.GetAllNavAreas() == 0 then
        error("This map is not supported by TTT Bots, it needs a navigational mesh.")
    end
end

--- Deep copy a table and return a new replica.
function TTTBots.Lib.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[TTTBots.Lib.DeepCopy(orig_key)] = TTTBots.Lib.DeepCopy(orig_value)
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local spotCache = {
    cover = {},
    goodsnipe = {},
    bestsnipe = {},
    exposed = {},
}
local spotCacheIDs = {
    cover = 1,
    goodsnipe = 2,
    bestsnipe = 4,
    exposed = 8,
}
--- Caches, or returns the cache if already exists, of the given spotCacheIDs key
---@param key string
---@return table
function TTTBots.Lib.CacheSpotsOfType(key)
    local id = spotCacheIDs[key]
    if #spotCache[key] > 0 then return spotCache[key] end
    local spots = {}
    local navs = navmesh.GetAllNavAreas()
    for i, v in pairs(navs) do
        if not v:IsLadder() then
            local spotsHere = v:GetHidingSpots(id) -- get spots of type 1
            for i2, v2 in pairs(spotsHere) do
                table.insert(spots, v2)
            end
        end
    end
    spotCache[key] = spots
end

function TTTBots.Lib.GetCoverSpots() return TTTBots.Lib.CacheSpotsOfType("cover") or {} end

function TTTBots.Lib.GetGoodSnipeSpots() return TTTBots.Lib.CacheSpotsOfType("goodsnipe") or {} end

function TTTBots.Lib.GetBestSnipeSpots() return TTTBots.Lib.CacheSpotsOfType("bestsnipe") or {} end

function TTTBots.Lib.GetExposedSpots() return TTTBots.Lib.CacheSpotsOfType("exposed") or {} end

--- Call this function at first run on a map (assuming navmesh has loaded) to cache all spots.
function TTTBots.Lib.CacheAllSpots()
    TTTBots.Lib.GetCoverSpots()
    TTTBots.Lib.GetGoodSnipeSpots()
    TTTBots.Lib.GetBestSnipeSpots()
    TTTBots.Lib.GetExposedSpots()
end

-- Wrapper for "ttt_bot_" + name convars
-- Prepends "ttt_bot_" to the name of the convar, and returns the boolean value of the convar.
function TTTBots.Lib.GetConVarBool(name)
    return GetConVar("ttt_bot_" .. name):GetBool()
end

-- Wrapper for "ttt_bot_" + name convars
-- Prepends "ttt_bot_" to the name of the convar, and returns the string value of the convar.
function TTTBots.Lib.GetConVarString(name)
    return GetConVar("ttt_bot_" .. name):GetString()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the integer value of the convar.
function TTTBots.Lib.GetConVarInt(name)
    return GetConVar("ttt_bot_" .. name):GetInt()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the float value of the convar.
function TTTBots.Lib.GetConVarFloat(name)
    return GetConVar("ttt_bot_" .. name):GetFloat()
end

function TTTBots.Lib.WeightedVectorMean(tbl)
    --[[
        tbl example = {
            { vector = Vector(0, 0, 0), weight = 1 },
            { vector = Vector(0, 0, 0), weight = 1 },
            { vector = Vector(0, 0, 0), weight = 1 },
        }
    ]]
    local sum = Vector(0, 0, 0)
    local totalWeight = 0
    for i, v in pairs(tbl) do
        sum = sum + (v.vector * v.weight)
        totalWeight = totalWeight + v.weight
    end
    return sum / totalWeight
end

---@param name string name of the profiler
---@param donotprint boolean if not nil/false, the profiler will not print the time elapsed
---@return function milliseconds Returns a function that returns the time elapsed since the function was called.
function TTTBots.Lib.Profiler(name, donotprint)
    local startTime = SysTime()
    return function()
        local ms = (SysTime() - startTime) * 1000
        if (ms < 0.1) then ms = 0.1 end

        if not donotprint then print(string.format("Profiler '%s' took %s ms.", name, ms)) end
        return ms
    end
end

--- Get a random number between 1 and 100 and return true if it is less than pct.
---@param pct number
function TTTBots.Lib.CalculatePercentChance(pct)
    return (math.random(1, 10000) / 100) <= pct
end

--- Returns a vector that is offset from the ground at either eye-level or crouch-level.
--- If dotrace, then it will trace upward from the ground to determine if this needs crouch-level.
--- If not dotrace, then just +32 to the Z
---@param vec Vector
---@param doTrace boolean
---@return Vector
function TTTBots.Lib.OffsetForGround(vec, doTrace)
    local offset = Vector(0, 0, 32)
    if doTrace then
        local trace = util.TraceLine({
            start = vec,
            endpos = vec + Vector(0, 0, 64),
            mask = MASK_SOLID_BRUSHONLY
        })
        if trace.Hit then
            offset = Vector(0, 0, 16)
        end
    end

    return vec + offset
end

--- TTTBots.Lib.QuadraticBezier(t, p0, p1, p2)
--- Returns a point on a quadratic bezier curve.
---@param t number 0-1
---@param p0 Vector This is the start point
---@param p1 Vector This is the control point
---@param p2 Vector This is the end point
function TTTBots.Lib.QuadraticBezier(t, p0, p1, p2)
    return (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + t ^ 2 * p2
end

--- Run filterFunc callback on each element, and return a table of elements that return true.
---@param tbl table
---@param filterFunc function
---@return table
function TTTBots.Lib.FilterTable(tbl, filterFunc)
    local newTbl = {}
    for i, v in pairs(tbl) do
        if filterFunc(v) then
            table.insert(newTbl, v)
        end
    end
    return newTbl
end

function TTTBots.Lib.NthFilteredItem(N, tbl, filterFunc)
    local newTbl = {}
    for i, v in pairs(tbl) do
        if filterFunc(v) then
            table.insert(newTbl, v)
        end
    end
    if N > #newTbl then
        return nil
    end
    return newTbl[N]
end

TTTBots.Chat = TTTBots.Chat or {}
--- Broadcasts a standard greeting in chat.
---
--- This used to be in the Chat library but due to loading orders it must be here.
function TTTBots.Chat.BroadcastGreeting()
    local broad = TTTBots.Chat.BroadcastInChat
    broad("---------", true)
    broad("Hello! You are playing on a TTT Bots compatible gamemode!", true)
    broad(
        "To add a bot, open the GUI menu using !botmenu, or use the console commands provided in the mod's workshop page.",
        true)
    broad(
        "Bots can also be added with the chat command !addbot X, where X is the number of bots. Type !help for more info.",
        true)
    broad("---------", true)
end

--- Basic wrapper to print a message in every player's chat.
---
--- This used to be in the Chat library but due to loading orders it must be here.
function TTTBots.Chat.BroadcastInChat(message, adminsOnly)
    for _, ply in pairs(player.GetAll()) do
        ply:ChatPrint(message)
    end
end