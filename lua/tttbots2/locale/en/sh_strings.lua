--- This file differs from chatter, as the strings are returned with formattable symbols. (like %s, %d, etc.)

local function loc(id, content)
    local lang = "en"
    TTTBots.Locale.AddLocalizedString(id, content, lang)
end

loc("not.implemented",
    "[ERROR] Not implemented yet. Please use the console commands instead. Check the workshop page or the github for a tutorial on how to use this mod.")
loc("bot.not.found", "[ERROR] Bot named '%s' not found.")
loc("specify.bot.name", "[ERROR] Please specify a bot name.")
loc("invalid.bot.number", "[ERROR] Please specify a valid number of bots to add.")
loc("no.navmesh", "[ERROR] This map does not have a navigation mesh! You cannot use bots without one!")
loc("not.server",
    "[ERROR] You must be playing on a server to use TTT Bots. Sorry! It can be a p2p server or dedicated.")
loc("not.server.guide", "[ERROR] Don't worry! Check the TTT Bots workshop page for a guide on how to host a server.")
loc("not.superadmin", "[ERROR] You cannot run this command unless you are a superadmin in this server.")
loc("gamemode.not.compatible",
    "[ERROR] This gamemode is not compatible with TTT Bots! Shutting up to prevent console spam.")
loc("too.many.regions",
    "[WARNING] There are %d regions present on this map. It is recommended to keep this number as low as possible. This may cause issues if unresolved.")
loc("not.enough.slots", "[WARNING] There are not enough player slots to add another bot.")
loc("not.enough.slots.n", "[WARNING] There are not enough player slots to add %s bots.")
loc("consider.kicking", "[WARNING] Please consider kicking some bots, or create a server with more slots.")

loc("bot.added", "[NOTICE] '%s' added a bot.")
loc("bot.kicked", "[NOTICE] '%s' kicked a bot (%s).")
loc("bot.kicked.reason", "Kicked by server administrator '%s'")
loc("bot.kicked.all", "[NOTICE] '%s' kicked all bots.")
loc("bot.rr", "[NOTICE] '%s' restarted the round and added %s bots.")
loc("bot.quota.changed", "[NOTICE] %s adjusted the bot quota to %d bots.")
loc("bot.notice", "[NOTICE] You are playing a match with %d TTT bots in the server.")
loc("fail.create.bot",
    "A bot could not be created. Please verify you are in a server (P2P or SRCDS) with sufficient player slots.")

loc("difficulty.1", "Very Easy")
loc("difficulty.2", "Easy")
loc("difficulty.3", "Normal")
loc("difficulty.4", "Hard")
loc("difficulty.5", "Very Hard")
loc("difficulty.?", "(Not Implemented)")
loc("difficulty.invalid", "The difficulty you have entered is invalid. It must be a number from 1-5.")
loc("difficulty.changed", "The TTT Bot difficulty has been changed to %s (from %s)")
loc("difficulty.current", "The current difficulty is set to '%s'")
loc("difficulty.changed.kickgood",
    "Since the difficulty was lowered, the server may begin removing overperforming bots where necessary.")
loc("difficulty.changed.kickbad",
    "Since the difficulty was raised, the server may begin removing underperforming bots where necessary.")
loc("following.traits", " has the following personality traits: ")

loc("help.botadd",
    "Adds a bot to the server. Usage: !addbot X, where X is the number of bots to add. X is optional and can be left blank.")
loc("help.botkickall", "Kicks all bots from the server.")
loc("help.botrr", "Restarts the round and adds the same number of bots as before.")
loc("help.botdescribe", "Describes the personality of a bot. Usage: !describe X, where X is the name of the bot.")
loc("help.botmenu", "Opens the bot menu. (Not implemented yet)")
loc("help.botdifficulty",
    "Changes the difficulty of the bots. Usage: !difficulty X, where X is the difficulty integer (1-to-5).")
loc("help.bothelp", "Shows this menu.")
loc("no.kickname", "You must provide a bot name to kick.")
loc("bot.not.found", "No bot matches the name '%s'")

-- Botmenu
loc('dashboard', 'Dashboard')
loc('current.bots', 'Current Bots')
loc('build.a.bot', 'Build-a-Bot')
loc('bot.names', 'Bot Names')
loc('traits', 'Traits')
loc('buyables', 'Buyables')
loc('mod.language', 'Mod Language | Examples are "en" or "fr"')
loc('quota.num', 'Quota Number | The # of bots to keep in the game. 0 = off')
loc('quota.mode', 'Quota Mode | Always have an "exact" X bots, or "fill" to X slots')
