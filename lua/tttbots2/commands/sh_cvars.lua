print("[TTT Bots 2] Loading shared cvars...")

local SH_FCVAR = { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER }

local function bot_sh_cvar(name, def, desc)
    return CreateConVar("ttt_bot_" .. name, def, SH_FCVAR, desc)
end


bot_sh_cvar("language", "en",
    "Changes the language that the bots speak in text chat, and may modify some GUI strings. Example is 'en' or 'es'")
bot_sh_cvar("pfps", "1", "Bots can have AI-related profile pictures in the scoreboard")
bot_sh_cvar("pfps_humanlike", "0", "Bots can have AI-related profile pictures in the scoreboard")
bot_sh_cvar("emulate_ping", "0",
    "Bots will emulate a humanlike ping (does not affect gameplay and is cosmetic.) This is to be used in servers of players that consent to playing with bots. It's a flavor feature for friends.")
