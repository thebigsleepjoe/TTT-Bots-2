util.AddNetworkString("TTTBots_DrawData")
util.AddNetworkString("TTTBots_ClientData")
util.AddNetworkString("TTTBots_RequestData")
util.AddNetworkString("TTTBots_SyncAvatarNumbers")

-- Declare TTTBots table
TTTBots = {
    Version = "2.0.0",
    Tickrate = 5, -- per second
    Lib = {}
}

include("includes/commands/concommands.lua")
include("includes/commands/cvars.lua")
include("includes/lib/languages.lua")

-- Pre-check before initializing

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
local gamemodeCompatible = function()
    local compatible = { ["terrortown"] = true }
    return compatible[engine.ActiveGamemode()] or false
end

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end

---Load all of the mod's depdenencies and initialize the mod
function TTTBots.Reload()
    include("includes/lib/botlib.lua")
    include("includes/lib/spots.lua")
    -- Initialize all of our other libraries
    include("includes/lib/pathmanager.lua")
    include("includes/lib/debugserver.lua")
    include("includes/lib/miscnetwork.lua")
    include("includes/lib/popularnavs.lua")
    include("includes/lib/match.lua")
    include("includes/lib/PlanCoordinator.lua")
    include("includes/commands/chatcommands.lua")

    -- Initialize behaviors
    include("includes/behaviors/tree.lua")

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
end

local initChecks = {}

local function addInitCheck(data)
    initChecks[data.name] = data
    initChecks[data.name].notifiedPlayers = {}
end

addInitCheck({
    name = "gamemodeCompatible",
    callback = gamemodeCompatible,
    adminsOnly = true,
    msg = TTTBots.Locale.GetLocalizedString("gamemode.not.compatible")
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
        v:ChatPrint("TTT Bots: " .. msg)
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
