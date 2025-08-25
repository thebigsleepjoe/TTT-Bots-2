--- This file is a shared resource called by both cl_tttbots2.lua and sv_tttbots2.lua in their respective autorun realms.
--- It is used to initialize the mod and load all of the necessary files.

AddCSLuaFile() -- Add this file to the client's download list

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
local gamemodeCompatible = function()
    local compatible = { ["terrortown"] = true }
    return compatible[engine.ActiveGamemode()] or false
end

if not gamemodeCompatible() then return end

-- Declare TTTBots table
TTTBots = {
    Version = "v1.3.5",
    Tickrate = 5, -- Ticks per second. Do not change unless you really know what you're doing.
    Lib = {},
    Chat = {}
}

function TTTBots.Chat.MessagePlayer(ply, message)
    ply:ChatPrint("[TTT Bots 2] " .. message)
end

local function includeServer()
    include("tttbots2/lib/sv_pathmanager.lua")
    include("tttbots2/lib/sv_debug.lua")
    include("tttbots2/lib/sv_miscnetwork.lua")
    include("tttbots2/lib/sv_debug.lua")
    include("tttbots2/lib/sv_popularnavs.lua")
    include("tttbots2/lib/sv_spots.lua")
    include("tttbots2/lib/sv_plancoordinator.lua")
    include("tttbots2/commands/sv_chatcommands.lua")
    include("tttbots2/lib/sv_dialog.lua")
    include("tttbots2/lib/sv_tree.lua")
    include("tttbots2/lib/sv_buyables.lua")
    include("tttbots2/lib/sv_roles.lua")
end

--- Similar to includeSharedFile, will include the file if we're a client, otherwise will AddCSLuaFile it if we're a server.
local function includeClientFile(path)
    if SERVER then AddCSLuaFile(path) end
    if CLIENT then include(path) end
end

local function includeClient()
    includeClientFile("tttbots2/client/cl_debug3d.lua")
    includeClientFile("tttbots2/client/cl_debugui.lua")
    includeClientFile("tttbots2/client/cl_scoreboard.lua")
    includeClientFile("tttbots2/client/cl_botmenu.lua")
    includeClientFile("tttbots2/client/cl_listener.lua")
end

--- Places the file in the AddCSLuaFile if server, otherwise loads it if we're a client. Includes the file either way.
---@param path string
---@param isReload? boolean = false
local function includeSharedFile(path, isReload)
    if not isReload and SERVER then AddCSLuaFile(path) end
    include(path)
end

---Include the shared files
---@param isReload? boolean = false
local function includeShared(isReload)
    includeSharedFile("tttbots2/lib/sh_botlib.lua", isReload)
    includeSharedFile("tttbots2/commands/sh_cvars.lua", isReload)
    includeSharedFile("tttbots2/commands/sh_concommands.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_match.lua", isReload)
    includeSharedFile("tttbots2/data/sh_traits.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_languages.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_botlib.lua", isReload)
end

-- These first two need to run on both realms so we can AddCSLuaFile.
includeShared()
includeClient()

if not SERVER then return end
util.AddNetworkString("TTTBots_DrawData")
util.AddNetworkString("TTTBots_ClientData")
util.AddNetworkString("TTTBots_RequestData")
util.AddNetworkString("TTTBots_SyncAvatarNumbers")
util.AddNetworkString("TTTBots_RequestConCommand")
util.AddNetworkString("TTTBots_RequestCvarUpdate")
util.AddNetworkString("TTTBots_SpectateModeChanged")
util.AddNetworkString("TTTBots_QuerySpectateMode")

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end
local alreadyAddedResources = false

---Load all of the mod's depdenencies and initialize the mod
function TTTBots.Reload()
    includeServer()

    -- Shorthands
    local Lib = TTTBots.Lib
    local PathManager = TTTBots.PathManager

    TTTBots.Spots.CacheAllSpots() -- Cache all navmesh spots (cover, exposed, sniper spots, etc.)
    TTTBots.Lib.GetNavRegions()   -- Caches all nav regions

    -- Bot behavior
    timer.Create("TTTBots_Tick", 1 / TTTBots.Tickrate, 0, function()
        local call, err = pcall(function()
            -- _testBotAttack()
            TTTBots.Match.Tick()
            TTTBots.Behaviors.RunTreeOnBots()
            TTTBots.PlanCoordinator.Tick()
            local bots = TTTBots.Bots
            for i, bot in pairs(bots) do
                -- TTTBots.DebugServer.RenderDebugFor(bot, { "all" })
                if not (IsValid(bot) and bot and bot.components) then continue end -- Sometimes a weird bug or edge case occurs, just ignore it

                for i, component in pairs(bot.components) do
                    if component.Think == nil then
                        print("No think")
                        continue
                    end
                    component:Think()
                end

                bot.tick = bot:BotLocomotor().tick
                bot.timeInGame = (bot.timeInGame or 0) + (1 / TTTBots.Tickrate)
            end
            TTTBots.Lib.UpdateBotModels()
        end, function(err)
            print("ERROR:", err)
        end)
        if err then
            ErrorNoHaltWithStack(err)
        end
    end)

    -- GM:StartCommand
    hook.Add("StartCommand", "TTTBots_StartCommand", function(ply, cmd)
        if ply:IsBot() then
            local bot = ply
            local locomotor = bot:BotLocomotor()

            -- Update locomotor
            locomotor:StartCommand(cmd)
        end
    end)

    -- Function to notify players (when bots are masked from the scoreboard) that there are bots in the server.
    -- This is for ethical purposes and to prevent the mod breaching the Steam Workshop/Garry's Mod guidelines.
    -- The bot masking features should ONLY ever be used on a private server with consenting players, and this is why this notification exists.
    hook.Add("TTTBeginRound", "TTTBots_EthicalNotify", function()
        if table.IsEmpty(TTTBots.Bots) then return end
        local msg = TTTBots.Locale.GetLocalizedString("bot.notice", #TTTBots.Bots)
        local notifyAnyway = Lib.GetConVarBool("notify_always")

        -- If any of these 3 are FALSE, then it is obvious who is a bot, so we don't need to notify.
        local humanlikePfps = (not Lib.GetConVarBool("pfps")) or
            Lib.GetConVarBool("pfps_humanlike")                    -- If pfps are disabled or they are humanlike
        local emulatePing = Lib.GetConVarBool("emulate_ping")      -- If ping is emulated (instead of reading "BOT")
        local noPrefixes = not Lib.GetConVarBool("names_prefixes") -- If their usernames aren't prefixed by [BOT]

        if notifyAnyway or (humanlikePfps and emulatePing and noPrefixes) then
            TTTBots.Chat.BroadcastInChat(msg)
            print(msg)
        end
    end)

    -- Send avatars to clients
    if alreadyAddedResources then return end
    alreadyAddedResources = true

    local f = string.format

    for i = 0, 5 do
        resource.AddFile(f("materials/avatars/%d.png", i))
    end

    for i = 0, 87 do
        resource.AddFile(f("materials/avatars/humanlike/%d.jpg", i))
    end
end

local initChecks = {}

local function addInitCheck(data)
    initChecks[data.name] = data
    initChecks[data.name].notifiedPlayers = {}
    initChecks[data.name].dontChat = data.dontChat or false
end

addInitCheck({
    name = "hasNavmesh",
    callback = hasNavmesh,
    adminsOnly = true,
    msg = TTTBots.Locale.GetLocalizedString("no.navmesh")
})

local function chatCheck(check)
    local msg = check.msg
    for i, v in pairs(player.GetHumans()) do
        if (check.adminsOnly and not v:IsSuperAdmin()) then continue end
        if check.notifiedPlayers[v] then continue end
        if not check.dontChat then
            v:ChatPrint("TTT Bots: " .. msg)
        else
            print("TTT Bots: " .. check.msg)
        end
        check.notifiedPlayers[v] = true
    end
end

-- Initialization
local function initializeIfChecksPassed()
    for i, check in pairs(initChecks) do
        local passed = check.callback()
        if (not passed) then
            chatCheck(check)
            timer.Simple(1, initializeIfChecksPassed)
            return
        end
    end

    print("[TTT Bots 2] Initializing TTT Bots...")
    TTTBots.Reload()
    hook.Run("TTTBotsInitialized", TTTBots)
end

initializeIfChecksPassed()
