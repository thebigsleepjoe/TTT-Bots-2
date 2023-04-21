TTTBots.Chat = {}
local Chat = TTTBots.Chat

Chat.Commands = {
    ["!botmenu"] = function(ply, fullstr)
        if not ply:IsSuperAdmin() then
            Chat.MessagePlayer(ply, "You do not have permission to use this command.")
            return
        end
        Chat.MessagePlayer(ply, "Not implemented yet. Please use the console commands instead.")
    end,
    ["!describe"] = function(ply, fullstr)
        if not ply:IsSuperAdmin() then
            Chat.MessagePlayer(ply, "You do not have permission to use this command.")
            return
        end
        -- example: fullstr="!describe bot1"
        -- outputs in chat the bot personality string (bot.components.personality:GetFlavoredTraits())

        local split = string.gmatch(fullstr, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local botname = split()                     -- second word is the bot name

        if botname == nil then
            Chat.MessagePlayer(ply, "Please specify a bot name.")
            return
        end

        local bot
        for i, v in pairs(player.GetBots()) do
            if string.lower(v:Nick()) == string.lower(botname) then
                bot = v
                break
            end
        end

        if bot == nil then
            Chat.MessagePlayer(ply, "Bot not found.")
            return
        end

        local personality = bot.components.personality
        local traits = personality:GetFlavoredTraits()
        local str = "Bot " .. bot:Nick() .. " has the following personality traits: "
        for i, trait in pairs(traits) do
            str = str .. trait .. ", "
        end
        str = string.sub(str, 1, -3) -- remove last comma
        Chat.MessagePlayer(ply, str)
    end,
    ["!describe2"] = function(ply, fullstr)
        if not ply:IsSuperAdmin() then
            Chat.MessagePlayer(ply, "You do not have permission to use this command.")
            return
        end
        -- Basically same as above, but instead of printing the flavor text we use the trait name
        -- example: fullstr="!describe2 bot1"

        local split = string.gmatch(fullstr, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local botname = split()                     -- second word is the bot name

        if botname == nil then
            Chat.MessagePlayer(ply, "Please specify a bot name.")
            return
        end

        local bot
        for i, v in pairs(player.GetBots()) do
            if string.lower(v:Nick()) == string.lower(botname) then
                bot = v
                break
            end
        end

        if bot == nil then
            Chat.MessagePlayer(ply, "Bot not found.")
            return
        end

        local personality = bot.components.personality
        local traits = personality:GetTraits()
        local str = "Bot " .. bot:Nick() .. " has the following personality traits: "
        for i, trait in pairs(traits) do
            str = str .. trait .. ", "
        end
        str = string.sub(str, 1, -3) -- remove last comma
        Chat.MessagePlayer(ply, str)
    end,
    ["!addbot"] = function(ply, fullstr)
        if not ply:IsSuperAdmin() then
            Chat.MessagePlayer(ply, "You do not have permission to use this command.")
            return
        end
        local split = string.gmatch(fullstr, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local amt = split()                         -- second word is the amount of bots to add

        -- check we can convert amt to a number, if it isn't nil or blank
        if amt ~= nil and amt ~= "" then
            amt = tonumber(amt)
            if amt == nil then
                Chat.MessagePlayer(ply, "Please specify a valid number of bots to add.")
                return
            end
        else
            amt = 1
        end

        -- check there are enough player slots
        local isSingle = game.SinglePlayer()
        if isSingle then
            Chat.MessagePlayer(ply, "Cannot add bots in singleplayer. Please check the workshop page for a how-to guide.")
            return
        end
        local slots = game.MaxPlayers() - #player.GetAll()
        if amt > slots then
            Chat.MessagePlayer(ply, "Not enough player slots to add " .. amt .. " bots.")
            return
        end

        -- add bots
        for i = 1, amt do
            TTTBots.Lib.CreateBot()
        end
    end,
    ["!roundrestart"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            Chat.MessagePlayer(ply, "You do not have permission to use this command.")
            return
        end
        local nBots = #player.GetBots()
        concommand.Run(ply, "ttt_bot_kickall")
        concommand.Run(ply, "ttt_roundrestart")
        concommand.Run(ply, "ttt_bot_add", { tostring(nBots) })

        Chat.MessagePlayer(ply, "Restarted round and added " .. nBots .. " bots.")
    end,
}


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
    broad(
        "To add a bot, open the GUI menu using !botmenu, or use the console commands provided in the mod's workshop page.")
    broad("---------")
end

hook.Add("PlayerSay", "TTTBots.PlayerSay", function(ply, text, team)
    local fulltxt = string.lower(text)
    local split = string.gmatch(fulltxt, "%S+") -- split by spaces
    local cmd = split()                         -- first word is the command

    if Chat.Commands[cmd] ~= nil then
        Chat.Commands[cmd](ply, fulltxt)
        return false
    end
end)
