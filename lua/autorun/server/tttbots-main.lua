util.AddNetworkString("TTTBots_DrawData")
util.AddNetworkString("TTTBots_ClientData")
util.AddNetworkString("TTTBots_RequestData")
util.AddNetworkString("TTTBots_SyncAvatarNumbers")

AddCSLuaFile("tttbots2/client/debugui.lua")
AddCSLuaFile("tttbots2/client/scoreboardoverride.lua")
AddCSLuaFile("tttbots2/client/debug3d.lua")

-- Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
    Tickrate = 5, -- per second
    Lib = {}
}

include("tttbots2/commands/concommands.lua")
include("tttbots2/commands/cvars.lua")
include("tttbots2/lib/languages.lua")

-- Pre-check before initializing

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
local gamemodeCompatible = function()
    local compatible = { ["terrortown"] = true }
    return compatible[engine.ActiveGamemode()] or false
end

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end
local alreadyAddedResources = false

---Load all of the mod's depdenencies and initialize the mod
function TTTBots.Reload()
    include("tttbots2/lib/botlib.lua")
    include("tttbots2/lib/spots.lua")
    -- Initialize all of our other libraries
    include("tttbots2/lib/pathmanager.lua")
    include("tttbots2/lib/debugserver.lua")
    include("tttbots2/lib/miscnetwork.lua")
    include("tttbots2/lib/popularnavs.lua")
    include("tttbots2/lib/match.lua")
    include("tttbots2/lib/PlanCoordinator.lua")
    include("tttbots2/commands/chatcommands.lua")

    -- Initialize behaviors
    include("tttbots2/behaviors/tree.lua")

    -- Future modules:
    -- Bot speech manager, for playing voice lines and chatting in-game when something happens
    -- (will figure out more later)

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
            TTTBots.Behaviors.Tree()
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

                bot.tick = bot.components.locomotor.tick
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
            local locomotor = bot.components.locomotor

            -- Update locomotor
            locomotor:StartCommand(cmd)
        end
    end)

    -- Function to notify players (when bots are masked from the scoreboard) that there are bots in the server.
    -- This is for ethical purposes and to prevent the mod breaching the Steam Workshop/Garry's Mod guidelines.
    -- The bot masking features should ONLY ever be used on a private server with consenting players, and this is why this notification exists.
    hook.Add("TTTBeginRound", "TTTBots_EthicalNotify", function()
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
    name = "gamemodeCompatible",
    callback = gamemodeCompatible,
    adminsOnly = true,
    msg = TTTBots.Locale.GetLocalizedString("gamemode.not.compatible"),
    dontChat = true,
})

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

    print("Initializing TTT Bots...")
    TTTBots.Reload()
end

initializeIfChecksPassed()
