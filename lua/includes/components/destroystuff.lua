TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.DestroyStuff = {}

local lib = TTTBots.Lib
local BotDestroyStuff = TTTBots.Components.DestroyStuff

function BotDestroyStuff:New(bot)
    local newDestroyStuff = {}
    setmetatable(newDestroyStuff, {
        __index = function(t, k) return BotDestroyStuff[k] end,
    })
    newDestroyStuff:Initialize(bot)

    local dbg = lib.GetDebugFor("all")
    if dbg then
        print("Initialized DestroyStuff for bot " .. bot:Nick())
    end

    return newDestroyStuff
end

function BotDestroyStuff:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.DestroyStuff = self

    self.componentID = string.format("DestroyStuff (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0 -- Tick counter
    self.bot = bot
    self.disabled = false
end

function BotDestroyStuff:Disable()
    self.disabled = true
end

function BotDestroyStuff:Enable()
    self.disabled = false
end

function BotDestroyStuff:Think()
    if self.disabled then return end
    self.tick = self.tick + 1

    print("BotDestroyStuff:Think()")
end

BotDestroyStuff.Breakables = BotDestroyStuff.Breakables or {}
BotDestroyStuff.Unbreakables = BotDestroyStuff.Unbreakables or {}

timer.Create("TTTBots.Components.DestroyStuff_Breakables", 1.5, 0, function()
    local db_break = {}
    local db_unbreak = {}

    local dbg = lib.GetConVarBool("debug_obstacles")

    for _, entity in pairs(ents.FindByClass("func_breakable")) do
        table.insert(db_break, entity)
        if dbg then print("Registered a breakable brush: " .. entity:GetClass()) end
    end

    for _, entity in pairs(ents.FindByClass("func_breakable_surf")) do
        table.insert(db_break, entity)
        if dbg then print("Registered a breakable brush: " .. entity:GetClass()) end
    end

    for _, entity in pairs(ents.FindByClass("prop_physics")) do
        local vals = entity:GetKeyValues()
        if vals.health and vals.health > 1 then
            table.insert(db_break, entity)
        else
            table.insert(db_unbreak, entity)
        end
    end

    print(#db_break .. " breakables, " .. #db_unbreak .. " unbreakables.")

    BotDestroyStuff.Breakables = db_break
    BotDestroyStuff.Unbreakables = db_unbreak
end)

timer.Create("TTTBots.Components.DestroyStuff_Breakables_draw", 0.1, 0, function()
    if not lib.GetConVarBool("debug_obstacles") then return end

    for i, breakable in pairs(BotDestroyStuff.Breakables) do
        local vec = breakable:GetPos()
        local minVec, maxVec = breakable:OBBMins(), breakable:OBBMaxs()
        TTTBots.DebugServer.DrawBox(vec, minVec, maxVec, Color(255, 0, 0, 0))
    end

    for i, unbreakable in pairs(BotDestroyStuff.Unbreakables) do
        local vec = unbreakable:GetPos()

        local minVec, maxVec = unbreakable:OBBMins(), unbreakable:OBBMaxs()
        TTTBots.DebugServer.DrawBox(vec, minVec, maxVec, Color(0, 255, 0, 0))
    end
end)
