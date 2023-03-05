TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.ObstacleTracker = {}

local lib = TTTBots.Lib
local BehaviorBase = TTTBots.Components.ObstacleTracker

function BehaviorBase:New(bot)
    local newObstacleTracker = {}
    setmetatable(newObstacleTracker, {
        __index = function(t, k) return BehaviorBase[k] end,
    })
    newObstacleTracker:Initialize(bot)

    local dbg = lib.GetDebugFor("all")
    if dbg then
        print("Initialized ObstacleTracker for bot " .. bot:Nick())
    end

    return newObstacleTracker
end

function BehaviorBase:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.ObstacleTracker = self

    self.componentID = string.format("ObstacleTracker (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0 -- Tick counter
    self.bot = bot
    self.disabled = false
end
