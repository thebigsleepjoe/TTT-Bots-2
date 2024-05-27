--- This file is unused in the actual code and is a meta file, AKA used for intellisense and quick prototyping.
--- You can read it and copy it to create your own components.
---@meta

---@class Component
TTTBots.Components.Base = TTTBots.Components.Base or {}

local lib = TTTBots.Lib
---@class Component
local Component = TTTBots.Components.Base

---@param bot Bot
---@return Component
function Component:New(bot)
    local newBase = {}
    setmetatable(newBase, {
        __index = function(t, k) return Component[k] end,
    })
    newBase:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Base for bot " .. bot:Nick())
    end

    return newBase
end

--- Called once at instantiation.
---@param bot Bot
function Component:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.Base = self
    self.componentID = string.format("Base (%s)", lib.GenerateID()) -- Component ID, used for debugging
    self.bot = bot
end

--- Called every tick.
function Component:Think()
end
