-- Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
}

-- Initialize all of our libraries
include("includes/lib/commonlib.lua")
include("includes/lib/pathmanager.lua")
include("includes/lib/debugserver.lua")

-- Initialize command libraries
include("includes/commands/chatcommands.lua")
include("includes/commands/cvarscommands.lua")

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
    if Lib.GetDebugFor("all") then
        RunConsoleCommand("ttt_idle_limit", "999999")
        RunConsoleCommand("developer", "1")
    end

    for i,bot in pairs(player.GetBots()) do
        -- TTTBots.DebugServer.RenderDebugFor(bot, { "all" })

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

timer.Create("TTTBots_ChangeGoal", 1, 0, function()
    for i,bot in pairs(player.GetBots()) do
        local locomotor = bot.components.locomotor
        
        -- get look vector of human
        local pos = player.GetHumans()[1]:GetEyeTrace().HitPos
        locomotor:SetGoalPos(pos)
        
        -- pick a random area
        -- local area = table.Random(navmesh.GetAllNavAreas())
        -- locomotor:SetGoalPos(area:GetCenter())

    end
end)