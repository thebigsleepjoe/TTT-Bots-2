TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BMingeCrowbar
TTTBots.Behaviors.MingeCrowbar = {}

local lib = TTTBots.Lib

---@class BMingeCrowbar
local MingeCrowbar = TTTBots.Behaviors.MingeCrowbar
MingeCrowbar.Name = "MingeCrowbar"
MingeCrowbar.Description = "Minge (mostly push-related) with the crowbar."
MingeCrowbar.Interruptible = true
MingeCrowbar.MinTimeBetween = 60.0
MingeCrowbar.SkipChance = 3 -- 1 in X change of skipping even if cooldown

---@class Bot
---@field isCBMinging boolean Is the bot currently minging
---@field mingeStopTime number The time we should stop minging by
---@field mingeTarget Player? The player target to minge

local STATUS = TTTBots.STATUS

function MingeCrowbar.IsMinging(bot)
    return bot.isCBMinging
end

---@return Player?
function MingeCrowbar.GetMingeTarget(bot)
    local personality = bot:BotPersonality() ---@type CPersonality
    local rate = personality:GetTraitMult("mingeRate") or 1.0
    local nearbyPlayers = lib.FilterTable(TTTBots.Roles.GetNonAllies(bot), function(other)
        if not IsValid(other) then return false end
        if not lib.CanSeeArc(bot, other:GetPos(), 120) then return false end
        local dist = bot:GetPos():Distance(other:GetPos())

        if dist < (100 * rate) then return true end
    end)

    return lib.GetClosest(nearbyPlayers, bot:GetPos()) ---@type Player?
end

function MingeCrowbar.CanStartMinge(bot)
    local nextMingeTime = bot.nextMingeTime or 0
    local personality = bot:BotPersonality() ---@type CPersonality
    local rate = personality:GetTraitMult("mingeRate") or 1.0

    if rate <= 0.05 then return false end

    if nextMingeTime > CurTime() then return false end

    if MingeCrowbar.GetMingeTarget(bot) == nil then return false end

    local chance = math.random(1, MingeCrowbar.SkipChance)
    if chance ~= 1 then return false end

    return true
end

function MingeCrowbar.SetMingeTimer(bot)
    local personality = bot:BotPersonality() ---@type CPersonality
    local rate = personality:GetTraitMult("mingeRate") or 1.0

    bot.nextMingeTime = CurTime() + (MingeCrowbar.MinTimeBetween / rate)
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function MingeCrowbar.Validate(bot)
    local mc = MingeCrowbar
    return (
        mc.IsMinging(bot)
        or mc.CanStartMinge(bot)
    )
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function MingeCrowbar.OnStart(bot)
    bot.isCBMinging = true
    bot.mingeStopTime = CurTime() + 3.5
    bot.mingeTarget = MingeCrowbar.GetMingeTarget(bot)
    MingeCrowbar.SetMingeTimer(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function MingeCrowbar.OnRunning(bot)
    local loco = bot:BotLocomotor() ---@type CLocomotor
    local inv = bot:BotInventory() ---@type CInventory
    loco:SetGoal(bot:GetPos())
    inv:PauseAutoSwitch()
    inv:EquipMelee()
    loco:StartAttack2()
    loco:PauseRepel()

    if bot.mingeStopTime < CurTime() then
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function MingeCrowbar.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function MingeCrowbar.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function MingeCrowbar.OnEnd(bot)
    bot.isCBMinging = false
    bot.mingeStopTime = nil
    bot.mingeTarget = nil
    local loco = bot:BotLocomotor() ---@type CLocomotor
    local inv = bot:BotInventory() ---@type CInventory
    inv:ResumeAutoSwitch()
    loco:StopAttack2()
    loco:SetGoal()
    loco:ResumeRepel()
end
