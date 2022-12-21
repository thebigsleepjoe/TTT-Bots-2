--# Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
}

--# Initialize all of our libraries
include("includes/commonlib.lua")
include("includes/chatcommands.lua")
include("includes/debugserver.lua")

include("includes/cvarscommands.lua")

--# Shorthands
local Lib = TTTBots.Lib
local Chat = TTTBots.Chat

--# Pre-check before initializing
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

--# Initializing
print("good to go")

--# Bot behavior
timer.Create("TTTBots_BotBehavior", 0.1, 0, function()

    -- Use TTTBots.DebugServer to draw line to indicate where each bot is currently looking
    local bots = player.GetBots()
    for _, bot in pairs(bots) do
        TTTBots.DebugServer.DrawBotLook(bot)
    end

end)