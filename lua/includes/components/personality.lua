include("includes/data/traits.lua")

---@class CPersonality
TTTBots.Components.Personality = TTTBots.Components.Personality or {}

local lib = TTTBots.Lib
---@class CPersonality
local BotPersonality = TTTBots.Components.Personality

BotPersonality.Traits = TTTBots.Traits

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

---Get the average trait multiplier for a given personality attribute. This could be hearing, fov, etc.
---@param attribute string
---@return number
function plyMeta:AverageTraitMultFor(attribute)
    local traits = self.components and self.components.personality and self.components.personality:GetTraits()
    if not traits then return 1 end
    local avg = 0.0
    for i, trait in pairs(traits) do
        avg = avg + ((trait.effects and trait.effects[attribute]) or 0)
    end
    return avg / #traits
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
