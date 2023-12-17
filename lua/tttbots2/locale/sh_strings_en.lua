--- This file differs from chatter, as the strings are returned with formattable symbols. (like %s, %d, etc.)

local function localize(id, content)
    local lang = "en"
    TTTBots.Locale.AddLocalizedString(id, content, lang)
end

localize("not.implemented",
    "[ERROR] Not implemented yet. Please use the console commands instead. Check the workshop page or the github for a tutorial on how to use this mod.")
localize("bot.not.found", "[ERROR] Bot named '%s' not found.")
localize("specify.bot.name", "[ERROR] Please specify a bot name.")
localize("invalid.bot.number", "[ERROR] Please specify a valid number of bots to add.")
localize("no.navmesh", "[ERROR] This map does not have a navigation mesh! You cannot use bots without one!")
localize("not.server",
    "[ERROR] You must be playing on a server to use TTT Bots. Sorry! It can be a p2p server or dedicated.")
localize("not.server.guide", "[ERROR] Don't worry! Check the TTT Bots workshop page for a guide on how to host a server.")
localize("not.superadmin", "[ERROR] You cannot run this command unless you are a superadmin in this server.")
localize("gamemode.not.compatible",
    "[ERROR] This gamemode is not compatible with TTT Bots! Shutting up to prevent console spam.")
localize("too.many.regions",
    "[WARNING] There are %d regions present on this map. It is recommended to keep this number as low as possible. This may cause issues if unresolved.")
localize("not.enough.slots", "[WARNING] There are not enough player slots to add another bot.")
localize("not.enough.slots.n", "[WARNING] There are not enough player slots to add %s bots.")
localize("consider.kicking", "[WARNING] Please consider kicking some bots, or create a server with more slots.")
localize("bot.added", "[NOTICE] '%s' added a bot.")
localize("bot.kicked", "[NOTICE] '%s' kicked a bot (%s).")
localize("bot.kicked.reason", "Kicked by server administrator '%s'")
localize("bot.kicked.all", "[NOTICE] '%s' kicked all bots.")
localize("bot.rr", "[NOTICE] '%s' restarted the round and added %s bots.")
localize("bot.quota.changed", "[NOTICE] %s adjusted the bot quota to %d bots.")
localize("bot.notice", "[NOTICE] You are playing a match with %d TTT bots in the server.")

localize("difficulty.1", "Very Easy")
localize("difficulty.2", "Easy")
localize("difficulty.3", "Normal")
localize("difficulty.4", "Hard")
localize("difficulty.5", "Very Hard")
localize("difficulty.?", "(Not Implemented)")
localize("difficulty.invalid", "The difficulty you have entered is invalid. It must be a number from 1-5.")
localize("difficulty.changed", "The TTT Bot difficulty has been changed to %s (from %s)")
localize("difficulty.current", "The current difficulty is set to '%s'")
localize("difficulty.changed.kickgood",
    "Since the difficulty was lowered, the server may begin removing overperforming bots where necessary.")
localize("difficulty.changed.kickbad",
    "Since the difficulty was raised, the server may begin removing underperforming bots where necessary.")
localize("following.traits", " has the following personality traits: ")

localize("help.botadd",
    "Adds a bot to the server. Usage: !addbot X, where X is the number of bots to add. X is optional and can be left blank.")
localize("help.botkickall", "Kicks all bots from the server.")
localize("help.botrr", "Restarts the round and adds the same number of bots as before.")
localize("help.botdescribe", "Describes the personality of a bot. Usage: !describe X, where X is the name of the bot.")
localize("help.botmenu", "Opens the bot menu. (Not implemented yet)")
localize("help.botdifficulty",
    "Changes the difficulty of the bots. Usage: !difficulty X, where X is the difficulty integer (1-to-5).")
localize("help.bothelp", "Shows this menu.")
localize("no.kickname", "You must provide a bot name to kick.")
localize("bot.not.found", "No bot matches the name '%s'")
