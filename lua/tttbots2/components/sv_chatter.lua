---@class CChatter : CBase
TTTBots.Components.Chatter = TTTBots.Components.Chatter or {}

local lib = TTTBots.Lib
---@class CChatter : CBase
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
    if not IsValid(self.bot) then return end
    self.bot:Say(text, teamOnly)
end

local keyboardLayout = {
    ['q'] = { 'w', 'a' },
    ['w'] = { 'q', 'e', 's', 'a' },
    ['e'] = { 'w', 'r', 'd', 's' },
    ['r'] = { 'e', 't', 'f', 'd' },
    ['t'] = { 'r', 'y', 'g', 'f' },
    ['y'] = { 't', 'u', 'h', 'g' },
    ['u'] = { 'y', 'i', 'j', 'h' },
    ['i'] = { 'u', 'o', 'k', 'j' },
    ['o'] = { 'i', 'p', 'l', 'k' },
    ['p'] = { 'o', 'l' },
    ['a'] = { 'q', 'w', 's', 'z' },
    ['s'] = { 'w', 'e', 'd', 'a', 'z', 'x' },
    ['d'] = { 'e', 'r', 'f', 's', 'x', 'c' },
    ['f'] = { 'r', 't', 'g', 'd', 'c', 'v' },
    ['g'] = { 't', 'y', 'h', 'f', 'v', 'b' },
    ['h'] = { 'y', 'u', 'j', 'g', 'b', 'n' },
    ['j'] = { 'u', 'i', 'k', 'h', 'n', 'm' },
    ['k'] = { 'i', 'o', 'l', 'j', 'm' },
    ['l'] = { 'o', 'p', 'k' },
    ['z'] = { 'a', 's', 'x' },
    ['x'] = { 'z', 's', 'd', 'c' },
    ['c'] = { 'x', 'd', 'f', 'v' },
    ['v'] = { 'c', 'f', 'g', 'b' },
    ['b'] = { 'v', 'g', 'h', 'n' },
    ['n'] = { 'b', 'h', 'j', 'm' },
    ['m'] = { 'n', 'j', 'k' },
}

local missKey = function(last, this, next)
    local typoOptions = keyboardLayout[this]
    if typoOptions then
        return typoOptions[math.random(#typoOptions)]
    else
        return this
    end
end

--- Intentionally inject typos into the text based on the chatter_typo_chance convars
---@param text string
---@return string result
function BotChatter:TypoText(text)
    local chance = lib.GetConVarFloat("chatter_typo_chance")

    local typoFuncs = {
        removeCharacter = function(last, this, next) return "" end,
        duplicateCharacter = function(last, this, next) return this .. this end,
        capitalizeCharacter = function(last, this, next) return string.upper(this) end,
        lowercaseCharacter = function(last, this, next) return string.lower(this) end,
        switchWithNext = function(last, this, next) return next .. this end,
        insertRandomCharacter = function(last, this, next) return this .. string.char(math.random(97, 122)) end,
        missKey = missKey
    }

    ---@type table<WeightedTable>
    local typoFuncsWeighted = {
        TTTBots.Lib.SetWeight(typoFuncs.removeCharacter, 20),
        TTTBots.Lib.SetWeight(typoFuncs.duplicateCharacter, 7),
        TTTBots.Lib.SetWeight(typoFuncs.capitalizeCharacter, 4),
        TTTBots.Lib.SetWeight(typoFuncs.lowercaseCharacter, 7),
        TTTBots.Lib.SetWeight(typoFuncs.switchWithNext, 12),
        TTTBots.Lib.SetWeight(typoFuncs.insertRandomCharacter, 14),
        TTTBots.Lib.SetWeight(typoFuncs.missKey, 30)
    }

    local result = ""
    local textLength = string.len(text)
    for i = 1, textLength do
        local char = string.sub(text, i, i)
        local last = i > 1 and string.sub(text, i - 1, i - 1) or ""
        local next = i < textLength and string.sub(text, i + 1, i + 1) or ""

        if math.random(0, 100) < chance then
            local typoFunc = lib.RandomWeighted(typoFuncsWeighted)
            char = typoFunc(last, char, next)
        end

        result = result .. char
    end

    return result
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
    text = self:TypoText(text)
    timer.Simple(delay, function()
        if self.bot == NULL or not IsValid(self.bot) then return end
        if ignoreDeath or lib.IsPlayerAlive(self.bot) then
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
        FollowStarted = 10,
        ServerConnected = 45,
        SillyChat = 30,
        SillyChatDead = 15,
    }

    local personality = self.bot.components.personality --- @type CPersonality
    if chancesOf100[event_name] then
        local chance = chancesOf100[event_name]
        if math.random(0, 100) > (chance * personality:GetTraitMult("textchat")) then return false end
    end

    local localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
    local isCasual = personality:GetClosestArchetype() == "casual"
    if localizedString then
        if isCasual then localizedString = string.lower(localizedString) end
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
    if not (IsValid(sender) and sender:IsBot() and teamOnly) then
        return
    end

    if not lib.IsPlayerAlive(sender) then
        return false
    end

    if listener:IsInTeam(sender) then
        return true
    end

    return false
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
            handleEvent(event) -- Pass the full chat message to handleEvent
        end
    end
end)

timer.Create("TTTBots.Chatter.SillyChat", 20, 0, function()
    if math.random(1, 9) > 1 then return end -- Should average to about once every 3 minutes
    local targetBot = TTTBots.Bots[math.random(1, #TTTBots.Bots)]
    if not targetBot then return end
    local chatter = lib.GetComp(targetBot, "chatter") ---@type CChatter
    if not chatter then return end

    local randomPlayer = TTTBots.Match.AlivePlayers[math.random(1, #TTTBots.Match.AlivePlayers)]
    if not randomPlayer or randomPlayer == targetBot then return end

    local eventName = lib.IsPlayerAlive(targetBot) and "SillyChat" or "SillyChatDead"
    chatter:On(eventName, { player = randomPlayer:Nick() })
end)

local plyMeta = FindMetaTable("Player")
function plyMeta:GetChatter()
    return lib.GetComp(self, "chatter")
end
