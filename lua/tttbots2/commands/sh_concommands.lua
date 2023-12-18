--# Local Variables
local Lib = TTTBots.Lib
local f = string.format
local printf = function(...) print(f(...)) end
local sharedFunctions = {}

local IsPlayerSuperAdmin = function(ply)
    return ply == NULL --dedicated server console
        or (IsValid(ply) and ply:IsSuperAdmin())
end

---Gets a string that is either the player's :Nick or else default (or else [Server])
---@param ply Player
---@param default? string If nil, defaults to "[Server]"
---@return string
local GetNickOrDefault = function(ply, default)
    return IsValid(ply) and ply:Nick() or (default or "[Server]")
end

local NotifyPlyOrServer = function(ply, message)
    if ply == NULL then
        print(message)
    else
        TTTBots.Chat.MessagePlayer(ply, message)
    end
end

local FuzzySearchPlys = function(name)
    local plys = player.GetAll()
    local plysFound = {}
    for i, ply in pairs(plys) do
        if string.find(string.lower(ply:Nick()), string.lower(name)) then
            table.insert(plysFound, ply)
        end
    end
    return plysFound
end
local FuzzySearchFirstPly = function(name)
    local plys = FuzzySearchPlys(name)
    if #plys == 0 then
        return nil
    end
    return plys[1]
end

local CreateSharedConCommand = function(name, serverCallback)
    sharedFunctions[name] = serverCallback
    concommand.Add(name, function(ply, _, args)
        if SERVER then
            serverCallback(ply, _, args)
        else
            net.Start("TTTBots_RequestConCommand")
            net.WriteString(name)
            net.WriteTable(args)
            net.SendToServer()
        end
    end)
end

--# ConCommands
CreateSharedConCommand("ttt_bot_add", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
    local number = tonumber(args[1]) or 1
    for i = 1, number do
        local bot = Lib.CreateBot()
        if not bot then return end
        print(string.format("%s created bot %s", GetNickOrDefault(ply), GetNickOrDefault(bot, "???")))
    end
end)

concommand.Add("ttt_bot_version", function(ply, _, args)
    print("TTTBots version: " .. TTTBots.Version)
end)

CreateSharedConCommand("ttt_bot_kickall", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
    for _, bot in pairs(TTTBots.Bots) do
        bot:Kick("Kicked by " .. (GetNickOrDefault(ply)) .. " using ttt_bot_kickall")
    end
end)

CreateSharedConCommand("ttt_bot_kick", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
    local botname = args[1]
    local kickSuccess = false
    local GLS = TTTBots.Locale.GetLocalizedString
    if not botname then
        NotifyPlyOrServer(ply, GLS("no.kickname"))
        return
    end

    if botname == "all" then
        RunConsoleCommand("ttt_bot_kickall")
        return
    end

    local bot = FuzzySearchFirstPly(botname)
    if bot then
        bot:Kick(GLS("bot.kicked.reason", GetNickOrDefault(ply)))
        TTTBots.Chat.BroadcastInChat(GLS("bot.kicked", GetNickOrDefault(ply), GetNickOrDefault(bot, "[Unknown]")))
        kickSuccess = true
    end

    if not kickSuccess then
        NotifyPlyOrServer(ply, GLS("bot.not.found", botname))
    end
end)

CreateSharedConCommand("ttt_bot_reload", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
    TTTBots.Reload()
    RunConsoleCommand("ttt_roundrestart")
end)

CreateSharedConCommand('ttt_bot_recache_spots', function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
    TTTBots.Spots.CacheAllSpots()
end)

CreateSharedConCommand("ttt_bot_recache_regions", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA

    PrintTable(TTTBots.Lib.GetNavRegions(true))
end)

CreateSharedConCommand("ttt_bot_debug_locomotor", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
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

CreateSharedConCommand("ttt_bot_nav_cullconnections", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
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

CreateSharedConCommand("ttt_bot_nav_generate", function(ply, _, args)
    if SERVER and ply == NULL then
        print("You must be in-game to use this command, sorry.")
        return
    end
    if not ply then return end
    if not ply:IsSuperAdmin() then return end
    local plyPos = ply:GetPos()
    local upNormal = Vector(0, 0, 1)
    navmesh.AddWalkableSeed(plyPos, upNormal)
    navmesh.BeginGeneration()
    RunConsoleCommand("ttt_bot_nav_cullconnections")
    RunConsoleCommand("ttt_bot_nav_markdangerousnavs")
end)

CreateSharedConCommand("ttt_bot_nav_markdangerousnavs", function(ply, _, args)
    if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA

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

if SERVER then
    concommand.Add("ttt_bot_print_ents", function(ply, _, args)
        if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
        for i, v in pairs(ents.GetAll()) do
            print(v:GetClass(), v:GetClass() == "prop_physics" and v:GetModel() or "")
        end
    end)

    concommand.Add("ttt_bot_print_archetypes", function(ply, _, args)
        if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
        for i, v in pairs(TTTBots.Bots) do
            if v and v.components and v.components.personality then
                local personality = v.components.personality ---@type CPersonality
                printf("BOT %s is a '%s.'", v:Nick(), personality.archetype)
            end
        end
    end)

    --- Print rage, boredom, and pressure for all bots.
    concommand.Add("ttt_bot_print_rbp", function(ply, _, args)
        if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
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

    concommand.Add("ttt_bot_print_difficulty", function(ply, _, args)
        if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
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

    concommand.Add("ttt_bot_print_heldweapons", function(ply, _, args)
        if not IsPlayerSuperAdmin(ply) then return end -- cmd only works as server or SA
        print("PRINTING HELD WEAPONS")
        print("---------------------")
        for i, ply in pairs(player.GetAll()) do
            if not Lib.IsPlayerAlive(ply) then continue end
            local wep = ply:GetActiveWeapon()
            if wep then
                local canBuy = wep.CanBuy
                local canSpawn = wep.AutoSpawnable
                local isTraitorWep = wep.CanBuy[ROLE_TRAITOR] and true or false
                printf("Player %s is holding a %s. CanBuy=%s, AutoSpawnable=%s, IsTraitorWep=%s", ply:Nick(),
                    wep:GetClass(),
                    tostring(canBuy), tostring(canSpawn), tostring(isTraitorWep))
            end
        end
        print("---------------------")
    end)

    net.Receive("TTTBots_RequestConCommand", function(len, ply)
        if not IsPlayerSuperAdmin(ply) then return end     -- we can only request console commands from the server or superadmins
        if ply == NULL or not IsValid(ply) then return end -- Not accepted by server console, as this should only be called on request from client
        local name = net.ReadString()
        local args = net.ReadTable()
        if not sharedFunctions[name] then return end
        local sharedFunc = sharedFunctions[name]
        printf("Player %s, who is a superadmin, called concommand '%s' remotely.", ply:Nick(), name)
        sharedFunc(ply, nil, args)
    end)
end
