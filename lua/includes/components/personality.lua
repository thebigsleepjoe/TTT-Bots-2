TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.Personality = TTTBots.Components.Personality or {}

local lib = TTTBots.Lib
local BotPersonality = TTTBots.Components.Personality

BotPersonality.Traits = {
    aggressive = {
        name = "aggressive",
        description =
        "[HE] often picks targets hastily, regardless of being right or wrong, and pays no mind to witnesses",
        conflicts = { "passive", "cautious" },
        traitor_only = false,
    },
    passive = {
        name = "passive",
        description = "When not a traitor, [HE] avoids fights and runs away instead",
        conflicts = { "aggressive", "rdmer" },
        traitor_only = false,
    },
    bomber = {
        name = "bomber",
        description = "Using C4 or a jihad bomb (if modded), [HE] enjoys blowing things up",
        conflicts = {},
        traitor_only = true,
    },
    suspicious = {
        name = "suspicious",
        description = "Players tend to mistrust [HIM] and are quick to assume [HE] is a traitor",
        conflicts = { "gullible" },
        traitor_only = false,
    },
    badaim = {
        name = "badaim",
        description = "Under pressure, [HE] struggles with aiming accuracy",
        conflicts = { "goodaim" },
        traitor_only = false,
    },
    goodaim = {
        name = "goodaim",
        description = "[HE] has better aim than the average player",
        conflicts = { "badaim" },
        traitor_only = false,
    },
    oblivious = {
        name = "oblivious",
        description = "Occasionally, [HE] overlooks bodies and traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
    },
    veryoblivious = {
        name = "veryoblivious",
        description = "Unless a detective, [HE] seldom searches bodies or notices traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
    },
    observant = {
        name = "observant",
        description = "Spotting bodies and traitor weapons comes easily to [HIM]",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
    },
    veryobservant = {
        name = "veryobservant",
        description = "[HE] instantly detects bodies and traitor weapons in the vicinity",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
    },
    loner = {
        name = "loner",
        description = "[HE] prefers to steer clear of crowds",
        conflicts = { "lovescrowds", "teamplayer" },
        traitor_only = false,
    },
    lovescrowds = {
        name = "lovescrowds",
        description = "Crowded spaces attract [HIM]",
        conflicts = { "loner" },
        traitor_only = false,
    },
    teamplayer = {
        name = "teamplayer",
        description = "Helping teammates is a priority for [HIM]",
        conflicts = { "loner", "rdmer" },
        traitor_only = false,
    },
    rdmer = {
        name = "rdmer",
        description = "[HE] kills people at random",
        conflicts = { "passive", "teamplayer" },
        traitor_only = false,
    },
    victim = {
        name = "victim",
        description = "Other bots are more likely to target [HIM]",
        conflicts = {},
        traitor_only = false,
    },
    sniper = {
        name = "sniper",
        description = "Adept with a sniper rifle, [HE] aims to eliminate others from afar",
        conflicts = { "meleer" },
        traitor_only = false,
    },
    meleer = {
        name = "meleer",
        description = "At close range, [HE] wields a crowbar to kill",
        conflicts = { "sniper" },
        traitor_only = false,
    },
    assassin = {
        name = "assassin",
        description = "Armed with a knife, [HE] seeks to eliminate others",
        conflicts = {},
        traitor_only = false,
    },
    bodyburner = {
        name = "bodyburner",
        description = "Burning bodies is one of [HIS] tactics",
        conflicts = {},
        traitor_only = false,
    },
    bodyguard = {
        name = "bodyguard",
        description = "[HE] selects a random player to protect",
        conflicts = { "loner" },
        traitor_only = false,
    },
    camper = {
        name = "camper",
        description = "As an innocent, [HE] chooses an area to hunker down in",
        conflicts = { "risktaker" },
        traitor_only = false,
    },
    talkative = {
        name = "talkative",
        description = "[HE] communicates more frequently",
        conflicts = { "silent" },
        traitor_only = false,
    },
    silent = {
        name = "silent",
        description = "[HE] keeps communication to a minimum",
        conflicts = { "talkative" },
        traitor_only = false,
    },
    risktaker = {
        name = "risktaker",
        description = "[HE] ventures into dangerous areas for the thrill",
        conflicts = { "cautious", "camper" },
        traitor_only = false,
    },
    cautious = {
        name = "cautious",
        description = "[HE] steers clear of danger when possible",
        conflicts = { "risktaker" },
        traitor_only = false,
    },
    gullible = {
        name = "gullible",
        description = "[HE] tends to believe others easily",
        conflicts = { "suspicious" },
        traitor_only = false,
    },
    doesntcare = {
        name = "doesntcare",
        description = "Apathetic, [HE] can be unresponsive at times",
        conflicts = { "talkative", "teamplayer" },
        traitor_only = false,
    },
    disguiser = {
        name = "disguiser",
        description = "As a traitor, [HE] loves [HIS] disguiser",
        conflicts = {},
        traitor_only = true,
    },
    radiohead = {
        name = "radiohead",
        description = "As a traitor, [HE] loves [HIS] radio",
        conflicts = {},
        traitor_only = true,
    },
}

function BotPersonality:New(bot)
    local newPersonality = {}
    setmetatable(newPersonality, {
        __index = function(t, k) return BotPersonality[k] end,
    })
    newPersonality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Personality for bot " .. bot:Nick())
    end

    return newPersonality
end

function BotPersonality:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.personality = self

    self.componentID = string.format("Personality (%s)", lib.GenerateID()) -- Component ID, used for debugging
    self.gender = (math.random(1, 100) < 50 and "male") or "female"
    self.HIM = (self.gender == "male" and "him") or "her"
    self.HIS = (self.gender == "male" and "his") or "hers"
    self.HE = (self.gender == "male" and "he") or "her"

    self.traits = self:GetSomeTraits(4)

    self.bot = bot
end

--- flavors text based on gender pronouns (self.HIM, .HIS, .HE)
function BotPersonality:FlavorText(text)
    local str, _int = string.gsub(text, "%[HIM%]", self.HIM):gsub("%[HIS%]", self.HIS):gsub("%[HE%]", self.HE)
    return str
end

function BotPersonality:GetTraits()
    return self.traits
end

function BotPersonality:GetFlavoredTraits()
    local traits = {}
    for i, trait in ipairs(self.traits) do
        print(self:FlavorText(self.Traits[trait].description))
        table.insert(traits, self:FlavorText(self.Traits[trait].description))
    end
    return traits
end

function BotPersonality:PrintFlavoredTraits()
    for _, trait in ipairs(self:GetFlavoredTraits()) do
        print(trait)
    end
end

function BotPersonality:Think()
    -- No need to think, this is a passive component
end

function BotPersonality:GetRandomTrait()
    local keys = {}
    for k, _ in pairs(self.Traits) do
        table.insert(keys, k)
    end
    return keys[math.random(#keys)]
end

function BotPersonality:TraitHasConflict(trait, selectedTraits)
    for _, selectedTrait in ipairs(selectedTraits) do
        for _, conflict in ipairs(self.Traits[selectedTrait].conflicts) do
            if conflict == trait then
                return true
            end
        end
    end
    return false
end

function BotPersonality:GetSomeTraits(num)
    local selectedTraits = {}
    local traitorTraits = 0

    while #selectedTraits < num do
        local tryCount = 0
        local trait = self:GetRandomTrait()

        while (self:TraitHasConflict(trait, selectedTraits) or table.HasValue(selectedTraits, trait)) and tryCount < 10 do
            trait = self:GetRandomTrait()
            tryCount = tryCount + 1
        end

        if tryCount < 10 then
            if self.Traits[trait].traitor_only then
                if traitorTraits < 1 then
                    table.insert(selectedTraits, trait)
                    traitorTraits = traitorTraits + 1
                end
            else
                table.insert(selectedTraits, trait)
            end
        else
            break
        end
    end

    return selectedTraits
end

local plyMeta = FindMetaTable("Player")

function plyMeta:GetPersonalityTraits()
    if self.components and self.components.personality then
        return self.components.personality:GetTraits()
    end
end

function plyMeta:PersonalityHas(trait_name)
    if self.components and self.components.personality then
        local traits = self.components.personality:GetTraits()
        for _, trait in ipairs(traits) do
            if trait == trait_name then
                return true
            end
        end
    end
    return false
end
