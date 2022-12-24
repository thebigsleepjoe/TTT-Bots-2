-- Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
}

-- Initialize all of our libraries
include("includes/commonlib.lua")
include("includes/chatcommands.lua")
include("includes/cvarscommands.lua")
include("includes/pathmanager.lua")
include("includes/debugserver.lua")

-- Shorthands
local Lib = TTTBots.Lib
local Chat = TTTBots.Chat
local PathManager = TTTBots.PathManager

-- Pre-check before initializing
if Lib.CheckCompatibleGamemode() then
    if Lib.CheckIfPlayerSlots() then
        Lib.PrintInitMessage()
        Chat.BroadcastGreeting()
    else
        Chat.BroadcastInChat("There are no player slots available! You cannot use the TTT Bots mod. Please start up a server to use this mod.")
    end
else
    print("Gamemode is not compatible with TTT Bots. Shutting up to prevent console spam.")
    return
end

-- Initializing
print("good to go")

-- Bot behavior
timer.Create("TTTBots_BotBehavior", 0.1, 0, function()

    for i,bot in pairs(player.GetBots()) do
        TTTBots.DebugServer.RenderDebugFor(bot, { "all" })

        -- Generate test path between our position and the first real player's
        local ply = player.GetHumans()[1]
        if ply then
            -- PathManager.SetPath(identifier, goalpos, startpos, bot, algorithm, recheckevery)
            PathManager.SetPath("testfor"..bot:Nick(), ply:GetPos(), bot:GetPos(), bot, "astar", 0.1)
        end
    end

end)