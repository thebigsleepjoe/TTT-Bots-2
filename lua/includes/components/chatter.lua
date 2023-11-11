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
    self.rateLimitTbl = {}
end

--- Check the rate limit table for if we can say the line. If so, then return true and update the rate limit tbl.
---@param event string
---@return boolean
function BotChatter:CanSayEvent(event)
    local rateLimitTime = lib.GetConVarFloat("chatter_minrepeat")
    local lastSpeak = self.rateLimitTbl[event] or -math.huge

    if lastSpeak + rateLimitTime < CurTime() then
        self.rateLimitTbl[event] = CurTime()
        return true
    end

    return false
end

function BotChatter:SayRaw(text, teamOnly)
    self.bot:Say(text, teamOnly)
end

--- Order the bot to say a string of text in chat. This function is rate limited and types messages out at a somewhat random speed.
---@param text string The raw string of text to put in chat.
---@param teamOnly boolean|nil (OPTIONAL, =FALSE) Should the bot place the message in the team chat?
---@param ignoreDeath boolean|nil (OPTIONAL, =FALSE) Should the bot say the text despite being dead?
---@param callback nil|function (OPTIONAL) A callback function to call when the bot is done speaking.
---@return boolean chatting Returns true if we just ordered the bot to speak, otherwise returns false.
function BotChatter:Say(text, teamOnly, ignoreDeath, callback)
    if self.typing then return false end
    local cps = lib.GetConVarFloat("chatter_cps")
    local delay = (string.len(text) / cps) * (math.random(75, 150) / 100)
    self.typing = true
    -- remove "[BOT] " occurences from the text
    text = string.gsub(text, "%[BOT%] ", "")
    timer.Simple(delay, function()
        if self.bot and (ignoreDeath or lib.IsPlayerAlive(self.bot)) then
            self:SayRaw(text, teamOnly)
            self.typing = false
            if callback then callback() end
        end
    end)
    return true
end

local RADIO = {
    quick_traitor = "%s is a Traitor!",
    quick_suspect = "%s acts suspicious."
}
function BotChatter:QuickRadio(msgName, msgTarget)
    local txt = RADIO[msgName]
    if not txt then ErrorNoHaltWithStack("Unknown message type " .. msgName) end
    hook.Run("TTTPlayerRadioCommand", self.bot, msgName, msgTarget)
end

--- A generic wrapper for when an event happens, to be implemented further in the future
---@param event_name string
---@param args table<any> A table of arguments passed to the event
function BotChatter:On(event_name, args, teamOnly)
    local dvlpr = lib.GetConVarBool("debug_misc")
    if dvlpr then
        print(string.format("Event %s called with %d args.", event_name, #args))
    end

    if not self:CanSayEvent(event_name) then return false end

    if event_name == "CallKOS" then
        local target = args.playerEnt
        if IsValid(target) then
            if (target.lastKOSTime or 0) + 5 > CurTime() then return false end
            target.lastKOSTime = CurTime()
        end
    end

    local difficulty = lib.GetConVarInt("difficulty")
    local kosChanceMult = lib.GetConVarFloat("chatter_koschance")

    --- Base chances to react to the events via chat
    local chancesOf100 = {
        InvestigateNoise = 15,
        InvestigateCorpse = 15,
        LifeCheck = 65,
        CallKOS = 15 * difficulty * kosChanceMult,
    }

    local personality = self.bot.components.personality --- @type CPersonality
    if chancesOf100[event_name] then
        local chance = chancesOf100[event_name]
        if math.random(0, 100) > (chance * personality:GetTraitMult("textchat")) then return false end
    end

    local localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
    if localizedString then
        self:Say(localizedString, teamOnly, false, function()
            if event_name == "CallKOS" then
                self:QuickRadio("quick_traitor", args.playerEnt)
            end
        end)
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


-- Define a hash table to hold our keywords and their corresponding events
local keywordEvents = {
    ["life check"] = "LifeCheck",
    ["who is alive"] = "LifeCheck",
    -- ["kos"] = "KOSCallout",
}

-- Helper function to handle the chat events
local function handleEvent(eventName)
    for i, v in pairs(TTTBots.Bots) do
        local chatter = lib.GetComp(v, "chatter")
        if not chatter then continue end
        chatter:On(eventName, {}, false)
    end
end

hook.Add("PlayerSay", "TTTBots.Chatter.PromptResponse", function(sender, text, teamChat)
    local text2 = string.lower(text) -- Convert text to lowercase for case-insensitive comparison

    for keyword, event in pairs(keywordEvents) do
        if string.find(text2, keyword) then
            print("~~~~~~~~~~~~~~~")
            print(string.format("Match [%s]! Triggered event (%s) with string: '%s'", keyword, event, text))
            print("~~~~~~~~~~~~~~~")
            handleEvent(event) -- Pass the full chat message to handleEvent
        end
    end
end)
