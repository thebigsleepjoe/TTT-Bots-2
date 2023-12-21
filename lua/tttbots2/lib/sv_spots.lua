TTTBots.Spots = {}

--- Go to through all of the spots on the navmesh and categorize them ourselves.
---@return table<Vector>
function TTTBots.Spots.CacheAllSpots()
    TTTBots.Spots.CachedSpots = {
        ["all"] = {},
    }
    local allNavs = navmesh.GetAllNavAreas()
    for i, v in pairs(allNavs) do
        local exposedSpots = v:GetExposedSpots()
        local hidingSpots = v:GetHidingSpots()
        for i, v in pairs(exposedSpots) do
            table.insert(TTTBots.Spots.CachedSpots["all"], v)
        end
        for i, v in pairs(hidingSpots) do
            table.insert(TTTBots.Spots.CachedSpots["all"], v)
        end
    end
    TTTBots.Spots.CacheSpecialSpots()

    return TTTBots.Spots.CachedSpots["all"]
end

function TTTBots.Spots.GetAllSpots()
    return TTTBots.Spots.CachedSpots["all"]
end

--- Return the nearest spot of a given category to pos. Also returns the distance to that spot.
---@param pos Vector
---@param category string
---@return Vector|nil, number
function TTTBots.Spots.GetNearestSpotOfCategory(pos, category)
    local spots = TTTBots.Spots.GetSpotsInCategory(category)
    local nearestSpot = nil
    local nearestDist = math.huge
    for i, spot in pairs(spots) do
        local dist = spot:Distance(pos)
        if dist < nearestDist then
            nearestDist = dist
            nearestSpot = spot
        end
    end
    return nearestSpot, nearestDist
end

function TTTBots.Spots.RegisterSpotCategory(title, spotValidCallback)
    TTTBots.Spots.CachedSpots[title] = {}
    TTTBots.Spots.CachedSpots[title].IsValid = spotValidCallback
    TTTBots.Spots.CachedSpots[title].Spots = {}

    local spotsToFilter = TTTBots.Spots.GetAllSpots()
    for i, spot in pairs(spotsToFilter) do
        if spotValidCallback(spot) then
            table.insert(TTTBots.Spots.CachedSpots[title].Spots, spot)
        end
    end

    print(string.format("[TTT Bots 2] Registered spot category '%s' with %d spots.", title,
        #TTTBots.Spots.CachedSpots[title].Spots))
end

function TTTBots.Spots.GetSpotsInCategory(title)
    return TTTBots.Spots.CachedSpots[title].Spots
end

--- Measure the visibility around the spot by tracing some lines in a circle around it, and return the average percentage of visibility.
function TTTBots.Spots.MeasureSpotVisibility(vec, radius)
    local total = 0
    local count = 0
    local offset = Vector(0, 0, 32)
    local angles = TTTBots.Lib.GetAngleTable(16)
    for i, angle in pairs(angles) do
        local x = math.cos(math.rad(angle)) * radius
        local y = math.sin(math.rad(angle)) * radius
        local trace = TTTBots.Lib.TracePercent(vec + offset, vec + Vector(x, y, 0) + offset)
        total = total + trace
        count = count + 1
    end
    return total / count
end

function TTTBots.Spots.CacheSpecialSpots()
    local SNIPER_MIN_TO_BE_CONSIDERED = 5
    local SniperExclusionaryFunc = function(spot)
        local visibleNavs = 0
        local myNav = navmesh.GetNearestNavArea(spot)
        if not myNav then return false end
        local navsICanSee = myNav:GetVisibleAreas()
        for i, nav in pairs(navsICanSee) do
            if not nav:IsPartiallyVisible(spot) then -- If we can see them, but they can't see us (this is for exclusionary)
                visibleNavs = visibleNavs + 1
            end
        end
        return visibleNavs >= SNIPER_MIN_TO_BE_CONSIDERED
    end

    local HIDING_MAX_VIS_PCT = 41
    local HidingFunc = function(spot)
        local visibAvg = TTTBots.Spots.MeasureSpotVisibility(spot, 256)

        return visibAvg <= HIDING_MAX_VIS_PCT
    end

    local SNIPER_MIN_VIS_PCT = 60
    local SniperFunc = function(spot)
        local visibAvg = TTTBots.Spots.MeasureSpotVisibility(spot, 512)

        return visibAvg >= SNIPER_MIN_VIS_PCT
    end

    local BOMB_MAX_VIS_PCT = 41
    local BombFunc = function(spot)
        local visibAvg = TTTBots.Spots.MeasureSpotVisibility(spot, 256)

        return visibAvg <= BOMB_MAX_VIS_PCT
    end

    TTTBots.Spots.RegisterSpotCategory("sniperExclusionary", SniperExclusionaryFunc)
    TTTBots.Spots.RegisterSpotCategory("hiding", HidingFunc)
    TTTBots.Spots.RegisterSpotCategory("sniper", SniperFunc)
    TTTBots.Spots.RegisterSpotCategory("bomb", BombFunc)
end
