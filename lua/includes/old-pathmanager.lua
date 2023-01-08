-- This is spaghetti code at its finest, and it will be refactored very soon.

-- manage the creation of pathfinding paths for the bots
TTTBots.PathManager = {}

local PathManager = TTTBots.PathManager
PathManager.cachedPaths = {}

--- Override (or create a new) path in the path manager. 
function PathManager.SetPath(identifier, goalpos, startpos, bot, algorithm, recheckevery)
    -- check that the path doesn't already exist, and if it does then check if it is past recheckevery
    if PathManager.cachedPaths[identifier] then
        if PathManager.cachedPaths[identifier].generated_time + PathManager.cachedPaths[identifier].recheckevery > CurTime() then
            return
        end
    end

    PathManager.cachedPaths[identifier] = {
        goalpos = goalpos,
        startpos = startpos,
        bot = bot,
        algorithm = algorithm, -- currently only supports "astar"
        recheckevery = recheckevery, -- how often should the path be rechecked

        generated = false,
        generated_time = 0,
        generated_start = nil,
        generated_end = nil,
        path = nil
    }
end

function PathManager.GetBotPaths(bot)
    local paths = {}
    for k, v in pairs(PathManager.cachedPaths) do
        if v.bot == bot then
            table.insert(paths, v)
        end
    end
    return paths
end

local function heuristic_cost_estimate( start, goal )
	-- Perhaps play with some calculations on which corner is closest/farthest or whatever
	return start:GetCenter():Distance( goal:GetCenter() )
end

-- using CNavAreas as table keys doesn't work, we use IDs
local function reconstruct_path( cameFrom, current )
	local total_path = { current }

	current = current:GetID()
	while ( cameFrom[ current ] ) do
		current = cameFrom[ current ]
		table.insert( total_path, navmesh.GetNavAreaByID( current ) )
	end
	return total_path
end

local function Astar( start, goal )
	if ( !IsValid( start ) or !IsValid( goal ) ) then return false end
	if ( start == goal ) then return true end

	start:ClearSearchLists()

	start:AddToOpenList()

	local cameFrom = {}

	start:SetCostSoFar( 0 )

	start:SetTotalCost( heuristic_cost_estimate( start, goal ) )
	start:UpdateOnOpenList()

	while ( !start:IsOpenListEmpty() ) do
		local current = start:PopOpenList() -- Remove the area with lowest cost in the open list and return it
		if ( current == goal ) then
			return reconstruct_path( cameFrom, current )
		end

		current:AddToClosedList()

		for k, neighbor in pairs( current:GetAdjacentAreas() ) do
			local newCostSoFar = current:GetCostSoFar() + heuristic_cost_estimate( current, neighbor )

			if ( neighbor:IsUnderwater() ) then -- Add your own area filters or whatever here
				continue
			end
			
			if ( ( neighbor:IsOpen() or neighbor:IsClosed() ) and neighbor:GetCostSoFar() <= newCostSoFar ) then
				continue
			else
				neighbor:SetCostSoFar( newCostSoFar );
				neighbor:SetTotalCost( newCostSoFar + heuristic_cost_estimate( neighbor, goal ) )

				if ( neighbor:IsClosed() ) then
                    -- This area is already on the closed list, remove it
					neighbor:RemoveFromClosedList()
				end

				if ( neighbor:IsOpen() ) then
					-- This area is already on the open list, update its position in the list to keep costs sorted
					neighbor:UpdateOnOpenList()
				else
					neighbor:AddToOpenList()
				end

				cameFrom[ neighbor:GetID() ] = current:GetID()
			end
		end
	end

	return false
end

timer.Create("TTTBots_GeneratePaths", 0.2, 0, function()
    for identifier, path in pairs(PathManager.cachedPaths) do
        if path.generated then
            if CurTime() - path.generated_time > path.recheckevery then
                path.generated = false
                path.generated_time = 0
                path.generated_start = nil
                path.generated_end = nil
                path.path = nil
            end
        else
            if path.bot:IsValid() and path.bot:IsBot() then
                if path.bot:GetPos():Distance(path.startpos) < 100 then
                    if path.algorithm == "astar" then
                        local start = navmesh.GetNearestNavArea(path.startpos)
                        local goal = navmesh.GetNearestNavArea(path.goalpos)
                        if start and goal then
                            path.generated = true
                            path.generated_time = CurTime()
                            path.generated_start = start
                            path.generated_end = goal
                            path.path = Astar(start, goal)

                            -- check if path type is table, and if it isnt, then remove it
                            if type(path.path) ~= "table" then
                                PathManager.cachedPaths[identifier] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end)