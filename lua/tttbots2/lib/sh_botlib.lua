TTTBots.Lib = TTTBots.Lib or {}

if SERVER then
    include("tttbots2/lib/sv_namemanager.lua")
    -- Import components for bot creation
    TTTBots.Components = {}
    include("tttbots2/components/sv_locomotor.lua")
    include("tttbots2/components/sv_obstacletracker.lua")
    include("tttbots2/components/sv_inventory.lua")
    include("tttbots2/components/sv_personality.lua")
    include("tttbots2/components/sv_memory.lua")
    include("tttbots2/components/sv_morality.lua")
    include("tttbots2/components/sv_chatter.lua")
end

TTTBots.Lib.BASIC_VIS_RANGE = 4000 --- Threshold to be considred for the :VisibleVec function in a basic visibility check.

local format = string.format

local alivePlayers = {}
---@realm server
local function updateAlivePlayers()
    alivePlayers = {}
    for i, ply in pairs(player.GetAll()) do
        alivePlayers[ply] = (IsValid(ply) and not (ply:IsSpec()) and ply:Alive() and ply:Health() > 0)
    end
end
if SERVER then timer.Create("TTTBots.Lib.AlivePlayersInterval", 1 / (TTTBots.Tickrate), 0, updateAlivePlayers) end


--- Check if not :IsSpec and :Alive
---@realm shared
function TTTBots.Lib.IsPlayerAlive(ply)
    return alivePlayers[ply]
end

--- returns the cached lib table of all players and whether or not they are living
---@realm server
---@return table<Player, boolean>
function TTTBots.Lib.GetPlayerLifeStates()
    return alivePlayers
end

local EXPLOSIVE_BARREL_MODELS = {
    ["models/props_c17/oildrum001_explosive.mdl"] = true,
    ["models//props_c17/oildrum001_explosive.mdl"] = true,
    ["props_c17/oildrum001_explosive.mdl"] = true
}
---Returns the closest explosive barrel to the target.
---@param target Entity
---@return Entity|nil barrel the barrel, else nil
---@return number distance distance to the barrel
---@realm shared
function TTTBots.Lib.GetClosestBarrel(target)
    local SPHERE_SIZE = 128
    local entities = ents.FindInSphere(target:GetPos(), SPHERE_SIZE)
    local closest, closestDist = TTTBots.Lib.GetClosest(entities, target:GetPos(), function(e)
        if e:GetClass() == "prop_physics" then
            local model = e:GetModel()
            if EXPLOSIVE_BARREL_MODELS[model] then
                return true
            end
        end
        return false
    end)

    return closest, closestDist
end

---Returns a table of living players, according to the IsPlayerAlive cache.
---@return table<Player>
---@realm shared

local aliveCache = {}
local lastUpdateTime = 0

function TTTBots.Lib.GetAlivePlayers()
    local currentTime = CurTime()
    if currentTime - lastUpdateTime >= 1 then
        aliveCache = {}
        for _, ply in ipairs(player.GetAll()) do
            if TTTBots.Lib.IsPlayerAlive(ply) then
                table.insert(aliveCache, ply)
            end
        end
        lastUpdateTime = currentTime
    end
    return aliveCache
end

local isolationCache = {}

-- Function to update the cache
local function UpdateIsolationCache(bot, other)
    if not IsValid(bot) or not IsValid(other) then
        return -math.huge
    end
    local isolation = 0

    local VISIBLE_FACTOR = -0.5    -- Penalty per visible player to other
    local VISIBLE_ME_FACTOR = 0.5  -- Bonus if we can already see other
    local DISTANCE_FACTOR = -0.001 -- Distance penalty per hammer unit to bot

    local witnesses = TTTBots.Lib.GetAllWitnessesBasic(other:EyePos(), TTTBots.Roles.GetNonAllies(bot), bot)
    isolation = isolation + (VISIBLE_FACTOR * table.Count(witnesses))
    isolation = isolation + (DISTANCE_FACTOR * bot:GetPos():Distance(other:GetPos()))
    isolation = isolation + (VISIBLE_ME_FACTOR * (bot:Visible(other) and 1 or 0))
    isolation = isolation + (math.random(-3, 3) / 10) -- Add a bit of randomness to the isolation

    -- Store the calculated isolation in the cache
    isolationCache[bot:UserID() .. "_" .. other:UserID()] = isolation

    return isolation
end
-- Timer to clear the cache every 2 seconds
timer.Create("ClearIsolationCache", 2, 0, function()
    isolationCache = {}
end)
---Give a weight to how isolated 'other' is to us. This is used to determine who to Sidekick.
---A higher isolation means the player is more isolated, and thus a better target for Sidekicking.
---@param bot Bot
---@param other Player
---@return number
---@realm server
function TTTBots.Lib.RateIsolation(bot, other)
    if not (bot and IsValid(bot)) then return -math.huge end
    if not (other and IsValid(other)) then return -math.huge end
    local cacheKey = bot:UserID() .. "_" .. other:UserID()
    if isolationCache[cacheKey] then
        return isolationCache[cacheKey]
    else
        return UpdateIsolationCache(bot, other)
    end
end

---Find the best target to Sidekick, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
---@realm server
function TTTBots.Lib.FindIsolatedTarget(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local bestIsolation = -math.huge
    local bestTarget = nil

    for _, other in ipairs(nonAllies) do
        local isolation = TTTBots.Lib.RateIsolation(bot, other)
        if isolation > bestIsolation then
            bestIsolation = isolation
            bestTarget = other
        end
    end

    return bestTarget, bestIsolation
end

---Returns a table of living bots, according to the IsPlayerAlive cache.
---@return table<Bot>
---@realm shared
function TTTBots.Lib.GetAliveBots()
    local alive = {}
    for _, ply in ipairs(TTTBots.Bots) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            table.insert(alive, ply)
        end
    end
    return alive
end

--- Returns a table of living allies
---@return table<Player>
---@realm shared
function TTTBots.Lib.GetAliveAllies(ply1)
    local alive = {}
    for _, ply2 in ipairs(TTTBots.Bots) do
        if TTTBots.Lib.IsPlayerAlive(ply2) and TTTBots.Roles.IsAllies(ply1, ply2) then
            table.insert(alive, ply2)
        end
    end
    return alive
end

---Looks at the active weapon ply is holding and returns true if it is a traitor-specific weapon. DOES NOT ACCOUNT FOR CUSTOM ROLES.
---@param ply Player
---@return boolean isTraitorWep
---@realm shared
function TTTBots.Lib.IsHoldingTraitorWep(ply)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false end

    local traitorsCanBuy = wep.CanBuy and wep.CanBuy[ROLE_TRAITOR] and true or false
    local canSpawnNaturally = wep.AutoSpawnable and true or false

    return traitorsCanBuy and not canSpawnNaturally
end

--- Generate lowercase alphanumeric string of length 6
---@return string id
---@realm shared
function TTTBots.Lib.GenerateID()
    local id = ""
    for i = 1, 6 do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

---@realm shared
function TTTBots.Lib.PrintInitMessage()
    print("~~~~~~~~~~~~~~~~~~~~~")
    print("TTT Bots initialized!")
    print(format("Version: %s", TTTBots.Version))
    print(format("Number of players: %s/%s", #player.GetAll(), game.MaxPlayers()))
    print(format("Gamemode: %s", engine.ActiveGamemode()))
    print(
        "NOTE: If you are reading this as a dedicated server owner, you cannot use chat commands remotely, your character must be in the server for that. You may still use most concommands.")
    print("~~~~~~~~~~~~~~~~~~~~~")
end

--- Checks if there are currently any player slots available
---@return boolean
---@realm shared
function TTTBots.Lib.HasPlayerSlots()
    return not (#player.GetAll() >= game.MaxPlayers())
end

--- Like CanSee, but the traces include everything that could stop a bullet.
---@param ply1 Player
---@param ply2 Player
---@return boolean
---@realm shared
function TTTBots.Lib.CanShoot(ply1, ply2)
    return ply1:Visible(ply2)
end

local cached_navs_by_size = {}
---@realm shared
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

---@realm server
function TTTBots.Lib.CallEveryNTicks(bot, callback, N)
    local tick = bot.tick or 0
    if tick % N == 0 then
        callback()
    end
end

--- An expensive visibility function that checks if ply1 can see ply2's feet, eyes, or hitbox center
---@param ply1 Player
---@param ply2 Player
---@return boolean canSee
---@realm shared
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

--- Checks if ply can see pos within an arc of X degrees. If so, checks if a VisibleVec returns true.
---@param ply Player
---@param pos Vector
---@param arc number The arc, in degrees, that the player can see. e.g., 90* = 45* in both directions
---@return boolean CanSee
---@realm shared
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

--- Return a table of every given player within range that also have a VisibleVec sightline to the position.
---@param pos Vector The position to check
---@param playerTbl table<Player>|nil (optional) defaults to all living players
---@param ignorePly Player|nil a player to ignore in the check, if any
---@realm shared
function TTTBots.Lib.GetAllWitnessesBasic(pos, playerTbl, ignorePly)
    local RANGE = TTTBots.Lib.BASIC_VIS_RANGE
    local witnesses = {}
    playerTbl = playerTbl or TTTBots.Lib.GetAlivePlayers()
    for i, ply in pairs(playerTbl) do
        if ply == NULL or not IsValid(ply) then continue end
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

---Get a list of players/bots that can see the position. Runs a CanSeeArc check with an FOV of 90*
---@param pos Vector
---@param botsOnly boolean
---@return table
---@realm shared
function TTTBots.Lib.GetAllWitnesses(pos, botsOnly)
    local witnesses = {}
    for _, ply in ipairs(botsOnly and TTTBots.Bots or player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) and IsValid(ply) then
            local sawthat = TTTBots.Lib.CanSeeArc(ply, pos, 90)
            if sawthat then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

TTTBots.Lib.DIFFICULTY_RANGES = {    --- The expected :GetDifficulty() ranges per difficulty setting
    [1] = -7,                        -- Very easy
    [2] = -3,                        -- Easy
    [3] = 0,                         -- Normal
    [4] = 3,                         -- Hard
    [5] = 7                          -- Very hard
}
TTTBots.Lib.DIFFICULTY_TOLERANCE = 4 --- The variability in difficulty that is allowed for a bot to be considered for removal.

net.Receive("TTTBots_SpectateModeChanged", function(len, ply)
    if not IsValid(ply) or ply:IsBot() then return end
    local spectateMode = net.ReadBool()
    ply.forceSpectate = spectateMode
    ply.QueryingSpectateMode = false
end)

--- Function responsible for managing bots to be added and removed by the quota system.
---@realm server
function TTTBots.Lib.UpdateQuota()
    local quotaN = TTTBots.Lib.GetConVarInt("quota")
    if quotaN == 0 then return end
    local quotaMode = TTTBots.Lib.GetConVarString("quota_mode")
    local players = player.GetAll()
    local nPlayers = #players -- All players in the match, including bots, excluding spectators.
    local nBots = #TTTBots.Bots
    local slotsLeft = game.MaxPlayers() - nPlayers
    
    if TTTBots.Lib.GetConVarBool("enable_quota_when_only_spectators") then
        local canPlay = false
        for _, ply in ipairs(players) do
            if not ply:IsBot() then
                if ply.forceSpectate == nil and (ply.QueryingSpectateMode == nil or ply.QueryingSpectateMode == false) then
                    net.Start("TTTBots_QuerySpectateMode")
                    net.Send(ply)
                    ply.QueryingSpectateMode = true -- As to not overload anyones network with queries. Worse network would result in more queries, and worse networks are overloaded faster.
                else
                    if ply.forceSpectate ~= nil and ply.forceSpectate == false then 
                        canPlay = true
                        break
                    end
                end
            end
        end

        if canPlay == false then
            if nBots > 0 then
                RunConsoleCommand("ttt_bot_kickall")
            end
            return
        end
    end

    if quotaMode == "fill" then
        if nPlayers < quotaN then
            if slotsLeft == 0 then return end -- Don't add bots if there are no slots left
            TTTBots.Lib.CreateBot()           -- Add bots one at a time
        elseif nPlayers > quotaN then
            TTTBots.Lib.RemoveBot()           -- Remove bots one at a time
        end
        return
    end

    if quotaMode == "exact" then
        if nBots < quotaN then
            if slotsLeft == 0 then return end -- Don't add bots if there are no slots left
            TTTBots.Lib.CreateBot()
        elseif nBots > quotaN then
            TTTBots.Lib.RemoveBot()
        end
    end

    local shouldCull = TTTBots.Lib.GetConVarBool("quota_cull_difficulty")
    if not shouldCull then return end

    -- Now search for any under- or over-difficulty bots for the current setting.
    local EXPECTED_DIFFICULTY = TTTBots.Lib.DIFFICULTY_RANGES[TTTBots.Lib.GetConVarInt("difficulty")]
    local DIFF_MIN = EXPECTED_DIFFICULTY - TTTBots.Lib.DIFFICULTY_TOLERANCE
    local DIFF_MAX = EXPECTED_DIFFICULTY + TTTBots.Lib.DIFFICULTY_TOLERANCE

    -- Iterate through each bot
    for i, bot in ipairs(TTTBots.Bots) do
        if not (bot and bot ~= NULL and IsValid(bot)) then continue end
        if (TTTBots.Lib.IsPlayerAlive(bot) and TTTBots.Match.IsRoundActive()) then continue end -- Do not kick bots that are alive during a round
        if not (bot.initialized and bot.components and bot.components.personality) then continue end
        local botDifficulty = bot:GetDifficulty()
        if not botDifficulty then continue end                                                  -- Bot hasn't been initialized, give it a moment
        -- If the bot's difficulty is too high or too low compared to the expected difficulty
        if botDifficulty < DIFF_MIN or botDifficulty > DIFF_MAX then
            print("Removing bot of difficulty", botDifficulty, DIFF_MIN, DIFF_MAX)
            bot:Kick()
            break -- Only do one at a time :)
        end
    end
end

if SERVER then
    local QUOTA_INTERVAL = 1 --- The period between adding/removing bots automatically. Used to prevent lag spikes, mostly.
    timer.Create("TTTBots.Lib.UpdateQuota", QUOTA_INTERVAL, 0, TTTBots.Lib.UpdateQuota)
end

--- Grabs the convar ttt_bot_playermodel and sets each bots model to that string. Does not do anything if is blank.
---@realm server
function TTTBots.Lib.UpdateBotModels()
    local model = TTTBots.Lib.GetConVarString("playermodel")
    if model == "" then return end
    for i, bot in pairs(TTTBots.Bots) do
        bot:SetModel(model)
    end
end

---@realm shared
function TTTBots.Lib.GetRandomAdjacent(nav)
    local adjacent = nav:GetAdjacentAreas()
    local random = math.random(1, #adjacent)
    return adjacent[random]
end

---@realm shared
function TTTBots.Lib.GetRandomAdjacentNth(nav, N, i)
    local adjacent = nav:GetAdjacentAreas()
    local random = math.random(1, #adjacent)
    if i == N then return adjacent[random] end
    return TTTBots.Lib.GetRandomAdjacentNth(adjacent[random], N, i + 1)
end

--- A table of { key = element, weight = weight}
---@class WeightedTable
---@field public key any Can be a table, number, string, any value.
---@field public weight number The weight relative to the rest of the table.

--- Creates a WeightedTable object.
---@param element any Can be a table, number, string, any value.
---@param weight number The weight relative to the rest of the table.
---@return WeightedTable
---@realm shared
function TTTBots.Lib.SetWeight(element, weight)
    return { key = element, weight = weight }
end

--- Get all visible nav areas to the given nav, that have a center within maxdist.
---@param nav CNavArea
---@param maxdist number
---@realm shared
function TTTBots.Lib.GetAllVisibleWithinDist(nav, maxdist)
    local allVisible = nav:GetVisibleAreas()
    local filteredDist = TTTBots.Lib.FilterTable(allVisible, function(nav2)
        return nav:GetCenter():Distance(nav2:GetCenter()) <= maxdist
    end)

    return filteredDist
end

--- Performs a basic line trace from start to finish
---@realm shared
function TTTBots.Lib.TraceBasic(start, finish)
    local trace = util.TraceLine({
        start = start,
        endpos = finish,
        mask = MASK_SOLID_BRUSHONLY
    })
    return trace
end

--- Performs a basic trace and returns the percentage (0-100) of the trace that was clear.
---@realm shared
function TTTBots.Lib.TracePercent(start, finish)
    local trace = TTTBots.Lib.TraceBasic(start, finish)
    local dist = start:Distance(finish) or 1
    local percent = (1 - ((dist - trace.Fraction * dist) / dist)) * 100
    return percent
end

local _cachedAngleTable = {}
--- Return a table of calculated angles for a given number of angles.
--- For instance, if n = 4, then the angles will be {0, 90, 180, 270}.
---@realm shared
function TTTBots.Lib.GetAngleTable(n)
    if _cachedAngleTable[n] then return _cachedAngleTable[n] end
    local angles = {}
    local angle = 0
    local angleStep = 360 / n
    for i = 1, n do
        table.insert(angles, angle)
        angle = angle + angleStep
    end
    _cachedAngleTable[n] = angles
    return angles
end

local _cachedRegions = {
    hasCached = false,  -- Has the table been cached yet?
    regions = {},       -- Table of regions containing navs
    alreadyCached = {}, -- Table of navs that have been claimed by a region
}

--- Recursively add adjacent nav areas to a region table. Avoids affecting already cached navs.
---@realm server
function TTTBots.Lib.AddAdjacentsToRegion(nav, regionTbl, alreadyCached)
    -- Initialize tables if not provided.
    regionTbl = regionTbl or {}
    alreadyCached = alreadyCached or {}

    -- Stack for nav areas to process
    local stack = { nav }

    while #stack > 0 do
        local currentNav = table.remove(stack)

        -- Process the current nav area if not already cached
        if not alreadyCached[currentNav] then
            alreadyCached[currentNav] = currentNav
            regionTbl[currentNav] = currentNav

            -- Add adjacent nav areas to the stack
            for _, adj in pairs(currentNav:GetAdjacentAreas()) do
                if not alreadyCached[adj] then
                    table.insert(stack, adj)
                end
            end
        end
    end
end

--- Create a Get and Set function for member varname
---@param varname string The name of the variable. Recommended PascalCase
---@param default any The default value of the variable.
---@return function GetFunc Called with (self)
---@return function SetFunc Called with (self, value)
function TTTBots.Lib.GetSet(varname, default)
    local setFunc = function(self, value)
        self["m_" .. varname] = value
    end
    local getFunc = function(self)
        if self["m_" .. varname] == nil then
            self["m_" .. varname] = default
        end
        return self["m_" .. varname]
    end

    return getFunc, setFunc
end

function TTTBots.Lib.IncludeDirectory(path)
    path = path .. "/"

    local files, directories = file.Find(path .. "*", "LUA")
    local loadedLuaList = {}

    for _, v in ipairs(files) do
        if string.EndsWith(v, ".lua") then
            local inclusion = include(path .. v)
            if inclusion then -- If the added script returns true, then add it to the list
                table.insert(loadedLuaList, v)
            end
        end
    end

    return loadedLuaList
end

function TTTBots.Lib.StringifyTable(tbl)
    local result = {}
    local isArray = true
    local index = 1

    for key, value in pairs(tbl) do
        if isArray and (key ~= index or type(key) ~= "number") then
            isArray = false
        end

        if isArray then
            table.insert(result, tostring(value))
            index = index + 1
        else
            local keyStr = type(key) == "string" and ("[" .. string.format("%q", key) .. "]") or
                ("[" .. tostring(key) .. "]")
            table.insert(result, keyStr .. " = " .. tostring(value))
        end
    end

    return "{ " .. table.concat(result, ", ") .. " }"
end

---@realm server
function TTTBots.Lib.GetNavRegions(forceRecache)
    if not forceRecache and _cachedRegions.hasCached then
        return _cachedRegions.regions
    end

    -- Re-initialize the _cachedRegions to clear old data if forceRecache is true.
    _cachedRegions.regions = {}
    _cachedRegions.alreadyCached = {}
    _cachedRegions.hasCached = false

    print("[TTT Bots 2] Caching nav regions...")
    local allNavsCached = {}

    local navs = navmesh.GetAllNavAreas()
    for _, nav in pairs(navs) do
        if not allNavsCached[nav] then
            local region = {}
            TTTBots.Lib.AddAdjacentsToRegion(nav, region, allNavsCached)
            if next(region) then -- Ensure the region is not empty
                table.insert(_cachedRegions.regions, region)
            end
        end
    end

    _cachedRegions.hasCached = true
    print("[TTT Bots 2] Cached nav regions; there are " .. #_cachedRegions.regions .. " regions.")
    return _cachedRegions.regions
end

--- Return the closest region table to position "pos"
---@realm server
function TTTBots.Lib.GetNearestRegion(pos)
    local regions = TTTBots.Lib.GetNavRegions()
    local closestNav = navmesh.GetNearestNavArea(pos)
    if not closestNav then return end
    for _, region in pairs(regions) do
        if region[closestNav] then return region end
    end
end

---@realm server
function TTTBots.Lib.GetRandomNavInRegion(region)
    return table.Random(region)
end

---@realm server
function TTTBots.Lib.GetRandomNavInNearestRegion(pos)
    local region = TTTBots.Lib.GetNearestRegion(pos)
    if not region then return end
    return TTTBots.Lib.GetRandomNavInRegion(region)
end

--- Returns a weighted random result from the table.
--- This function accepts an array of WeightedTable objects, calculates the total weight,
--- selects a random number in the range of total weight, then iterates through the array
--- adding the weight of each item to a counter until it exceeds or equals to the random number.
--- At that point, it returns the key of the current item.
---@param options table<WeightedTable> An array of WeightedTable options.
---@return any The key of the randomly selected WeightedTable item.
---@realm shared
function TTTBots.Lib.RandomWeighted(options)
    assert(#options > 0, "Table is empty")

    local totalWeight = 0
    for i = 1, #options do
        totalWeight = totalWeight + options[i].weight
    end

    local random = math.random(0, totalWeight)
    local currentWeight = 0
    for i = 1, #options do
        currentWeight = currentWeight + options[i].weight
        if random <= currentWeight then
            return options[i].key
        end
    end
end

--- Similar to GetAllWitnesses, but internally uses CanSee instead of CanSeeArc (so 360*)
---@realm shared
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
---@param nonTeammatesOnly? boolean
---@param caller? Player The player to use for teammate comparison
---@return table<Player> witnesses A table of players that can see the position.
---@realm shared
function TTTBots.Lib.GetAllVisible(pos, nonTeammatesOnly, caller)
    if (type(pos) ~= "Vector") then
        ErrorNoHaltWithStack("Invalid vec type to GetAllVisible: " .. type(pos))
        return {}
    end
    local witnesses = {}
    for _, ply in ipairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) and (nonTeammatesOnly and caller and not TTTBots.Roles.IsAllies(caller, ply)) then
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
---@realm shared
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
---@realm shared
function TTTBots.Lib.GetFreePlayerSlots()
    return game.MaxPlayers() - #player.GetAll()
end

--- Equivalent of GetConVar("ttt_bot_debug_(debugType)"):GetBool()
---@param debugType string
---@return boolean
---@realm server
function TTTBots.Lib.GetDebugFor(debugType)
    return GetConVar("ttt_bot_debug_" .. debugType):GetBool()
end

--- XY Distance between two Vectors
---@param pos1 any
---@param pos2 any
---@return number
---@realm shared
function TTTBots.Lib.DistanceXY(pos1, pos2)
    return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

---@realm shared
function TTTBots.Lib.IsTTT2()
    return TTT2
end

---@realm shared
function TTTBots.Lib.IsDoor(ent)
    local class = ent:GetClass()
    local validClasses = {
        ["func_door"] = true,
        ["func_door_rotating"] = true,
        ["prop_door_rotating"] = true
    }
    return validClasses[class] or false
end

---@realm shared
function TTTBots.Lib.IsValidBody(rag)
    return IsValid(rag) and CORPSE.GetPlayerNick(rag, false) ~= false
end

--- Return a random open angle in a circle around the given position, or nil if there are none.
---@param origin Vector
---@param range number
---@return Vector|nil
---@realm shared
function TTTBots.Lib.GetRandomOpenNormal(origin, range)
    local angles = TTTBots.Lib.GetAngleTable(16)
    local options = {}

    for i, angle in pairs(angles) do
        local x = math.cos(math.rad(angle)) * range
        local y = math.sin(math.rad(angle)) * range
        local trace = TTTBots.Lib.TracePercent(origin, origin + Vector(x, y, 0))

        if trace > 50 then
            table.insert(options, Vector(x, y, 0))
        end
    end

    return table.Random(options)
end

--- Check that the nearest point on the nearest navmesh is within 32 units of the given position. Irrespective of Z/height.
--- This is intended to be used with weapons.
---@param pos any
---@return boolean
---@realm shared
function TTTBots.Lib.BotCanReachPos(pos)
    local nav = navmesh.GetNearestNavArea(pos)
    if not nav then
        return false
    end
    local nearestPoint = nav:GetClosestPointOnArea(pos)
    return TTTBots.Lib.DistanceXY(nearestPoint, pos) <= 32
end

local notifiedSlots = false
local notifiedNavmesh = false

local function createPlayerBot(botname)
    local bot = player.CreateNextBot(botname)

    bot.components = {
        locomotor = TTTBots.Components.Locomotor:New(bot),
        obstacletracker = TTTBots.Components.ObstacleTracker:New(bot),
        inventory = TTTBots.Components.Inventory:New(bot),
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

    bot.initialized = true

    hook.Run("TTTBotJoined", bot)

    return bot
end

---Test if there is a navmesh and notify the server if not on first call.
---@return boolean
function TTTBots.Lib.TestNavmesh()
    if table.IsEmpty(navmesh.GetAllNavAreas()) then
        if not notifiedNavmesh then
            local msg = TTTBots.Locale.GetLocalizedString("no.navmesh")
            TTTBots.Chat.BroadcastInChat(msg)
            print(msg)
            notifiedNavmesh = true
        end
        return false
    end

    return true
end

---Test if there are player slots and notify the server if not on first call.
---@return boolean
function TTTBots.Lib.TestPlayerSlots()
    if not TTTBots.Lib.HasPlayerSlots() then
        if not notifiedSlots then
            local msg = TTTBots.Locale.GetLocalizedString("not.enough.slots")
            TTTBots.Chat.BroadcastInChat(msg)
            print(msg)
            notifiedSlots = true
        end
        return false
    end

    return true
end

--- Test if there are any players in the server to prevent issue #34
---@return boolean
function TTTBots.Lib.TestServerActive()
    local numHumans = table.Count(player.GetHumans())

    return numHumans > 0
end

--- Create a bot, optionally with a name.
---@param name? string Optional, defaults to random name
---@return Player? bot The bot, or false if there are no player slots
---@realm server
function TTTBots.Lib.CreateBot(name)
    -- Test if the server can support bots.
    if not TTTBots.Lib.TestPlayerSlots() then return end
    if not TTTBots.Lib.TestNavmesh() then return end
    if not TTTBots.Lib.TestServerActive() then return end

    -- Start initializing the bot
    name = name or TTTBots.Lib.GenerateName()
    local failFunc = function()
        print(TTTBots.Locale.GetLocalizedString("fail.create.bot"))
        print("Below is the error:")
        print(debug.traceback())
    end
    local success, bot = xpcall(function() return createPlayerBot(name) end, failFunc, name)

    return bot or nil
end

---Gets a table of revivable corpses (i.e., those that were not headshot).
---@return table
function TTTBots.Lib.GetRevivableCorpses()
    local bodies = TTTBots.Match.Corpses
    local wasHeadshot = CORPSE.WasHeadshot

    local revivable = {}
    for i, corpse in pairs(bodies) do
        if not TTTBots.Lib.IsValidBody(corpse) then continue end
        if wasHeadshot(corpse) then continue end

        table.insert(revivable, corpse)
    end

    return revivable
end

---Get the first closest revivable corpse to the given bot. If filterAlly d: true) then it will only return corpses of the same team. Else nil.
---@param bot Bot
---@param filterAlly? boolean
---@return Player? player
---@return any? ragdoll
function TTTBots.Lib.GetClosestRevivable(bot, filterAlly)
    local options = TTTBots.Lib.GetRevivableCorpses()
    local cTime = CurTime()

    filterAlly = filterAlly or true -- Default filterAlly? to true

    for i, rag in pairs(options) do
        if not TTTBots.Lib.IsValidBody(rag) then continue end
        local deadply = player.GetBySteamID64(rag.sid64)
        if not IsValid(deadply) then continue end
        if filterAlly and not TTTBots.Roles.IsAllies(bot, deadply) then continue end
        if (deadply.reviveCooldown or 0) > cTime then continue end
        return deadply, rag
    end

    return nil -- No corpses found
end

if SERVER then
    hook.Add("PlayerInitialSpawn", "TTTBots.Lib.PlayerInitialSpawn.Chatter", function(bot)
        timer.Simple(math.pi, function()
            if not (bot and IsValid(bot) and bot:IsBot()) then return end
            local chatter = bot:BotChatter()
            if not chatter then return end
            chatter:On("ServerConnected", { player = bot:Nick() })
        end)
    end)
end

--- Removes the first bot in the match that is dead (or if we are outside of a match). Will avoid kicking living bots during a match.
---@param reason? string Optional, defaults to "Removed by server"
---@realm server
function TTTBots.Lib.RemoveBot(reason)
    local bots = TTTBots.Bots
    if #bots == 0 then return end

    for i, bot in pairs(bots) do
        if not IsValid(bot) then continue end
        if not TTTBots.Lib.IsPlayerAlive(bot) or not TTTBots.Match.IsRoundActive() then
            bot:Kick(reason or "Removed by server")
            return true
        end
    end

    return false
end

--- Trace line from eyes (if fromEyes, else feet) to the given position. Returns the trace result.
--- This is used to cut corners when pathfinding.
---@param player Player
---@param fromEyes boolean Optional, defaults to false
---@param finish Vector Vector
---@return any TraceResult
---@realm shared
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
---@param extraCallback function|nil Optional, a function that takes an entity and returns true/false
---@return Entity|Player|nil Entity the entity, else nill
---@return number ClosestDist
---@realm shared
function TTTBots.Lib.GetClosest(entities, pos, extraCallback)
    if (#entities == 1) then return entities[1], 0 end
    local closest = nil
    local closestDist = 99999
    for i, v in pairs(entities) do
        if extraCallback then if not extraCallback(v) then continue end end
        local vIsPlayer = IsValid(v) and v:IsPlayer()
        if vIsPlayer and not TTTBots.Lib.IsPlayerAlive(v) then continue end
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
---@realm shared
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
---@realm server
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

---@realm server
function TTTBots.Lib.VoluntaryDisconnect(bot, reason)
    if bot.disconnecting then return true end -- already disconnecting
    bot.disconnecting = true
    local chatter = bot and bot.components and bot.components.chatter
    if not chatter then return true end

    chatter:On("Disconnect" .. reason, { bot = bot, name = bot:Nick() })
    timer.Simple(math.random(1, 3), function()
        if not bot then return end
        if not IsValid(bot) then return end
        bot:Kick(string.format(
            "Disconnect by user",
            reason or "UNDEFINED"))
    end)

    -- The auto rejoin should only happen if there isn't a quota. If there is, then this will cause issues.
    local quota = TTTBots.Lib.GetConVarInt("quota")
    if quota <= 0 then
        -- schedule another bot to re-join
        timer.Simple(math.random(3, 14), function()
            TTTBots.Lib.CreateBot()
        end)
    end
end

--- return the component 'type' of the bot, or nil if doesn't have one
---@deprecated
---@param bot Bot
---@param type string
---@return Component Component
---@realm server
function TTTBots.Lib.GetComp(bot, type)
    return bot.components[type]
end

function TTTBots.Lib.WepClassExists(classname)
    return weapons.Get(classname) ~= nil
end

--- Functionally the same as navmesh.GetNavArea(pos), but includes ladder areas. Might return nil if there is no navmesh.
---@param pos any Vector
---@return CNavArea|CNavLadder|nil nav: CNavArea CNavLadder
---@realm server
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

    return nil
end

--- Deep copy a table and return a new replica.
---@realm shared
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

---@realm shared
function TTTBots.Lib.HUToMeters(hammer_units)
    local conversionMult = 0.01905
    return hammer_units * conversionMult
end

---@realm shared
function TTTBots.Lib.MetersToHU(meters)
    local conversionDiv = 0.01905
    return meters / conversionDiv
end

-- Wrapper for "ttt_bot_" + name convars
-- Prepends "ttt_bot_" to the name of the convar, and returns the boolean value of the convar.
---@realm shared
function TTTBots.Lib.GetConVarBool(name)
    local cvar = GetConVar("ttt_bot_" .. name)
    if not cvar then print(name) end
    return cvar:GetBool()
end

-- Wrapper for "ttt_bot_" + name convars
-- Prepends "ttt_bot_" to the name of the convar, and returns the string value of the convar.
---@realm shared
function TTTBots.Lib.GetConVarString(name)
    return GetConVar("ttt_bot_" .. name):GetString()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the integer value of the convar.
---@realm shared
function TTTBots.Lib.GetConVarInt(name)
    return GetConVar("ttt_bot_" .. name):GetInt()
end

--- Wrapper for "ttt_bot_" + name convars
--- Prepends "ttt_bot_" to the name of the convar, and returns the float value of the convar.
---@realm shared
function TTTBots.Lib.GetConVarFloat(name)
    return GetConVar("ttt_bot_" .. name):GetFloat()
end

---@realm shared
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
---@realm shared
function TTTBots.Lib.Profiler(name, donotprint)
    local startTime = SysTime()
    return function()
        local ms = (SysTime() - startTime) * 1000
        if (ms < 0.1) then ms = 0.1 end

        if not donotprint then print(string.format("Profiler '%s' took %s ms.", name, ms)) end
        return ms
    end
end

function TTTBots.Lib.GetHeadPos(other)
    local boneIndex = other:LookupBone("ValveBiped.Bip01_Head1")
    if not boneIndex then return other:EyePos() end

    return other:GetBonePosition(boneIndex)
end

--- Get a random number between 1 and 100 and return true if it is less than pct. Supports decimals above 0.01.
---@param pct number
---@realm shared
function TTTBots.Lib.TestPercent(pct)
    return (math.random(1, 100000) / 1000) <= pct
end

--- Returns a vector that is offset from the ground at either eye-level or crouch-level.
--- If dotrace, then it will trace upward from the ground to determine if this needs crouch-level.
--- If not dotrace, then just +32 to the Z
---@param vec Vector
---@param doTrace boolean
---@return Vector
---@realm shared
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
---@realm shared
function TTTBots.Lib.QuadraticBezier(t, p0, p1, p2)
    return (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + t ^ 2 * p2
end

--- Run filterFunc callback on each element, and return a table of elements that return true.
---@param tbl table
---@param filterFunc function
---@return table
---@realm shared
function TTTBots.Lib.FilterTable(tbl, filterFunc)
    local newTbl = {}
    for i, v in pairs(tbl) do
        if filterFunc(v) then
            table.insert(newTbl, v)
        end
    end
    return newTbl
end

---Retrieves the Nth item from a table after applying a filter function.
---@param N (number): The index of the item to retrieve.
---@param tbl (table): The table to filter and retrieve the item from.
---@param filterFunc (function): The filter function to apply on each item in the table.
---@return (any): The Nth filtered item from the table, or nil if it doesn't exist.
---@realm shared
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

--- Return a list of nav areas visible to vec's nearest nav area, filtered by range.
---@param vec Vector The position to check
---@param range number The range to check
---@return table<CNavArea> visible A table of nav areas that are visible to vec's nearest nav area.
---@realm server
function TTTBots.Lib.VisibleNavsInRange(vec, range)
    local nav = navmesh.GetNearestNavArea(vec)
    if not nav then return {} end
    local visible = nav:GetVisibleAreas()

    local filtered = TTTBots.Lib.FilterTable(visible, function(nav2)
        return nav:GetCenter():Distance(nav2:GetCenter()) <= range
    end)

    return filtered
end

TTTBots.Chat = TTTBots.Chat or {}

--- Basic wrapper to print a message in every player's chat.
---
--- This used to be in the Chat library but due to loading orders it must be here.
---@realm server
function TTTBots.Chat.BroadcastInChat(message, adminsOnly)
    for _, ply in pairs(player.GetAll()) do
        ply:ChatPrint(message)
    end
end
