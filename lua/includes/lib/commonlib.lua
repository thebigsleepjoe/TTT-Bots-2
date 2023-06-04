TTTBots.Lib = TTTBots.Lib or {}

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
function TTTBots.Lib.CheckCompatibleGamemode()
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

-- Some of these comps have separate code that runs independent of the actual component objects,
-- so we need to check if the gamemode is compatible before including them, else they will definitely shit out errors
if TTTBots.Lib.CheckCompatibleGamemode() then
    include("includes/data/usernames.lua")

    -- Import components for bot creation
    TTTBots.Components = {}
    include("includes/components/locomotor.lua")
    include("includes/components/obstacletracker.lua")
    include("includes/components/inventorymgr.lua")
    include("includes/components/personality.lua")
    include("includes/components/memory.lua")
end

local format = string.format

-- Check if not :IsSpec and :Alive, pretty much makes code look neater
function TTTBots.Lib.IsPlayerAlive(bot)
    return IsValid(bot) and not (bot:IsSpec() and bot:Alive())
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
    for _, ply in ipairs(player.GetBots()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
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

--- If we can see the target ply2 from ply1. First tests eye-to-eye sightline, eye-to-feet, then eye-to-center.
---@param ply1 Player
---@param ply2 Player
---@return boolean
function TTTBots.Lib.CanSee(ply1, ply2)
    if not IsValid(ply1) or not IsValid(ply2) then return false end
    local start = ply1:EyePos()

    -- Start at the eyes
    local targetEyes = ply2:EyePos()
    local traceEyes = util.TraceLine({ start = start, endpos = targetEyes, filter = { ply1, ply2 }, mask = MASK_SHOT })
    if traceEyes.Hit then return true end

    -- Then the feet
    local targetFeet = ply2:GetPos()
    local traceFeet = util.TraceLine({ start = start, endpos = targetFeet, filter = { ply1, ply2 }, mask = MASK_SHOT })
    if traceFeet.Hit then return true end

    -- Then the center
    local targetCenter = ply2:GetPos() + Vector(0, 0, 32)
    local traceCenter = util.TraceLine({ start = start, endpos = targetCenter, filter = { ply1, ply2 }, mask = MASK_SHOT })
    if traceCenter.Hit then return true end

    return false
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

--- Uses built-in ply:HasEvilTeam but is nil-safe. Basically if they're a traitor.
---@param ply any
---@return boolean
function TTTBots.Lib.IsEvil(ply)
    if not ply then return nil end
    if not ply:IsPlayer() then return false end
    return ply:HasEvilTeam()
end

--- Opposite of IsEvil, nil-safe. Basically if they're not a traitor.
---@param ply any
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
    local closest = nil
    local closestDist = 99999
    for i, v in pairs(entities) do
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

    error("This map is not supported by TTT Bots, it needs a navigational mesh.")
end

-- Wrapper for "ttt_bot_" + name convars
-- Prepends "ttt_bot_" to the name of the convar, and returns the boolean value of the convar.
function TTTBots.Lib.GetConVarBool(name)
    return GetConVar("ttt_bot_" .. name):GetBool()
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
