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

local gls = TTTBots.Locale.GetLocalizedString

Chat.Commands = {
    ["!botmenu"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end
        TTTBots.Chat.MessagePlayer(ply, gls("not.implemented"))
    end,
    ["!botdescribe"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end

        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local target = split()                      -- second word is the bot name

        if target == nil then
            TTTBots.Chat.MessagePlayer(ply, gls("specify.bot.name"))
            return
        end

        local bot = fuzzySearchFirstPly(target)
        if bot == nil or not bot:IsBot() then
            TTTBots.Chat.MessagePlayer(ply, gls('bot.not.found', target))
            return
        end

        local personality = bot.components.personality
        local traits = personality:GetTraits()
        local str = "Bot " .. bot:Nick() .. gls("following.traits")
        for i, trait in pairs(traits) do
            str = str .. trait .. ", "
        end
        str = string.sub(str, 1, -3) -- remove last comma
        TTTBots.Chat.MessagePlayer(ply, str)
    end,
    ["!addbot"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end
        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local amt = split()                         -- second word is the amount of bots to add

        -- check we can convert amt to a number, if it isn't nil or blank
        if amt ~= nil and amt ~= "" then
            amt = tonumber(amt)
            if amt == nil then
                TTTBots.Chat.MessagePlayer(ply, gls("invalid.bot.number"))
                return
            end
        else
            amt = 1
        end

        -- check there are enough player slots
        local isSingle = game.SinglePlayer()
        if isSingle then
            TTTBots.Chat.MessagePlayer(ply, gls("not.server"))
            TTTBots.Chat.MessagePlayer(ply, gls("not.server.guide"))
            return
        end
        local slots = game.MaxPlayers() - #player.GetAll()
        if amt > slots then
            TTTBots.Chat.MessagePlayer(ply, gls("not.enough.slots.n", tostring(amt)))
            TTTBots.Chat.MessagePlayer(ply, gls("consider.kicking"))
            return
        end

        -- add bots
        for i = 1, amt do
            TTTBots.Lib.CreateBot()
        end
    end,
    ["!botadd"] = function(ply, fulltxt)
        Chat.Commands['!roundrestart'](ply, fulltxt)
    end,
    ["!botrr"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end
        local nBots = #TTTBots.Bots
        concommand.Run(ply, "ttt_bot_kickall")
        concommand.Run(ply, "ttt_roundrestart")
        concommand.Run(ply, "ttt_bot_add", { tostring(nBots) })

        TTTBots.Chat.BroadcastInChat(gls("bot.rr", ply:Nick(), tostring(nBots)))
    end,
    ["!botkickall"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end
        concommand.Run(ply, "ttt_bot_kickall")
        TTTBots.Chat.BroadcastInChat(gls("bot.kicked.all", ply:Nick()))
    end,
    ["!botdifficulty"] = function(ply, fulltxt)
        if not ply:IsSuperAdmin() then
            TTTBots.Chat.MessagePlayer(ply,
                gls("not.superadmin"))
            return
        end

        local split = string.gmatch(fulltxt, "%S+") -- split by spaces
        local cmd = split()                         -- first word is the command
        local difficulty = split()                  -- second arg is the difficulty, if any

        if not difficulty then
            local curDifficulty = TTTBots.Lib.GetConVarInt("difficulty")
            local index = "difficulty." .. curDifficulty
            local difficultyName = gls(index)
            TTTBots.Chat.MessagePlayer(ply, gls("difficulty.current", difficultyName))
            return
        end

        local possibleDiffs = {
            ['1'] = true,
            ['2'] = true,
            ['3'] = true,
            ['4'] = true,
            ['5'] = true,
        }

        if possibleDiffs[difficulty] then
            local curDifficulty = TTTBots.Lib.GetConVarInt("difficulty")
            local index = "difficulty." .. curDifficulty
            local difficultyName = gls(index)
            TTTBots.Chat.MessagePlayer(ply, gls("difficulty.changed", gls("difficulty." .. difficulty), difficultyName))
            ply:ConCommand("ttt_bot_difficulty " .. tostring(difficulty))
            if tonumber(difficulty) < curDifficulty then
                TTTBots.Chat.MessagePlayer(ply, gls("difficulty.changed.kickgood"))
            elseif tonumber(difficulty) > curDifficulty then
                TTTBots.Chat.MessagePlayer(ply, gls("difficulty.changed.kickbad"))
            end
        else
            TTTBots.Chat.MessagePlayer(ply, gls("difficulty.invalid"))
        end
    end,
    ["!bothelp"] = function(ply, fulltxt)
        local mp = TTTBots.Chat.MessagePlayer
        local visibleHelp = {
            botmenu = gls("help.botmenu"),
            botadd = gls("help.botadd"),
            botrr = gls("help.botrr"),
            botkickall = gls("help.botkickall"),
            botdifficulty = gls("help.botdifficulty"),
            botdescribe = gls("help.botdescribe"),
            bothelp = gls("help.bothelp"),
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
                gls("not.superadmin"))
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
