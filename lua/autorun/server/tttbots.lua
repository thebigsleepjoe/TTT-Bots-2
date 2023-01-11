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
timer.Create("TTTBots_Tick", 0.1, 0, function()
    -- Set ttt_idle_limit to 999999 to prevent us from getting kicked when debugging
    RunConsoleCommand("ttt_idle_limit", "999999")

    for i,bot in pairs(player.GetBots()) do
        TTTBots.DebugServer.RenderDebugFor(bot, { "all" })

        -- debug: set goal of locomotor to human 1's position
        bot.components.locomotor:SetGoalPos(player.GetHumans()[1]:GetPos())

        for i,component in pairs(bot.components) do
            component:Think()
        end

    end

end)

-- GM:StartCommand
hook.Add("StartCommand", "TTTBots_StartCommand", function(ply, cmd)
    if ply:IsBot() then
        local bot = ply
        local locomotor = bot.components.locomotor

        -- Update locomotor
        locomotor:StartCommand(cmd)
    end
end)