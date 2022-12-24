-- No need for this module to be defined globally.
local FCVAR = FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED + FCVAR_LUA_SERVER

--# Server ConVars
CreateConVar("ttt_bot_community_names", "1", FCVAR, "Enables community-suggested names. WARNING: Potentially offensive, not family-friendly.")
CreateConVar("ttt_bot_debug_pathfinding", "1", FCVAR,
    "Enables debug for pathfinding. Requires built-in developer convar to be 1.")
CreateConVar("ttt_bot_debug_look", "1", FCVAR,
    "Enables debug for looking at things. Requires built-in developer convar to be 1.")


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
        if bot:Nick() == botname then
            bot:Kick("Kicked by " .. (ply and ply:Nick() or "[Server]") .. " using ttt_bot_kick")
            return
        end
    end
end)