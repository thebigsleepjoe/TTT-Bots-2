include("includes/lib/chattertxt.lua")

---@class CChatter
TTTBots.Components.Chatter = TTTBots.Components.Chatter or {}

local lib = TTTBots.Lib
---@class CChatter
local BotChatter = TTTBots.Components.Chatter

function BotChatter:New(bot)
    local newChatter = {}
    setmetatable(newChatter, {
        __index = function(t, k) return BotChatter[k] end,
    })
    newChatter:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Chatter for bot " .. bot:Nick())
    end

    return newChatter
end

function BotChatter:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Chatter = self

    self.componentID = string.format("Chatter (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                      -- Tick counter
    self.bot = bot
end

function BotChatter:SayRaw(text, teamOnly)
    self.bot:Say(text, teamOnly)
end

function BotChatter:Say(text, teamOnly)
    local delay = (math.random(0, 100) / 100.0) * 2
    timer.Simple(delay, function()
        self:SayRaw(text, teamOnly)
    end)
end

local RADIO = {
    quick_traitor = "%s is a Traitor!",
    quick_suspect = "%s acts suspicious."
}
function BotChatter:QuickRadio(msgName, msgTarget)
    hook.Run("TTTPlayerRadioCommand", self.bot, msgName, msgTarget)
    local txt = RADIO[msgName]
    if not txt then ErrorNoHalt("Unknown message type " .. msgName) end
    self:SayRaw(string.format(txt, msgTarget:Nick()))
end

--- A generic wrapper for when an event happens, to be implemented further in the future
---@param event_name string
---@param args table<any> A table of arguments passed to the event
function BotChatter:On(event_name, args, teamOnly)
    local dvlpr = lib.GetConVarBool("debug_misc")
    if dvlpr then
        print(string.format("Event %s called with %d args.", event_name, #args))
    end

    --- Base chances to react to the events via chat
    local chancesOf100 = {
        InvestigateNoise = 15
    }

    local localizedString = TTTBots.LocalizedStrings.GetLocalizedLine(event_name, self.bot, args)
    if localizedString then
        if chancesOf100[event_name] then
            local chance = chancesOf100[event_name]
            if math.random(0, 100) > chance then return false end
        end
        self:Say(localizedString, teamOnly)
        return true
    end

    return false
end

function BotChatter:Think()
end

-- hook for GM:PlayerCanSeePlayersChat(text, taemOnly, listener, sender)
hook.Add("PlayerCanSeePlayersChat", "TTTBots_PlayerCanSeePlayersChat", function(text, teamOnly, listener, sender)
    if IsValid(sender) and sender:IsBot() and teamOnly then
        if lib.IsPlayerAlive(sender) then
            local isEvil = lib.IsEvil(sender)
            if not isEvil then
                sender:Say(text)
                return false
            end
            if listener:IsInTeam(sender) then
                return true
            end
        else
            return false
        end
    end
end)
