-- No need for this module to be defined globally.
local FCVAR = FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED + FCVAR_LUA_SERVER


--# Server ConVars
local cvar = CreateConVar("test_cvar", "0", FCVAR, "This is a test cvar")

--# Server Commands
concommand.Add("test_command", function(ply, cmd, args)
    print("This is a test command")
    print("provided args are", args)
end)

concommand.Add("ttt_bot_add", function(ply, cmd, args)
    local name = TTTBots.Lib.GenerateName()
    local bot = TTTBots.Lib.CreateBot(name)
    print(string.format("%s created bot named %s", ply and ply:Nick() or "[Server]", bot:Nick()))
end)