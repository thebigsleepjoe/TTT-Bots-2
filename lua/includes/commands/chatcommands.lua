TTTBots.Chat = TTTBots.Chat or {}
local Chat = TTTBots.Chat

local function fuzzySearchTbl(tbl, name)
    local tblFound = {}
    for i, v in pairs(tbl) do
        if string.find(string.lower(v), string.lower(name)) then
            table.insert(tblFound, v)
        end
    end
    return tblFound
end

local function fuzzySearchPlys(name)
    local plys = player.GetAll()
    local plysFound = {}
    for i, ply in pairs(plys) do
        if string.find(string.lower(ply:Nick()), string.lower(name)) then
            table.insert(plysFound, ply)
        end
    end
    return plysFound
end

local function fuzzySearchFirstPly(name)
    local plys = fuzzySearchPlys(name)
    if #plys == 0 then
        return nil
    end
    return plys[1]
end

Chat.Commands = {
    ["!botmenu"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end
        TTTBots.Chat.MessagePlayer(ply, "Not implemented yet. Please use the console commands instead.")
    end,
    ["!describe"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end

        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local target = split()                      -- second word is the bot name

        if target == nil then
            TTTBots.Chat.MessagePlayer(ply, "Please specify a bot name.")
            return
        end

        local bot = fuzzySearchFirstPly(target)
        if bot == nil or not bot:IsBot() then
            TTTBots.Chat.MessagePlayer(ply, "Bot named '" .. target .. "' not found.")
            return
        end

        local personality = bot.components.personality
        local traits = personality:GetTraits()
        local str = "Bot " .. bot:Nick() .. " has the following personality traits: "
        for i, trait in pairs(traits) do
            str = str .. trait .. ", "
        end
        str = string.sub(str, 1, -3) -- remove last comma
        TTTBots.Chat.MessagePlayer(ply, str)
    end,
    ["!addbot"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end
        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local amt = split()                         -- second word is the amount of bots to add

        -- check we can convert amt to a number, if it isn't nil or blank
        if amt ~= nil and amt ~= "" then
            amt = tonumber(amt)
            if amt == nil then
                TTTBots.Chat.MessagePlayer(ply, "Please specify a valid number of bots to add.")
                return
            end
        else
            amt = 1
        end

        -- check there are enough player slots
        local isSingle = game.SinglePlayer()
        if isSingle then
            TTTBots.Chat.MessagePlayer(ply,
                "Cannot add bots in singleplayer. Please check the workshop page for a how-to guide.")
            TTTBots.Chat.MessagePlayer(ply, "You must be in a server to use this mod. Don't worry, it's super easy!!")
            return
        end
        local slots = game.MaxPlayers() - #player.GetAll()
        if amt > slots then
            TTTBots.Chat.MessagePlayer(ply, "Not enough player slots to add " .. amt .. " bots.")
            TTTBots.Chat.MessagePlayer(ply,
                "Please consider re-hosting with more player slots, or kick some existing bots.")
            return
        end

        -- add bots
        for i = 1, amt do
            TTTBots.Lib.CreateBot()
        end
    end,
    ["!roundrestart"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end
        local nBots = #TTTBots.Bots
        concommand.Run(ply, "ttt_bot_kickall")
        concommand.Run(ply, "ttt_roundrestart")
        concommand.Run(ply, "ttt_bot_add", { tostring(nBots) })

        -- TTTBots.Chat.MessagePlayer(ply, "Restarted round and added " .. nBots .. " bots.")
        TTTBots.Chat.BroadcastInChat(ply:Nick() .. " restarted the round and added " .. nBots .. " bots.")
    end,
    ["!restartround"] = function(ply, fulltxt)
        Chat.Commands['!roundrestart'](ply, fulltxt)
    end,
    ["!rr"] = function(ply, fulltxt)
        Chat.Commands['!roundrestart'](ply, fulltxt)
    end,
    ["!kickbots"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end
        concommand.Run(ply, "ttt_bot_kickall")
        TTTBots.Chat.BroadcastInChat(ply:Nick() .. " kicked all bots from the server.")
    end,
    ["!bothelp"] = function(ply, fulltxt)
        local mp = TTTBots.Chat.MessagePlayer
        local visibleHelp = {
            addbot = "Adds a bot to the server. Usage: !addbot X, where X is the number of bots to add.",
            kickbots = "Kicks all bots from the server.",
            roundrestart = "Restarts the round and adds the same number of bots as before.",
            describe = "Describes the personality of a bot. Usage: !describe X, where X is the name of the bot.",
            botmenu = "Opens the bot menu. (Not implemented yet)",
            help = "Shows this help message."
        }

        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the !help command
        local func = split()                        -- second word is the func

        if func == nil then
            mp(ply, "Available commands:")
            for cmd, desc in pairs(visibleHelp) do
                mp(ply, cmd .. ": " .. desc)
            end
        else
            if visibleHelp[func] == nil then
                mp(ply, "Command '" .. func .. "' not found. Make sure to not include the ! symbol.")
            else
                mp(ply, func .. ": " .. visibleHelp[func])
            end
        end
    end,
    ["!botdebug"] = function(ply, fulltxt)
        -- Run ttt_bot_debug_showui on the client's end if they're a superadmin
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                "You do not have permission to execute this command. You must be a superadmin.")
            return
        end
        ply:ConCommand("ttt_bot_debug_showui")
    end,
}

function TTTBots.Chat.MessagePlayer(ply, message)
    ply:ChatPrint("[TTT Bots] " .. message)
end

hook.Add("PlayerSay", "TTTBots.PlayerSay", function(ply, text, team)
    if ply:IsBot() then return end
    local cvarTest = TTTBots.Lib.GetConVarBool("enable_chat_cmds")
    if not cvarTest then return end
    local fulltxt = string.lower(text)
    local split = string.gmatch(fulltxt, "%S+") -- split by spaces
    local cmd = split()                         -- first word is the command

    if Chat.Commands[cmd] ~= nil then
        Chat.Commands[cmd](ply, fulltxt)
        return false
    end
end)
