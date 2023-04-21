TTTBots.Lib = {}

include("includes/data/usernames.lua")

-- Import components for bot creation
include("includes/components/locomotor.lua")
include("includes/components/obstacletracker.lua")
include("includes/components/inventorymgr.lua")
include("includes/components/personality.lua")

local Lib = TTTBots.Lib
local format = string.format

-- Check if not :IsSpec and :Alive, pretty much makes code look neater
function Lib.IsPlayerAlive(bot)
    return IsValid(bot) and not (bot:IsSpec() and bot:Alive())
end

-- Generate lowercase alphanumeric string of length 6
function Lib.GenerateID()
    local id = ""
    for i = 1, 6 do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

function Lib.PrintInitMessage()
    print("~~~~~~~~~~~~~~~~~~~~~")
    print("TTT Bots initialized!")
    print(format("Version: %s", TTTBots.Version))
    print(format("Number of players: %s/%s", #player.GetAll(), game.MaxPlayers()))
    print(format("Gamemode: %s", engine.ActiveGamemode()) ..
        " | (Compatible = " .. tostring(Lib.CheckCompatibleGamemode()) .. ")")
    print(
        "NOTE: If you are reading this as a dedicated server owner, you cannot use chat commands remotely, your character must be in the server for that. You may still use concommands.")
    print("~~~~~~~~~~~~~~~~~~~~~")
end

function Lib.CheckIfPlayerSlots()
    return not (#player.GetAll() >= game.MaxPlayers())
end

function Lib.CheckCompatibleGamemode()
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

function Lib.GetDebugFor(debugType)
    return GetConVar("ttt_bot_debug_" .. debugType):GetBool()
end

function Lib.DistanceXY(pos1, pos2)
    return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

--- Check that the nearest point on the nearest navmesh is within 32 units of the given position. Irrespective of Z/height.
--- This is intended to be used with weapons.
function Lib.BotCanReachPos(pos)
    local nav = navmesh.GetNearestNavArea(pos)
    if not nav then
        return false
    end
    local nearestPoint = nav:GetNearestPoint(pos)
    return Lib.DistanceXY(nearestPoint, pos) <= 32
end

function Lib.CreateBot(name)
    if not Lib.CheckIfPlayerSlots() then
        TTTBots.Chat.BroadcastInChat("Somebody tried to add a bot, but there are not enough player slots.")
        return false
    end
    name = name or Lib.GenerateName()
    local bot = player.CreateNextBot(name)

    bot.components = {
        locomotor = TTTBots.Components.Locomotor:New(bot),
        obstacletracker = TTTBots.Components.ObstacleTracker:New(bot),
        inventorymgr = TTTBots.Components.InventoryMgr:New(bot),
        personality = TTTBots.Components.Personality:New(bot),
    }

    local dvlpr = Lib.GetDebugFor("misc")
    if dvlpr then
        for i, v in pairs(bot.components) do
            print(string.format("Bot %s component '%s', ID is: %s", bot:Nick(), i, v.componentID))
        end
    end

    return bot
end

-- Trace line from eyes (if fromEyes, else feet) to the given position. Returns the trace result.
-- This is used to cut corners when pathfinding.
function Lib.TraceVisibilityLine(player, fromEyes, finish)
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

function Lib.GetClosest(entities, pos)
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

function Lib.GetFirstCloserThan(entities, pos, threshold)
    for i, v in pairs(entities) do
        local dist = v:GetPos():Distance(pos)
        if dist < threshold then
            return v
        end
    end
    return nil
end

function Lib.GetClosestLadder(pos)
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

-- Functionally the same as navmesh.GetNavArea(pos), but includes ladder areas.
function Lib.GetNearestNavArea(pos)
    local closestCNavArea = navmesh.GetNearestNavArea(pos)
    local closestLadder = Lib.GetClosestLadder(pos)

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
function Lib.GetConVarBool(name)
    return GetConVar("ttt_bot_" .. name):GetBool()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the integer value of the convar.
function Lib.GetConVarInt(name)
    return GetConVar("ttt_bot_" .. name):GetInt()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the float value of the convar.
function Lib.GetConVarFloat(name)
    return GetConVar("ttt_bot_" .. name):GetFloat()
end

function Lib.WeightedVectorMean(tbl)
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
function Lib.Profiler(name, donotprint)
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
function Lib.OffsetForGround(vec, doTrace)
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

--- Lib.QuadraticBezier(t, p0, p1, p2)
--- Returns a point on a quadratic bezier curve.
---@param t number 0-1
---@param p0 Vector This is the start point
---@param p1 Vector This is the control point
---@param p2 Vector This is the end point
function Lib.QuadraticBezier(t, p0, p1, p2)
    return (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + t ^ 2 * p2
end

function Lib.FilterTable(tbl, filterFunc)
    local newTbl = {}
    for i, v in pairs(tbl) do
        if filterFunc(v) then
            table.insert(newTbl, v)
        end
    end
    return newTbl
end

function Lib.NthFilteredItem(N, tbl, filterFunc)
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
