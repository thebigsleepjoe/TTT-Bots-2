TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BSidekick
TTTBots.Behaviors.CreateSidekick = {}

local lib = TTTBots.Lib

---@class BSidekick
local CreateSidekick = TTTBots.Behaviors.CreateSidekick
CreateSidekick.Name = "Sidekick"
CreateSidekick.Description = "Sidekick a player (or random player) and ultimately kill them."
CreateSidekick.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Sidekick.
---A higher isolation means the player is more isolated, and thus a better target for Sidekicking.
---@param bot Bot
---@param other Player
---@return number
function CreateSidekick.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Sidekick, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateSidekick.FindTarget(bot)
    return lib.FindIsolatedTarget(bot)
end

function CreateSidekick.ClearTarget(bot)
    bot.SidekickTarget = nil
end

---@class Bot
---@field SidekickTarget Player?
---@field SidekickScore number?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Sidekick.ClearTarget.
---@see Sidekick.ClearTarget
---@param bot Bot
---@param target Player?
function CreateSidekick.SetTarget(bot, target, isolationScore)
    bot.SidekickTarget = target or CreateSidekick.FindTarget(bot)
    bot.SidekickScore = isolationScore or CreateSidekick.RateIsolation(bot, bot.SidekickTarget)
end

function CreateSidekick.GetTarget(bot)
    return bot.SidekickTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateSidekick.ValidateTarget(bot, target)
    local target = target or CreateSidekick.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateSidekick.CheckForBetterTarget(bot)
    local currentScore = bot.SidekickScore or -math.huge
    local alternative, altScore = CreateSidekick.FindTarget(bot)

    if not alternative then return end
    if not CreateSidekick.ValidateTarget(bot, alternative) then return end

    -- check for a difference of at least +1
    if altScore and altScore - currentScore >= 1 then
        CreateSidekick.SetTarget(bot, alternative, altScore)
    end
end

---Should we start Sidekicking? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateSidekick.ShouldStartSidekicking(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateSidekick.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Sidekick if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetJackalGun()) then return false end -- Do not Sidekick if we don't have a jackal gun.
    return CreateSidekick.ValidateTarget(bot) or CreateSidekick.ShouldStartSidekicking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateSidekick.OnStart(bot)
    if not CreateSidekick.ValidateTarget(bot) then
        CreateSidekick.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateSidekick.OnRunning(bot)
    if not CreateSidekick.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateSidekick.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateSidekick.CheckForBetterTarget(bot)
        if CreateSidekick.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()

    local witnesses = lib.GetAllWitnessesBasic(targetPos, TTTBots.Roles.GetNonAllies(bot), bot)
    if table.Count(witnesses) <= 1 then
        inv:PauseAutoSwitch()
        local equipped = inv:EquipJackalGun()
        if not equipped then return STATUS.RUNNING end
        local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
        loco:LookAt(bodyPos)
        local eyeTrace = bot:GetEyeTrace()
        if eyeTrace and eyeTrace.Entity == target then
            loco:StartAttack()
        end
        return STATUS.RUNNING
    else
        inv:ResumeAutoSwitch()
        loco:StopAttack()
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateSidekick.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateSidekick.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateSidekick.OnEnd(bot)
    CreateSidekick.ClearTarget(bot)
    local loco = bot:BotLocomotor()
    if not loco then return end
    loco:StopAttack()
    bot:SetAttackTarget(nil)
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = bot:BotInventory()
        if not (inv) then return end
        inv:ResumeAutoSwitch()
    end)
end
