TTTBots.Lib = {}

include("includes/data/usernames.lua")

-- Import components for bot creation
include("includes/components/locomotor.lua")

local Lib = TTTBots.Lib
local format = string.format

-- Check if not :IsSpec and :Alive, pretty much makes code look neater
function Lib.IsBotAlive(bot)
    return IsValid(bot) and not (bot:IsSpec() and bot:Alive())
end

function Lib.PrintInitMessage()
    print("~~~~~~~~~~~~~~~~~~~~~")
    print("TTT Bots initialized!")
    print(format("Version: %s", TTTBots.Version))
    print(format("Number of players: %s/%s", #player.GetAll(), game.MaxPlayers()))
    print(format("Gamemode: %s", engine.ActiveGamemode()) ..
        " | (Compatible = " .. tostring(Lib.CheckCompatibleGamemode()) .. ")")
    print("NOTE: If you are reading this as a dedicated server owner, you cannot use chat commands remotely, your character must be in the server for that. You may still use concommands.")
    print("~~~~~~~~~~~~~~~~~~~~~")
end

function Lib.CheckIfPlayerSlots()
    return not (#player.GetAll() >= game.MaxPlayers())
end

function Lib.CheckCompatibleGamemode()
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

function Lib.CreateBot(name)
    if not Lib.CheckIfPlayerSlots() then
        TTTBots.Chat.BroadcastInChat("Somebody tried to add a bot, but there are not enough player slots.")
        return false
    end
    name = name or TTTBots.Lib.GenerateName()
    local bot = player.CreateNextBot(name)

    bot.components = {
        locomotor = TTTBots.Components.Locomotor:New(bot)
    }

    print(string.format("%s created bot named %s", ply and ply:Nick() or "[Server]", bot:Nick()))

    return bot
end

-- Trace line from eyes (if fromEyes, else feet) to the given position. Returns the trace result.
-- This is used to cut corners when pathfinding.
function Lib.TraceVisibilityLine(player, fromEyes, finish)
    local startPos = player:GetPos()
    if fromEyes then
        startPos = player:EyePos()
    end
    local trace = util.TraceLine({
        start = startPos,
        endpos = finish,
        filter = player,
        mask = MASK_PLAYERSOLID
    })
    return trace
end