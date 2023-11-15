include("includes/data/traits.lua")

---@class CPersonality
TTTBots.Components.Personality = {}

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

function BotPersonality:GetStatRateFor(name)
    return self[name .. "Rate"] or 1
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
    local modifier = self:GetStatRateFor("rage") * (lib.GetConVarFloat("rage_rate") / 100)
    modifier = math.max(0.05, modifier)
    self.rage = clamp(self.rage + (x * modifier), 0, 1)

    return self.rage
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddPressure(x)
    local modifier = self:GetStatRateFor("pressure") * (lib.GetConVarFloat("pressure_rate") / 100)
    self.pressure = clamp(self.pressure + (x * modifier), 0, 1)

    return self.pressure
end

local pressureEvents = { --- The amount that is added to our pressure when an event (the keys) happens.
    KillEnemy = -0.3,    --- When we kill an enemy
    Hurt = 0.1,          --- When we are hurt
    HurtEnemy = -0.1,    --- When we hurt an enemy
    HearGunshot = 0.02,  --- Upon hearing gunshots
    HearDeath = 0.1,     --- Upon hearing a death
    HearExplosion = 0.2, --- Upon hearing an explosion
    BulletClose = 0.05,  --- Player's bullet flies past our character
    NewTarget = 0.15,    --- Target changes to a new opponent
}
function BotPersonality:OnPressureEvent(event_name)
    local pressure = pressureEvents[event_name]
    if pressure then
        self:AddPressure(pressure)
    end
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddBoredom(x)
    local modifier = self:GetStatRateFor("boredom") * (lib.GetConVarFloat("boredom_rate") / 100)
    modifier = math.max(0.05, modifier)
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
            local amt = (-stat.decay / TTTBots.Tickrate) * (self:GetStatRateFor(stat.name))
            stat.addfunc(self, amt) -- stats are not affected by personality traits
        end
    end
end

local DISCONNECT_BOREDOM_THRESHOLD = 0.95
local DISCONNECT_RAGE_THRESHOLD = 0.98
function BotPersonality:DisconnectIfDesired()
    local roundActive = TTTBots.Match.RoundActive
    local isAlive = TTTBots.Lib.IsPlayerAlive(self.bot)
    if (roundActive or not isAlive) then return false end -- don't dc during a round, that's rude!
    if self.disconnecting then return true end
    local cvar = lib.GetConVarBool("allow_leaving")
    if not cvar then return end -- module is disabled
    if self:GetBoredom() >= DISCONNECT_BOREDOM_THRESHOLD then
        self.disconnecting = TTTBots.Lib.VoluntaryDisconnect(self.bot, "Boredom")
    elseif self:GetRage() >= DISCONNECT_RAGE_THRESHOLD then
        self.disconnecting = TTTBots.Lib.VoluntaryDisconnect(self.bot, "Rage")
    end
end

function BotPersonality:Think()
    if not (self.rageRate and self.pressureRate and self.boredomRate) then
        self.rageRate = (self:GetTraitMult("rageRate") or 1)         --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
        self.pressureRate = (self:GetTraitMult("pressureRate") or 1) --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
        self.boredomRate = (self:GetTraitMult("boredomRate") or 1)   --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
    end

    BOREDOM_ENABLED = TTTBots.Lib.GetConVarBool("boredom")
    PRESSURE_ENABLED = TTTBots.Lib.GetConVarBool("pressure")
    RAGE_ENABLED = TTTBots.Lib.GetConVarBool("rage")

    self:DecayStats()

    self:DisconnectIfDesired()
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

function BotPersonality:GetTraitAdditive(attribute)
    return self.bot:GetTraitAdditive(attribute)
end

function BotPersonality:GetTraitBool(attribute, falseHasPriority)
    return self.bot:GetTraitBool(attribute, falseHasPriority)
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
    local total = 1
    if not traits then return total end
    for i, trait in pairs(traits) do
        total = total * ((trait.effects and trait.effects[attribute]) or 1)
    end
    return total
end

function plyMeta:GetTraitAdditive(attribute)
    local traits = self.components.personality:GetTraitData()
    local total = 0
    if not traits then return total end
    for i, trait in pairs(traits) do
        total = total + ((trait.effects and trait.effects[attribute]) or 0)
    end
    return total
end

--- Return a boolean for the given attribute based on the bots traits. If false has priority (defaults true), then any traits that are false will make the entire function return false.
---@param attribute string The name of the attribute to check
---@param falseHasPriority boolean|nil Defaults to true. Should we escape early if we have a trait that conflicts with this attribute (aka is false)?
function plyMeta:GetTraitBool(attribute, falseHasPriority)
    if falseHasPriority == nil then falseHasPriority = true end
    local traits = self.components.personality:GetTraitData()
    local total = false
    if not traits then return total end
    for i, trait in pairs(traits) do
        local val = (trait.effects and trait.effects[attribute]) or
            nil                                     -- IMPORTANT to default to nil, otherwise false will probably be returned when it shouldn't be
        if falseHasPriority and (val == false) then -- check if val is explicitly false
            return false
        else
            total = total or val
        end
    end
    return total
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

-- ON DYING
local DEATH_RAGE_BASE = 0.2    -- Increase rage on death by this amount
local DEATH_PRESSURE_BASE = -1 -- Remove pressure when dying
local DEATH_BOREDOM_BASE = 0.1 -- Increase boredom on death by this amount

-- ON KILLING ANOTHER PLAYER
local KILL_RAGE_BASE = -0.1     -- Decrease rage on kill by this amount
local KILL_PRESSURE_BASE = -0.2 -- Decrease pressure on kill by this amount
local KILL_BOREDOM_BASE = -0.1  -- Decrease boredom on kill by this amount

hook.Add("PlayerDeath", "TTTBots.Personality.PlayerDeath", function(bot, inflictor, attacker)
    if bot:IsBot() then
        local personality = bot and bot.components and bot.components.personality
        if not personality then return end
        personality:AddRage(DEATH_RAGE_BASE)
        personality:AddPressure(DEATH_PRESSURE_BASE)
        personality:AddBoredom(DEATH_BOREDOM_BASE)
    end

    if attacker and IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot() then
        local personality = attacker and attacker.components and attacker.components.personality
        if not personality then return end
        personality:AddRage(KILL_RAGE_BASE)
        personality:AddPressure(KILL_PRESSURE_BASE)
        personality:AddBoredom(KILL_BOREDOM_BASE)
    end
end)

local LOSE_RAGE_BASE = 0.1         -- Increase rage by this amount when losing a round
local LOSE_PRESSURE_BASE = 0.1     -- Increase pressure by this amount when losing a round
local LOSE_BOREDOM_BASE = 0.05     -- Increase boredom by this amount when losing a round
local SURVIVAL_LOSE_MODIFIER = 0.5 -- Multiply the above values by this amount if the bot survives the round

local WIN_RAGE_BASE = -0.3         -- Decrease rage by this amount when winning a round
local WIN_PRESSURE_BASE = -1       -- Decrease pressure by this amount when winning a round
local WIN_BOREDOM_BASE = -0.05     -- Decrease boredom by this amount when winning a round
local SURVIVAL_WIN_MODIFIER = 2    -- Multiply the above values by this amount if the bot survives the round

local function updateBotAttributes(traitorsWon)
    for i, bot in pairs(TTTBots.Bots) do
        local personality = bot and bot.components and bot.components.personality
        if not personality then continue end
        local botEvil = lib.IsEvil(bot)
        local botSurvived = lib.IsPlayerAlive(bot)

        if botEvil then
            if traitorsWon then
                personality:AddRage(WIN_RAGE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
                personality:AddPressure(WIN_PRESSURE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
                personality:AddBoredom(WIN_BOREDOM_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
            else
                personality:AddRage(LOSE_RAGE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
                personality:AddPressure(LOSE_PRESSURE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
                personality:AddBoredom(LOSE_BOREDOM_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
            end
        else
            if traitorsWon then
                personality:AddRage(LOSE_RAGE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
                personality:AddPressure(LOSE_PRESSURE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
                personality:AddBoredom(LOSE_BOREDOM_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
            else
                personality:AddRage(WIN_RAGE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
                personality:AddPressure(WIN_PRESSURE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
                personality:AddBoredom(WIN_BOREDOM_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
            end
        end
    end
end

hook.Add("TTTEndRound", "TTTBots.Personality.EndRound", function(result)
    local RESULTS = {
        innocents = "innocents",
        traitors = "traitors",
    }
    if not RESULTS[result] then return end

    if result == RESULTS.innocents then
        updateBotAttributes(false)
    else
        updateBotAttributes(true)
    end
end)

local RDM_RAGE_MIN = 0.7
local RDM_BOREDOM_MIN = 0.7
local RDM_PCT_CHANCE = 20 -- 10% chance to rdm every 2.5 seconds if criteria are met
timer.Create("TTTBots.Personality.RDM", 2.5, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not lib.GetConVarBool("enable_rdm") then return end
    for i, bot in pairs(TTTBots.Bots) do
        if not lib.IsPlayerAlive(bot) then continue end -- skip if bot not loaded
        local personality = lib.GetComp(bot, "personality") ---@type CPersonality
        if not personality then continue end            -- skip if bot not loaded
        if lib.IsEvil(bot) then continue end            -- no rdm for traitors
        if bot.attackTarget ~= nil then continue end    -- no rdm if we're already attacking someone

        local boredom = personality:GetBoredom()
        local rage = personality:GetRage()
        local isRdmer = personality:GetTraitBool("rdmer")
        local chanceTest = math.random(1, 100) <= RDM_PCT_CHANCE

        if chanceTest and isRdmer or (boredom > RDM_BOREDOM_MIN) or (rage > RDM_RAGE_MIN) then
            local targets = lib.GetAllWitnessesBasic(bot:GetPos(), TTTBots.Match.AlivePlayers, bot)
            local grudge = (IsValid(bot.grudge) and lib.IsPlayerAlive(bot.grudge) and bot.grudge)
            local randomTarget = grudge or table.Random(targets)
            if targets and #targets > 0 then
                bot:SetAttackTarget(randomTarget)
            end
        end
    end
end)
