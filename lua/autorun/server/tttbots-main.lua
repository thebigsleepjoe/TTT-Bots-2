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

-- Force download of bot avatars

if engine.ActiveGamemode() ~= "terrortown" then return end

local f = string.format

for i = 0, 5 do
    resource.AddFile(f("materials/avatars/%d.png", i))
end

for i = 0, 87 do
    resource.AddFile(f("materials/avatars/humanlike/%d.jpg", i))
end
