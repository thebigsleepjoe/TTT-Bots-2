--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
TTTBots = TTTBots or {}
TTTBots.Components.BotMemory = TTTBots.BotMemory or {}

local lib = TTTBots.Lib
local BotMemory = TTTBots.Components.BotMemory


function BotMemory:New(bot)
    local newMemory = {}
    setmetatable(newMemory, {
        __index = function(t, k) return BotMemory[k] end,
    })
    newMemory:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Memory for bot " .. bot:Nick())
    end

    return newMemory
end

function BotMemory:ResetMemory()
    self.playerPositions = {}
end

function BotMemory:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.memory = self

    self:ResetMemory()

    self.bot = bot
end

function BotMemory:UpdatePlayerPositions()

end

function BotMemory:Think()
    self:UpdatePlayerPositions()
end
