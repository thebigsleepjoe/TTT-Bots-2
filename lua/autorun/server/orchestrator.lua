-- Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
}

-- Initialize all of our libraries
include("includes/lib/commonlib.lua")
include("includes/lib/pathmanager.lua")
include("includes/lib/debugserver.lua")
include("includes/lib/miscnetwork.lua")

-- Initialize command libraries
include("includes/commands/chatcommands.lua")
include("includes/commands/cvars.lua")
include("includes/commands/concommands.lua")

-- Initialize behaviors
include("includes/behaviors/main.lua")

-- Future modules:
-- Bot speech manager, for playing voice lines and chatting in-game when something happens
-- (will figure out more later)

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
        Chat.BroadcastInChat(
            "There are no player slots available! You cannot use the TTT Bots mod. Please start up a server to use this mod.")
    end
else
    print("Gamemode is not compatible with TTT Bots. Shutting up to prevent console spam.")
    return
end

-- Initializing
print("good to go")

-- Bot behavior
timer.Create("TTTBots_Tick", 0.1, 0, function()
    local call, err = pcall(function()
        for i, bot in pairs(player.GetBots()) do
            -- TTTBots.DebugServer.RenderDebugFor(bot, { "all" })

            for i, component in pairs(bot.components) do
                if component.Think == nil then
                    print("No think")
                    continue
                end
                component:Think()
            end
        end
    end, function(err)
        print(err)
    end)
    if err then
        ErrorNoHalt(err)
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

-- timer.Create("TTTBots_ChangeGoal", 10, 0, function()
--     for i, bot in pairs(player.GetBots()) do
--         local locomotor = bot.components.locomotor

--         -- get look vector of human
--         -- local pos = player.GetHumans()[1]:GetEyeTrace().HitPos
--         -- locomotor:SetGoalPos(pos)

--         -- pick a random area
--         local area = table.Random(navmesh.GetAllNavAreas())
--         locomotor:SetGoalPos(area:GetCenter())
--     end
-- end)
