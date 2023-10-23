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

    -- Debug draw logic
    -- for i = 1, 5 do
    --     if not sorted[i] then break end
    --     -- TTTBots.DebugServer.DrawText(pos, text, lifetime, forceID)
    --     local nav = navmesh.GetNavAreaByID(sorted[i][1])
    --     local pos = nav:GetCenter()
    --     local txt = "(" .. sorted[i][2] .. "s) Popularity Rank #" .. i
    --     TTTBots.DebugServer.DrawText(pos, txt, 1, "popularnavs" .. i)
    -- end
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
