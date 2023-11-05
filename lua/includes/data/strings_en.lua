--- This file differs from chatter, as the strings are returned with formattable symbols. (like %s, %d, etc.)

local function localize(id, content)
    local lang = "en"
    TTTBots.Locale.AddLocalizedString(id, content, lang)
end

localize("no.navmesh", "[ERROR] This map does not have a navigation mesh! You cannot use bots without one!")
localize("not.server", "[ERROR] You must be playing on a server to use TTT Bots. Sorry! It can be a p2p server or dedicated.")
localize("gamemode.not.compatible", "[ERROR] This gamemode is not compatible with TTT Bots! Shutting up to prevent console spam.")
localize("too.many.regions", "[WARNING] There are %d regions present on this map. It is recommended to keep this number as low as possible. This may cause issues if unresolved.")
localize("not.enough.slots", "[WARNING] There are not enough player slots to add another bot.")
localize("bot.added", "[NOTICE] '%s' added a bot.")
localize("bot.kicked", "[NOTICE] '%s' kicked a bot.")
localize("bot.kicked.all", "[NOTICE] '%s' kicked all bots.")

localize("difficulty.1", "Very Easy")
localize("difficulty.2", "Easy")
localize("difficulty.3", "Normal")
localize("difficulty.4", "Hard")
localize("difficulty.5", "Very Hard")
localize("difficulty.?", "(Not Implemented)")
localize("difficulty.changed", "The TTT Bot difficulty has been changed to %s (from %s)")
localize("difficulty.changed.kickgood", "Since the difficulty was lowered, the server will begin removing some overperforming bots.")
localize("difficulty.changed.kickbad", "Since the difficulty was raised, the server will begin removing some underperforming bots.")