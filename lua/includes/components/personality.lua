---@class CPersonality
TTTBots.Components.Personality = TTTBots.Components.Personality or {}

local lib = TTTBots.Lib
---@class CPersonality
local BotPersonality = TTTBots.Components.Personality

BotPersonality.Traits = {
    --- Quick to attack (innocent) and ignores evaluation of danger when picking a target (traitor)
    aggressive = {
        name = "aggressive",
        description =
        "[HE] often picks targets hastily, regardless of being right or wrong, and pays no mind to witnesses",
        conflicts = { "passive", "cautious" },
        traitor_only = false,
    },
    --- When hearing shots, finds a safe spot to hide. NEVER seeks out gunshots.
    passive = {
        name = "passive",
        description = "When not a traitor, [HE] avoids fights and runs away instead",
        conflicts = { "aggressive", "rdmer" },
        traitor_only = false,
    },
    --- Places C4, doubles C4 hearing radius
    bomber = {
        name = "bomber",
        description = "Using C4 or a jihad bomb (if modded), [HE] enjoys blowing things up",
        conflicts = {},
        traitor_only = true,
    },
    --- Sus actions give self +50% suspicion
    suspicious = {
        name = "suspicious",
        description = "Players tend to mistrust [HIM] and are quick to assume [HE] is a traitor",
        conflicts = { "gullible" },
        traitor_only = false,
    },
    --- Aim tends to be terrible, especially when under pressure.
    badaim = {
        name = "badaim",
        description = "Under pressure, [HE] struggles with aiming accuracy",
        conflicts = { "goodaim" },
        traitor_only = false,
    },
    --- The simplest trait: has better aim than the average player, regardless of pressure
    goodaim = {
        name = "goodaim",
        description = "[HE] has better aim than the average player",
        conflicts = { "badaim" },
        traitor_only = false,
    },
    --- Not paying full attention; bad hearing, memory, and target acquisition.
    oblivious = {
        name = "oblivious",
        description = "Occasionally, [HE] overlooks bodies and traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
    },
    --- Significantly brain damaged. Not good at hearing, memory, or target acquisition.
    veryoblivious = {
        name = "veryoblivious",
        description = "Unless a detective, [HE] seldom searches bodies or notices traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
    },
    -- Good hearing, memory, and target acquisition than the average player.
    observant = {
        name = "observant",
        description = "Spotting bodies and traitor weapons comes easily to [HIM]",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
    },
    --- Significantly better hearing, memory, and is more likely to attack the right person.
    veryobservant = {
        name = "veryobservant",
        description = "[HE] instantly detects bodies and traitor weapons in the vicinity",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
    },
    --- Tends to wander to the least popular nav areas, but can still wander elsewhere
    loner = {
        name = "loner",
        description = "[HE] prefers to steer clear of crowds",
        conflicts = { "lovescrowds", "teamplayer" },
        traitor_only = false,
    },
    --- Tends to wander into popular nav areas, but can still wander elsewhere
    lovescrowds = {
        name = "lovescrowds",
        description = "Crowded spaces attract [HIM]",
        conflicts = { "loner" },
        traitor_only = false,
    },
    --- As traitor, follows his traitors around to coordinate attacks with them better.
    teamplayer = {
        name = "teamplayer",
        description = "Helping teammates is a priority for [HIM]",
        conflicts = { "loner", "rdmer" },
        traitor_only = true,
    },
    --- Attacks random person regardless of team. THIS SHOULD BE DISABLED BY DEFAULT!
    rdmer = {
        name = "rdmer",
        description = "[HE] kills people at random",
        conflicts = { "passive", "teamplayer" },
        traitor_only = false,
    },
    --- Makes traitors 3x as likely to attack him at random
    victim = {
        name = "victim",
        description = "Other bots are more likely to target [HIM]",
        conflicts = {},
        traitor_only = false,
    },
    --- Prefers to use long range single-shot guns, wanders between open nav spots
    sniper = {
        name = "sniper",
        description = "Adept with a sniper rifle, [HE] aims to eliminate others from afar",
        conflicts = { "meleer" },
        traitor_only = false,
    },
    --- Pulls out crowbar and kills people the old fashioned way. Modifies attack behavior
    meleer = {
        name = "meleer",
        description = "At close range, [HE] wields a crowbar to kill",
        conflicts = { "sniper" },
        traitor_only = false,
    },
    --- Uses the knife to kill when alone with someone
    assassin = {
        name = "assassin",
        description = "Armed with a knife, [HE] seeks to eliminate others",
        conflicts = {},
        traitor_only = false,
    },
    --- Uses the flare gun to burn corpses he leaves
    bodyburner = {
        name = "bodyburner",
        description = "Burning bodies is one of [HIS] tactics",
        conflicts = {},
        traitor_only = false,
    },
    --- Prefers wander around a randomly selected player, typically a detective.
    bodyguard = {
        name = "bodyguard",
        description = "[HE] selects a random player to protect",
        conflicts = { "loner" },
        traitor_only = false,
    },
    --- Instead of wandering randomly, hunkers in a random hidden spot
    camper = {
        name = "camper",
        description = "As an innocent, [HE] chooses an area to hunker down in",
        conflicts = { "risktaker" },
        traitor_only = false,
    },
    --- Uses chat more frequently, especially when traitor
    talkative = {
        name = "talkative",
        description = "[HE] communicates more frequently",
        conflicts = { "silent" },
        traitor_only = false,
    },
    --- Does not use any chat whatsoever
    silent = {
        name = "silent",
        description = "[HE] keeps communication to a minimum",
        conflicts = { "talkative" },
        traitor_only = false,
    },
    --- Roams into high-stress areas and walks towards gunshots for fun.
    risktaker = {
        name = "risktaker",
        description = "[HE] ventures into dangerous areas for the thrill",
        conflicts = { "cautious", "camper" },
        traitor_only = false,
    },
    --- Double suspicion gain, is more observant
    cautious = {
        name = "cautious",
        description = "[HE] steers clear of danger when possible",
        conflicts = { "risktaker" },
        traitor_only = false,
    },
    --- Suspicion system is disabled
    gullible = {
        name = "gullible",
        description = "[HE] tends to believe others easily",
        conflicts = { "suspicious" },
        traitor_only = false,
    },
    --- Doesn't pay attention to many noises, doesn't react quickly, much worse memory of events and people
    doesntcare = {
        name = "doesntcare",
        description = "Apathetic, [HE] can be unresponsive at times",
        conflicts = { "talkative", "teamplayer", "cautious" },
        traitor_only = false,
    },
    --- Can use the disguiser
    disguiser = {
        name = "disguiser",
        description = "As a traitor, [HE] loves [HIS] disguiser",
        conflicts = {},
        traitor_only = true,
    },
    --- Can play sounds on radio
    radiohead = {
        name = "radiohead",
        description = "As a traitor, [HE] loves [HIS] radio",
        conflicts = { "deaf" },
        traitor_only = true,
    },
    --- Cannot hear sounds
    deaf = {
        name = "deaf",
        description = "[HE] cannot hear",
        conflicts = { "radiohead", "lowvolume", "highvolume" },
        traitor_only = false,
    },
    --- Worse sound detection range
    lowvolume = {
        name = "lowvolume",
        description = "[HE] cannot hear too well or has [HIS] volume lowered",
        conflicts = { "deaf", "highvolume" },
        traitor_only = false,
    },
    --- Better sound detection range
    highvolume = {
        name = "highvolume",
        description = "[HE] can hear very well or has [HIS] volume raised",
        conflicts = { "deaf", "lowvolume" },
        traitor_only = false,
    },
    --- Double rage rate
    rager = {
        name = "rager",
        description = "[HE] gets angry easily",
        conflicts = { "pacifist" },
        traitor_only = false,
    },
    --- Half rage rate
    pacifist = {
        name = "pacifist",
        description = "[HE] is a pacifist",
        conflicts = { "rager" },
        traitor_only = false,
    },
    --- Doesn't feel pressure when aiming
    steady = {
        name = "steady",
        description = "[HE] is steady when aiming",
        conflicts = { "shaky" },
        traitor_only = false,
    },
    --- Feels 3x pressure when aiming
    shaky = {
        name = "shaky",
        description = "[HE] is shaky when aiming",
        conflicts = { "steady" },
        traitor_only = false,
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

    ---@deprecated not implemented yet
    self.preferSwitchToSecondary = math.random(1, 100) < 50 -- prefer to switch to secondary weapon instead of reloading
    ---@deprecated not implemented yet
    self.preferOnlySecondary = math.random(1, 100) < 10     -- Prefer ONLY using secondary unless no secondary or no ammo

    self.traits = self:GetSomeTraits(4)

    --- How angry the bot is, from 1-100. Adds onto pressure. At 100% rage, the bot will leave and be replaced.
    self.rage = 0
    --- How pressured the bot is feeling (effects aim) from 1-100.
    self.pressure = 0


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
