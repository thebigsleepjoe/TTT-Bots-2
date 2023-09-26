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

-- Pre-check before initializing

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
local gamemodeCompatible = function()
    local compatible = { ["terrortown"] = true }
    return compatible[engine.ActiveGamemode()] or false
end

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end

local function initializeMod()
    include("includes/lib/commonlib.lua")
    -- Initialize all of our other libraries
    include("includes/lib/pathmanager.lua")
    include("includes/lib/debugserver.lua")
    include("includes/lib/miscnetwork.lua")
    include("includes/lib/popularnavs.lua")
    include("includes/lib/gamestate.lua")
    include("includes/lib/PlanCoordinator.lua")

    -- Initialize command libraries
    include("includes/commands/chatcommands.lua")
    include("includes/commands/cvars.lua")

    -- Initialize behaviors
    include("includes/behaviors/tree.lua")

    -- Future modules:
    -- Bot speech manager, for playing voice lines and chatting in-game when something happens
    -- (will figure out more later)

    -- Shorthands
    local Lib = TTTBots.Lib
    local PathManager = TTTBots.PathManager

    Lib.CacheAllSpots() -- Cache all navmesh spots (cover, exposed, sniper spots, etc.)

    local debugSpots = true

    if debugSpots then
        local f = string.format
        print(f("On this map, there are:"))
        print(f("%d hiding/cover spots", #Lib.GetCoverSpots()))
        print(f("%d exposed spots", #Lib.GetExposedSpots()))
        print(f("%d sniper spots", #Lib.GetGoodSnipeSpots()))
        print(f("%d great sniper spots", #Lib.GetBestSnipeSpots()))
    end

    local function _testBotAttack()
        local alivePlayers = Lib.GetAlivePlayers()
        -- Go over each alive bot using lib.GetAliveBots() and set target to a random lib.GetAlivePlayers() player
        for i, bot in pairs(Lib.GetAliveBots()) do
            if bot.attackTarget then continue end
            local newTarget = table.Random(alivePlayers)
            if newTarget == bot then continue end
            bot.attackTarget = newTarget

            local f = string.format
            print(f("Bot %s is targeting %s", bot:Nick(), newTarget:Nick()))
        end
    end
    -- Bot behavior
    timer.Create("TTTBots_Tick", 1 / TTTBots.Tickrate, 0, function()
        local call, err = pcall(function()
            -- _testBotAttack()
            TTTBots.Match.Tick()
            TTTBots.Behaviors.Tree()
            TTTBots.PlanCoordinator.Tick()
            local bots = TTTBots.Bots
            print("ticking " .. #bots .. " bots")
            print("total players in game: " .. #player.GetAll())
            for i, bot in pairs(bots) do
                -- TTTBots.DebugServer.RenderDebugFor(bot, { "all" })

                for i, component in pairs(bot.components) do
                    if component.Think == nil then
                        print("No think")
                        continue
                    end
                    component:Think()
                end

                bot.tick = bot.components.locomotor.tick
                print("ticked bot on tick #" .. (bot.tick or 0))
                bot.timeInGame = (bot.timeInGame or 0) + (1 / TTTBots.Tickrate)
            end
        end, function(err)
            print("ERROR:", err)
        end)
        if err then
            ErrorNoHalt(err)
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
    msg = "This gamemode is not compatible with TTT Bots! Shutting up to prevent console spam."
})

addInitCheck({
    name = "hasNavmesh",
    callback = hasNavmesh,
    adminsOnly = true,
    msg = "This map does not have a navmesh! You cannot use bots without one!"
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
    initializeMod()
end

initializeIfChecksPassed()
