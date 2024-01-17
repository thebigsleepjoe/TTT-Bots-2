--- Basically defines "hangout" areas that people frequent
--- Does NOT apply to CNavLadders
TTTBots.Lib = TTTBots.Lib or {}
TTTBots.Lib.PopularNavs = {}
TTTBots.Lib.PopularNavsSorted = {}

local lib = TTTBots.Lib

timer.Create("TTTBots.Lib.PopularNavsTimer", 1, 0, function()
    -- check if we have a navmesh and we're in a round
    local plys = player.GetAll()
    for i, v in pairs(plys) do
        if not lib.IsPlayerAlive(v) then continue end
        local nav = navmesh.GetNearestNavArea(v:GetPos())
        if not nav then continue end
        local id = nav:GetID()
        TTTBots.Lib.PopularNavs[id] = (TTTBots.Lib.PopularNavs[id] or 0) + 1
    end

    -- sort by popularity
    local sorted = {}
    for k, v in pairs(TTTBots.Lib.PopularNavs) do
        table.insert(sorted, { k, v })
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)

    TTTBots.Lib.PopularNavsSorted = sorted

    if lib.GetConVarBool("debug_navpopularity") then
        -- Debug draw logic
        -- for i = 1, 5 do
        --     if not sorted[i] then break end
        --     -- TTTBots.DebugServer.DrawText(pos, text, lifetime, forceID)
        --     local nav = navmesh.GetNavAreaByID(sorted[i][1])
        --     local pos = nav:GetCenter()
        --     local txt = "(" .. sorted[i][2] .. "s) Popularity Rank #" .. i
        --     TTTBots.DebugServer.DrawText(pos, txt, 1, "popularnavs" .. i)
        -- end
        for i, navTbl in pairs(TTTBots.Lib.GetTopNPopularNavs(3)) do
            local nav = navmesh.GetNavAreaByID(navTbl[1])
            local pos = nav:GetCenter()
            local txt = "(" .. navTbl[2] .. "s) Popularity Rank #" .. i
            TTTBots.DebugServer.DrawText(pos, txt, 1.2, "popularnavs" .. i)
        end

        for i, navTbl in pairs(TTTBots.Lib.GetTopNUnpopularNavs(3)) do
            local nav = navmesh.GetNavAreaByID(navTbl[1])
            local pos = nav:GetCenter()
            local txt = "(" .. navTbl[2] .. "s) Unpopularity Rank #" .. i
            TTTBots.DebugServer.DrawText(pos, txt, 1.2, "unpopularnavs" .. i)
        end
    end
end)

function TTTBots.Lib.GetPopularNavs()
    return TTTBots.Lib.PopularNavsSorted
end

function TTTBots.Lib.GetTopNPopularNavs(n)
    local sorted = TTTBots.Lib.GetPopularNavs()
    local topN = {}
    for i = 1, n do
        if not sorted[i] then break end
        table.insert(topN, sorted[i])
    end
    return topN
end

--- The opposite of GetTopNPopularNavs
function TTTBots.Lib.GetTopNUnpopularNavs(n)
    local sorted = TTTBots.Lib.GetPopularNavs()
    local topN = {}
    for i = #sorted, #sorted - n, -1 do
        if not sorted[i] then break end
        table.insert(topN, sorted[i])
    end
    return topN
end

--- Get a random popular nav area from the top 8 most popular nav areas (or fewer if there are less than 8)
function TTTBots.Lib.GetRandomPopularNav()
    local topN = TTTBots.Lib.GetTopNPopularNavs(8)
    local rand = math.random(1, #topN)
    return topN[rand][1]
end

local navMeta = FindMetaTable("CNavArea")


---Get the popularity percentage [0,1] of this nav area compared to others. 1 = most, 0 = least
---@return unknown
function navMeta:GetPopularityPct()
    local popNavs = TTTBots.Lib.GetPopularNavs()
    local total = #popNavs

    for i, navTbl in pairs(popNavs) do
        if navTbl[1] == self:GetID() then
            return i / total
        end
    end
end
