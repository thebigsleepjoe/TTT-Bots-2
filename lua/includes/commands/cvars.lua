local FCVAR = FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED + FCVAR_LUA_SERVER

-- Gameplay-effecting cvars
-- todo

-- Cosmetic cvars
CreateConVar("ttt_bot_community_names", "1", FCVAR,
    "Enables community-suggested names. WARNING: Potentially offensive, not family-friendly.")

-- Debug cvars
CreateConVar("ttt_bot_debug_pathfinding", "1", FCVAR,
    "Enables debug for pathfinding. Requires built-in developer convar to be 1.")
CreateConVar("ttt_bot_debug_look", "1", FCVAR,
    "Enables debug for looking at things. Requires built-in developer convar to be 1.")
CreateConVar("ttt_bot_debug_all", "1", FCVAR,
    "Enables all debug. This will set ttt_idle_limit to 99999 and set developer to 1.")