--- Defines "hangout" areas that people frequent.
--- Does NOT apply to CNavLadders.
TTTBots.Lib = TTTBots.Lib or {}
TTTBots.Lib.PopularNavs = {}
TTTBots.Lib.PopularNavsSorted = {}

local lib = TTTBots.Lib

-- Lookup table: navID -> rank index (built alongside the sorted list)
local _popularityRankLookup = {}
local _sortCounter = 0
local SORT_INTERVAL = 5 -- Only re-sort every N seconds instead of every second

--- Creates a timer that updates the popularity of nav areas every second.
timer.Create("TTTBots.Lib.PopularNavsTimer", 1, 0, function()
    -- Update visit counts for alive players
    for ply, isAlive in pairs(lib.GetPlayerLifeStates()) do
        if not isAlive then continue end
        if not IsValid(ply) then continue end
        local nav = navmesh.GetNearestNavArea(ply:GetPos())
        if not nav then continue end
        local id = nav:GetID()
        TTTBots.Lib.PopularNavs[id] = (TTTBots.Lib.PopularNavs[id] or 0) + 1
    end

    -- Only re-sort every SORT_INTERVAL seconds to reduce CPU usage
    _sortCounter = _sortCounter + 1
    if _sortCounter >= SORT_INTERVAL then
        _sortCounter = 0

        local sorted = {}
        for k, v in pairs(TTTBots.Lib.PopularNavs) do
            sorted[#sorted + 1] = { k, v }
        end
        table.sort(sorted, function(a, b) return a[2] > b[2] end)

        TTTBots.Lib.PopularNavsSorted = sorted

        -- Build rank lookup for O(1) GetPopularityPct
        _popularityRankLookup = {}
        for i, navTbl in ipairs(sorted) do
            _popularityRankLookup[navTbl[1]] = i
        end
    end

    if lib.GetConVarBool("debug_navpopularity") then
        -- Debug draw logic.
        for i, navTbl in ipairs(TTTBots.Lib.GetTopNPopularNavs(3)) do
            local nav = navmesh.GetNavAreaByID(navTbl[1])
            local pos = nav:GetCenter()
            local txt = string.format("(%ds) Popularity Rank #%d", navTbl[2], i)
            TTTBots.DebugServer.DrawText(pos, txt, 1.2, "popularnavs" .. i)
        end

        for i, navTbl in ipairs(TTTBots.Lib.GetTopNUnpopularNavs(3)) do
            local nav = navmesh.GetNavAreaByID(navTbl[1])
            local pos = nav:GetCenter()
            local txt = string.format("(%ds) Unpopularity Rank #%d", navTbl[2], i)
            TTTBots.DebugServer.DrawText(pos, txt, 1.2, "unpopularnavs" .. i)
        end
    end
end)

-- Reset popularity data between rounds
hook.Add("TTTBeginRound", "TTTBots.PopularNavs.Reset", function()
    TTTBots.Lib.PopularNavs = {}
    TTTBots.Lib.PopularNavsSorted = {}
    _popularityRankLookup = {}
    _sortCounter = 0
end)

--- Retrieves the sorted list of popular nav areas.
---@return table sorted A sorted table of nav areas by popularity.
function TTTBots.Lib.GetPopularNavs()
    return TTTBots.Lib.PopularNavsSorted
end

--- Retrieves the top N popular nav areas.
---@param n number The number of top popular nav areas to retrieve.
---@return table<table<number, number>> popular A table of the top N popular nav areas.
function TTTBots.Lib.GetTopNPopularNavs(n)
    local sorted = TTTBots.Lib.GetPopularNavs()
    local topN = {}
    for i = 1, math.min(n, #sorted) do
        topN[#topN + 1] = sorted[i]
    end
    return topN
end

--- Retrieves the top N unpopular nav areas.
--- The opposite of GetTopNPopularNavs.
---@param n number The number of top unpopular nav areas to retrieve.
---@return table<table<number, number>> unpopular A table of the top N unpopular nav areas.
function TTTBots.Lib.GetTopNUnpopularNavs(n)
    local sorted = TTTBots.Lib.GetPopularNavs()
    local topN = {}
    for i = #sorted, math.max(#sorted - n + 1, 1), -1 do
        if not sorted[i] then break end
        topN[#topN + 1] = sorted[i]
    end
    return topN
end

--- Retrieves a random popular nav area from the top 8 most popular nav areas (or fewer if there are less than 8).
---@return number id The ID of a random popular nav area.
function TTTBots.Lib.GetRandomPopularNav()
    local topN = TTTBots.Lib.GetTopNPopularNavs(8)
    local rand = math.random(1, #topN)
    return topN[rand][1]
end

local navMeta = FindMetaTable("CNavArea")

--- Gets the popularity percentage [0,1] of this nav area compared to others. 1 = most, 0 = least.
---@return number popularity The popularity percentage of this nav area.
function navMeta:GetPopularityPct()
    local sorted = TTTBots.Lib.PopularNavsSorted
    local total = #sorted
    if total == 0 then return 0.0 end

    local rank = _popularityRankLookup[self:GetID()]
    if not rank then return 0.0 end

    -- Rank 1 = most popular = highest percentage
    return 1 - ((rank - 1) / total)
end
