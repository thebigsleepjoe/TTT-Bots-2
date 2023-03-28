TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.InventoryMgr = TTTBots.Components.InventoryMgr or {}

local lib = TTTBots.Lib
local BotInventoryMgr = TTTBots.Components.InventoryMgr

function BotInventoryMgr:New(bot)
    local newInventoryMgr = {}
    setmetatable(newInventoryMgr, {
        __index = function(t, k) return BotInventoryMgr[k] end,
    })
    newInventoryMgr:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized InventoryMgr for bot " .. bot:Nick())
    end

    return newInventoryMgr
end

function BotInventoryMgr:Initialize(bot)
    print("Initializing")
    bot.components = bot.components or {}
    bot.components.InventoryMgr = self

    self.componentID = string.format("inventorymgr (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.bot = bot
end

function BotInventoryMgr:Think()
    print("Thinking")
end
