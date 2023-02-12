-- No need for this module to be defined globally.
local FCVAR = FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED + FCVAR_LUA_SERVER

--# Server ConVars
CreateConVar("ttt_bot_community_names", "1", FCVAR, "Enables community-suggested names. WARNING: Potentially offensive, not family-friendly.")
CreateConVar("ttt_bot_debug_pathfinding", "1", FCVAR,
    "Enables debug for pathfinding. Requires built-in developer convar to be 1.")
CreateConVar("ttt_bot_debug_look", "1", FCVAR,
    "Enables debug for looking at things. Requires built-in developer convar to be 1.")
CreateConVar("ttt_bot_debug_all", "1", FCVAR,
    "Enables all debug. This will set ttt_idle_limit to 99999 and set developer to 1.")


--# Local Variables
local Lib = TTTBots.Lib

--# ConCommands
concommand.Add("ttt_bot_add", function(ply, cmd, args)
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
    for _, bot in pairs(player.GetBots()) do
        bot:Kick("Kicked by " .. (ply and ply:Nick() or "[Server]") .. " using ttt_bot_kickall")
    end
end)

concommand.Add("ttt_bot_kick", function(ply, cmd, args)
    local botname = args[1]
    if not botname then
        TTTBots.Chat.MessagePlayer(ply, "You must specify a bot name.")
        return
    end
    for _, bot in pairs(player.GetBots()) do
        if bot:Nick() == botname or botname == "all" then
            bot:Kick("Kicked by " .. (ply and ply:Nick() or "[Server]") .. " using ttt_bot_kick")
        end
        if not botname == "all" then
            return
        end
    end
end)

concommand.Add("ttt_bot_debug_locomotor", function(ply, cmd, args)
    -- Execute ttt_bot_kickall, then ttt_bot_add, then ttt_roundrestart.
    -- This will remove all bots, then add one back, and then restart the round.
    RunConsoleCommand("ttt_bot_kickall")
    RunConsoleCommand("ttt_bot_add", "1")
    RunConsoleCommand("ttt_roundrestart")
    RunConsoleCommand("ttt_bot_debug_pathfinding", "1")

    -- Wait for a quarter-second, then teleport the human player to the bot.
    timer.Simple(0.25, function()
        local bot = player.GetBots()[1]
        if not bot then return end
        ply:SetPos(bot:GetPos() + Vector(0, 0, 50))
    end)
end)