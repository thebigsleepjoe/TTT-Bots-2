TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.ObstacleTracker = TTTBots.Components.ObstacleTracker or {}

local lib = TTTBots.Lib
local BotObstacleTracker = TTTBots.Components.ObstacleTracker

function BotObstacleTracker:New(bot)
    local newObstacleTracker = {}
    setmetatable(newObstacleTracker, {
        __index = function(t, k) return BotObstacleTracker[k] end,
    })
    newObstacleTracker:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized ObstacleTracker for bot " .. bot:Nick())
    end

    return newObstacleTracker
end

function BotObstacleTracker:Initialize(bot)
    print("Initializing")
    bot.components = bot.components or {}
    bot.components.obstacletracker = self

    self.componentID = string.format("obstacletracker (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                              -- Tick counter
    self.bot = bot
    self.disabled = false

    print(self.Think)
end

function BotObstacleTracker:Disable()
    self.disabled = true
end

function BotObstacleTracker:Enable()
    self.disabled = false
end

function BotObstacleTracker:GetBlockingBreakable()
    local normal = self.bot.components.locomotor.moveNormal
    if not normal then
        return
    end

    local start = self.bot:GetPos() + Vector(0, 0, 16)
    local endpos = (self.bot:GetPos() + Vector(0, 0, 16)) + normal * 50
    local trace = util.TraceLine({
        start = start,
        endpos = endpos,
        filter = self.bot
    })

    if trace.Hit and trace.Entity then
        -- check if trace.Entity is in the BotObstacleTracker.Breakables table
        return table.HasValue(BotObstacleTracker.Breakables, trace.Entity) and trace.Entity or nil
    end
end

--- Gets the nearby obstacles to the bot (breakable and unbreakable)
---@param radius number The radius to search in, can be nil (default is 100)
function BotObstacleTracker:GetNearbyObstacles(radius)
    local nearby = {}
    local pos = self.bot:GetPos()
    radius = radius or 100

    local all = {}
    table.Add(all, BotObstacleTracker.Breakables)
    table.Add(all, BotObstacleTracker.Unbreakables)

    for _, obstacle in pairs(all) do
        if not IsValid(obstacle) then continue end
        local vec = obstacle:GetPos()
        if vec:Distance(pos) < radius then
            table.insert(nearby, obstacle)
        end
    end

    return nearby
end

function BotObstacleTracker:Think()
    if self.disabled then return end
    self.tick = self.tick + 1

    if self.tick % 3 == 0 then
        self.blocking = self:GetBlockingBreakable()
    end
end

function BotObstacleTracker:IsPathBlocked()
    return (self.blocking ~= nil) and IsValid(self.blocking)
end

function BotObstacleTracker:GetBlocking()
    return self.blocking
end

----------------------------------------
-- STATIC METHODS / FIELDS
----------------------------------------

BotObstacleTracker.Breakables = BotObstacleTracker.Breakables or {}
BotObstacleTracker.Unbreakables = BotObstacleTracker.Unbreakables or {}

timer.Create("TTTBots.Components.ObstacleTracker_Breakables", 1.5, 0, function()
    local db_break = {}
    local db_unbreak = {}

    local dbg = lib.GetConVarBool("debug_obstacles")

    -- for i, v in pairs(ents.GetAll()) do
    --     print(v:GetClass())
    -- end

    for _, entity in pairs(ents.FindByClass("func_breakable")) do
        table.insert(db_break, entity)
    end

    for _, entity in pairs(ents.FindByClass("func_breakable_surf")) do
        table.insert(db_break, entity)
    end

    local phys = {}
    table.Add(phys, ents.FindByClass("prop_physics"))
    table.Add(phys, ents.FindByClass("prop_physics_multiplayer"))
    table.Add(phys, ents.FindByClass("func_physbox"))

    for _, entity in pairs(phys) do
        local vals = entity:GetKeyValues()
        if vals.health and vals.health > 1 then
            table.insert(db_break, entity)
        else
            table.insert(db_unbreak, entity)
        end
    end

    if dbg then
        print(#db_break .. " breakables, " .. #db_unbreak .. " unbreakables.")
    end

    BotObstacleTracker.Breakables = db_break
    BotObstacleTracker.Unbreakables = db_unbreak
end)

timer.Create("TTTBots.Components.ObstacleTracker_Breakables_draw", 0.1, 0, function()
    if not lib.GetConVarBool("debug_obstacles") then return end

    for i, breakable in pairs(BotObstacleTracker.Breakables) do
        if not IsValid(breakable) then continue end
        local vec = breakable:GetPos()
        local minVec, maxVec = breakable:OBBMins(), breakable:OBBMaxs()
        TTTBots.DebugServer.DrawBox(vec, minVec, maxVec, Color(255, 0, 0, 0))
    end

    for i, unbreakable in pairs(BotObstacleTracker.Unbreakables) do
        if not IsValid(unbreakable) then continue end
        local vec = unbreakable:GetPos()

        local minVec, maxVec = unbreakable:OBBMins(), unbreakable:OBBMaxs()
        TTTBots.DebugServer.DrawBox(vec, minVec, maxVec, Color(0, 255, 0, 0))
    end
end)
