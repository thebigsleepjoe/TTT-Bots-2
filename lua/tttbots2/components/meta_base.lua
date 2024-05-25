--- This file is unused in the actual code and is a meta file, AKA used for intellisense and quick prototyping.
--- You can read it and copy it to create your own components.
---@meta

---@class CBase
TTTBots.Components.Base = TTTBots.Components.Base or {}

local lib = TTTBots.Lib
---@class CBase
local CBase = TTTBots.Components.Base

---@param bot Player
---@return CBase
function CBase:New(bot)
    local newBase = {}
    setmetatable(newBase, {
        __index = function(t, k) return CBase[k] end,
    })
    newBase:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Base for bot " .. bot:Nick())
    end

    return newBase
end

--- Called once at instantiation.
---@param bot Player
function CBase:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.Base = self
    self.componentID = string.format("Base (%s)", lib.GenerateID()) -- Component ID, used for debugging
    self.bot = bot
end

--- Called every tick.
function CBase:Think()
end
