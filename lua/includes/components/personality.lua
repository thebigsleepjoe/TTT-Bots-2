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

    self.traits = self:GetNoConflictTraits(4)
    self.archetype = self:GetClosestArchetype()

    --- How angry the bot is, from 1-100. Adds onto pressure. At 100% rage, the bot will leave voluntary (if enabled).
    self.rage = 0
    --- How pressured the bot is feeling (effects aim) from 1-100.
    self.pressure = 0
    --- How bored the bot is. Affects how long until they voluntarily leave the server (and get replaced)
    self.boredom = 0


    self.bot = bot
end

function BotPersonality:GetClosestArchetype()
    local traitData = self:GetTraitData()
    local archetypes = {}
    for i, trait in pairs(traitData) do
        if trait.archetype then
            archetypes[trait.archetype] = (archetypes[trait.archetype] or 0) + 1
        end
    end
    local sortedArchetypes = {}
    for archetype, count in pairs(archetypes) do
        table.insert(sortedArchetypes, { archetype = archetype, count = count })
    end
    table.sort(sortedArchetypes, function(a, b) return a.count > b.count end)
    if sortedArchetypes[1] then
        return sortedArchetypes[1].archetype
    else
        return "default"
    end
end

--- flavors text based on gender pronouns (self.HIM, .HIS, .HE)
function BotPersonality:FlavorText(text)
    local str, _int = string.gsub(text, "%[HIM%]", self.HIM):gsub("%[HIS%]", self.HIS):gsub("%[HE%]", self.HE)
    return str
end

--- Return the bot's list of traits. These are just keynames and not the actual trait objects.
function BotPersonality:GetTraits()
    return self.traits
end

--- Returns a table of trait data, which is a table of actual trait objects, instead of the keys themselves (like GetTraits())
function BotPersonality:GetTraitData()
    if self.traitData then return self.traitData end
    self.traitData = {}
    for _, trait in ipairs(self.traits) do
        table.insert(self.traitData, BotPersonality.Traits[trait])
    end
    return self.traitData
end

--- Returns a table of strings that are the flavored trait descriptions. Basically human-readable explanations of each trait.
function BotPersonality:GetFlavoredTraits()
    local traits = {}
    for i, trait in ipairs(self.traits) do
        -- print(self:FlavorText(self.Traits[trait].description))
        table.insert(traits, self:FlavorText(self.Traits[trait].description))
    end
    return traits
end

function BotPersonality:PrintFlavoredTraits()
    for _, trait in ipairs(self:GetFlavoredTraits()) do
        print(trait)
    end
end

local DECAY_BOREDOM = -0.0005 -- at 100% rate, with no interruptions, this is about 2000 secs (32 mins) to reach 1 from 0
local DECAY_PRESSURE = 0.05   -- at 100% rate, with no interruptions, this is about 20 secs to reach 0 from 1
local DECAY_RAGE = 0.002      -- at 100% rate, with no interruptions, this is about 500 secs (8 mins) to reach 0 from 1

local BOREDOM_ENABLED = 1
local PRESSURE_ENABLED = 1
local RAGE_ENABLED = 1

local function clamp(n, min, max)
    return math.min(math.max(n, min), max)
end

--- decrement the value n by decayAmt, while saying within [0,1]
local function decayN(n, decayAmt)
    return clamp((n or 0) - decayAmt, 0, 1)
end
--- Returns the bot's rage, if enabled, else 0.
function BotPersonality:GetRage() return RAGE_ENABLED and self.rage or 0 end

--- Returns the bot's pressure, if enabled, else 0.
function BotPersonality:GetPressure() return PRESSURE_ENABLED and self.pressure or 0 end

--- Returns the bot's boredom, if enabled, else 0.
function BotPersonality:GetBoredom() return BOREDOM_ENABLED and self.boredom or 0 end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddRage(x)
    local modifier = lib.GetConVarFloat("rage_rate") / 100
    self.rage = clamp(self.rage + (x * modifier), 0, 1)

    return self.rage
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddPressure(x)
    local modifier = lib.GetConVarFloat("pressure_rate") / 100
    self.pressure = clamp(self.pressure + (x * modifier), 0, 1)

    return self.pressure
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddBoredom(x)
    local modifier = lib.GetConVarFloat("boredom_rate") / 100
    self.boredom = clamp(self.boredom + (x * modifier), 0, 1)

    return self.boredom
end

--- Decay boredom, pressure, and rage.
function BotPersonality:DecayStats()
    local stats = {
        { name = "boredom",  decay = DECAY_BOREDOM,  addfunc = self.AddBoredom,  enabled = BOREDOM_ENABLED },
        { name = "pressure", decay = DECAY_PRESSURE, addfunc = self.AddPressure, enabled = PRESSURE_ENABLED },
        { name = "rage",     decay = DECAY_RAGE,     addfunc = self.AddRage,     enabled = RAGE_ENABLED },
    }

    for _, stat in ipairs(stats) do
        if not stat.enabled then continue end
        if stat.decay ~= 0 then
            stat.addfunc(self, -stat.decay / TTTBots.Tickrate)
        end
    end
end

function BotPersonality:Think()
    BOREDOM_ENABLED = TTTBots.Lib.GetConVarBool("boredom")
    PRESSURE_ENABLED = TTTBots.Lib.GetConVarBool("pressure")
    RAGE_ENABLED = TTTBots.Lib.GetConVarBool("rage")

    self:DecayStats()
end

--- Get a pure random trait name.
---@return string
function BotPersonality:GetRandomTrait()
    local keys = {}
    for k, _ in pairs(self.Traits) do
        table.insert(keys, k)
    end
    return keys[math.random(#keys)]
end

--- Detect if a trait conflicts with anything in the a of traits
---@param trait string
---@param traitSet table
---@return boolean
function BotPersonality:TraitHasConflict(trait, traitSet)
    for _, selectedTrait in ipairs(traitSet) do
        for _, conflict in ipairs(self.Traits[selectedTrait].conflicts) do
            if conflict == trait then
                return true
            end
        end
    end
    return false
end

--- Returns a set of num traits that are non-conflicting. Don't get too many, otherwise it'll crash or take a long time.
---@param num number
---@return table
function BotPersonality:GetNoConflictTraits(num)
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

--- Functionally same as Player:HasTrait(trait_name)
---@param trait_name string
---@return boolean
function BotPersonality:HasTrait(trait_name)
    return self.bot:HasTrait(trait_name)
end

function BotPersonality:HasTraitIn(hashtable)
    return self.bot:HasTraitIn(hashtable)
end

function BotPersonality:GetIgnoresOrders()
    if self.bot.ignoreOrders ~= nil then return self.bot.ignoreOrders end
    -- go through each trait and check if it has "ignoreOrders" in its effects set to true
    local traits = self:GetTraitData()
    for _, trait in ipairs(traits) do
        if trait.effects and trait.effects.ignoreOrders then
            self.bot.ignoreOrders = true
            return true
        end
    end
    self.bot.ignoreOrders = false
    return false
end

---Wrapper for bot:GetTraitMult(attribute)
---@param attribute string
---@return number
function BotPersonality:GetTraitMult(attribute)
    return self.bot:GetTraitMult(attribute)
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
function plyMeta:GetTraitMult(attribute)
    local traits = self.components.personality:GetTraitData()
    local avg = 1
    if not traits then return avg end
    for i, trait in pairs(traits) do
        avg = avg * ((trait.effects and trait.effects[attribute]) or 1)
    end
    return avg
end

--- Check if the bot has a specific trait, by name.
---@param trait_name string
---@return boolean hasTrait
function plyMeta:HasTrait(trait_name)
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

--- Check if the bot has any traits that match the entries in the hashtable.
---@param hashtable table<string, boolean>
---@return boolean hasTrait
function plyMeta:HasTraitIn(hashtable)
    local traits = self.components.personality:GetTraits()
    for _, trait in ipairs(traits) do
        if hashtable[trait] then
            return true
        end
    end
    return false
end
