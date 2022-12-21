TTTBots.Lib = {}

local Lib = TTTBots.Lib
local format = string.format

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
    local bot = player.CreateNextBot(name)

    return bot
end