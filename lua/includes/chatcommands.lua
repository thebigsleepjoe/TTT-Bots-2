TTTBots.Chat = {}

local Chat = TTTBots.Chat

function Chat.BroadcastInChat(message)
    for _, ply in pairs(player.GetAll()) do
        ply:ChatPrint(message)
    end
end

function Chat.MessagePlayer(ply, message)
    ply:ChatPrint("[TTT Bots] " .. message)
end

function Chat.BroadcastGreeting()
    local broad = Chat.BroadcastInChat
    broad("---------")
    broad("Hello! You are playing on a TTT Bots compatible gamemode!")
    broad("To add a bot, open the GUI menu using !botmenu, or use the console commands provided in the mod's workshop page.")
    broad("---------")
end