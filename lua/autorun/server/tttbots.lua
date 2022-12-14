--# Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
}

--# Initialize all of our libraries
include("includes/commonlib.lua")
include("includes/chatcommands.lua")

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