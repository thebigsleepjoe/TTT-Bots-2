--# Local Variables
local Lib = TTTBots.Lib
local f = string.format
local printf = function(...) print(f(...)) end

--# ConCommands
concommand.Add("ttt_bot_add", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    local number = tonumber(args[1])
    if number then
        for i = 1, number do
            local bot = Lib.CreateBot()
            if not bot then return end
            print(string.format("%s created bot named %s", ply and ply:Nick() or "[Server]", bot:Nick()))
        end
    else
        local bot = Lib.CreateBot()
        if not bot then return end
        print(string.format("%s created bot named %s", ply and ply:Nick() or "[Server]", bot:Nick()))
    end
end)

concommand.Add("ttt_bot_kickall", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    for _, bot in pairs(TTTBots.Bots) do
        bot:Kick("Kicked by " .. (ply and ply:Nick() or "[Server]") .. " using ttt_bot_kickall")
    end
end)

concommand.Add("ttt_bot_kick", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    local botname = args[1]
    if not botname then
        TTTBots.Chat.MessagePlayer(ply, "You must specify a bot name.")
        return
    end
    for _, bot in pairs(TTTBots.Bots) do
        if bot:Nick() == botname or botname == "all" then
            bot:Kick("Kicked by " .. (ply and ply:Nick() or "[Server]") .. " using ttt_bot_kick")
        end
        if not botname == "all" then
            return
        end
    end
end)

concommand.Add("ttt_bot_reload", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    TTTBots.Reload()
    RunConsoleCommand("ttt_roundrestart")
end)

concommand.Add('ttt_bot_recache_spots', function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    TTTBots.Spots.CacheAllSpots()
end)

concommand.Add("ttt_bot_recache_regions", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA

    TTTBots.Lib.GetNavRegions(true)
end)


concommand.Add("ttt_bot_debug_locomotor", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    -- Execute ttt_bot_kickall, then ttt_bot_add, then ttt_roundrestart.
    -- This will remove all bots, then add one back, and then restart the round.
    RunConsoleCommand("ttt_bot_kickall")
    RunConsoleCommand("ttt_bot_add", "1")
    RunConsoleCommand("ttt_roundrestart")
    RunConsoleCommand("ttt_bot_debug_pathfinding", "1")

    -- Wait for a quarter-second, then teleport the human player to the bot.
    timer.Simple(0.25, function()
        local bot = TTTBots.Bots[1]
        if not bot then return end
        ply:SetPos(bot:GetPos() + Vector(0, 0, 50))
    end)
end)

concommand.Add("ttt_bot_nav_cullconnections", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    -- For each node in the navmesh, get its adjacents. Calculate the edge-to-edge distance between the two nodes.
    -- if it's jumping more than 40 units, then it's not a valid connection. Remove it.
    local navmesh = navmesh.GetAllNavAreas()
    local nBogus = 0
    for i, node in pairs(navmesh) do
        local adjacents = node:GetAdjacentAreas()
        for i, adjacent in pairs(adjacents) do
            local heightChange = node:ComputeAdjacentConnectionHeightChange(adjacent)
            if heightChange > 64 then
                node:Disconnect(adjacent)
                nBogus = nBogus + 1
            end
        end
    end
    print("Number of bogus connections removed: " .. nBogus)
end)

concommand.Add("ttt_bot_nav_generate", function(ply, cmd, args)
    if not ply then
        print("You must be in-game to run this, sorry.")
        return
    end
    if not ply:IsSuperAdmin() then return end
    print("Beginning generation.")
    local plyPos = ply:GetPos()
    local upNormal = Vector(0, 0, 1)
    navmesh.AddWalkableSeed(plyPos, upNormal)
    navmesh.BeginGeneration()
    -- run ttt_bot_cullconnections and ttt_bot_nav_markdangerousnavs
    print("Culling weird connections")
    ply:ConCommand("ttt_bot_nav_cullconnections")
    print("Marking dangerous navs (e.g., areas within trigger_hurts)")
    ply:ConCommand("ttt_bot_nav_markdangerousnavs")
end)

concommand.Add("ttt_bot_nav_markdangerousnavs", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA

    -- local navmesh = navmesh.GetAllNavAreas()
    local hazards = ents.FindByClass("trigger_hurt")

    for i, hazard in pairs(hazards) do
        -- TTTBots.DebugServer.DrawCross(hazard:GetPos(), 10, Color(255, 0, 0), 10)
        -- Let's draw a box around it instead
        local mins, maxs = hazard:OBBMins(), hazard:OBBMaxs()
        local pos = hazard:GetPos()
        TTTBots.DebugServer.DrawBox(pos, mins, maxs, Color(255, 100, 100, 10), 10)

        -- Get all navs in an area where the radius is the distance between the center and the maxs.
        local radius = pos:Distance(pos + maxs)
        local navs = navmesh.Find(pos, radius, 100, 100)
        for _, nav in pairs(navs) do
            -- First check if the nav's center point is within the box bounds
            if not nav:GetCenter():WithinAABox(pos + mins, pos + maxs) then continue end
            nav:SetAttributes(nav:GetAttributes() + NAV_MESH_AVOID)
            TTTBots.DebugServer.DrawCross(nav:GetCenter(), 20, Color(255, 0, 0), 10)
        end
    end
end)

concommand.Add("ttt_bot_print_ents", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    for i, v in pairs(ents.GetAll()) do
        print(v:GetClass(), v:GetClass() == "prop_physics" and v:GetModel() or "")
    end
end)

concommand.Add("ttt_bot_print_archetypes", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    for i, v in pairs(TTTBots.Bots) do
        if v and v.components and v.components.personality then
            local personality = v.components.personality ---@type CPersonality
            printf("BOT %s is a '%s.'", v:Nick(), personality.archetype)
        end
    end
end)

--- Print rage, boredom, and pressure for all bots.
concommand.Add("ttt_bot_print_rbp", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    print("PER-BOT RAGE-BOREDOM-PRESSURE PRINTOUT")
    print("--------------------------------")
    for i, v in pairs(TTTBots.Bots) do
        if v and v.components and v.components.personality then
            local personality = v.components.personality ---@type CPersonality
            printf("[BOT %s] R: %.2f, B: %.2f, P: %.2f", v:Nick(), (personality.rage or 0),
                (personality.boredom or 0),
                (personality.pressure or 0))
        end
    end
    print("--------------------------------")
end)

concommand.Add("ttt_bot_print_difficulty", function(ply, cmd, args)
    if not ply or not (ply and ply:IsSuperAdmin()) then return end -- cmd only works as server or SA
    local botDifficulty = TTTBots.Match.GetBotsDifficulty()
    print("BOT DIFFICULTY REPORT:")
    print("----------------------------")
    local avgDifficulty = 0
    for bot, diff in pairs(botDifficulty) do
        avgDifficulty = avgDifficulty + diff
        printf("[BOT %s] %.2f", bot:Nick(), diff)
    end
    avgDifficulty = avgDifficulty / #TTTBots.Bots
    print("Average difficulty: " .. avgDifficulty)
    print("----------------------------")
end)
