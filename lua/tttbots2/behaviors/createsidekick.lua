TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BSidekick
TTTBots.Behaviors.CreateSidekick = {}

local lib = TTTBots.Lib

---@class BSidekick
local CreateSidekick = TTTBots.Behaviors.CreateSidekick
CreateSidekick.Name = "Sidekick"
CreateSidekick.Description = "Sidekick a player (or random player) and ultimately kill them."
CreateSidekick.Interruptible = true

---@enum BStatus
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

---Give a weight to how isolated 'other' is to us. This is used to determine who to Sidekick.
---A higher isolation means the player is more isolated, and thus a better target for Sidekicking.
---@param bot Player
---@param other Player
---@return number
function CreateSidekick.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Sidekick, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Player
---@return Player?
---@return number
function CreateSidekick.FindTarget(bot)
    return lib.FindIsolatedTarget(bot)
end

function CreateSidekick.ClearTarget(bot)
    bot.SidekickTarget = nil
end

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Sidekick.ClearTarget.
---@see Sidekick.ClearTarget
---@param bot Player
---@param target Player?
function CreateSidekick.SetTarget(bot, target, isolationScore)
    bot.SidekickTarget = target or CreateSidekick.FindTarget(bot)
    bot.SidekickScore = isolationScore or CreateSidekick.RateIsolation(bot, bot.SidekickTarget)
end

function CreateSidekick.GetTarget(bot)
    return bot.SidekickTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Player
---@param target? Player
---@return boolean
function CreateSidekick.ValidateTarget(bot, target)
    return TTTBots.Behaviors.Stalk.ValidateTarget(bot, target) -- This mimics the same functionality.
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Player
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
---@param bot Player
---@return boolean
function CreateSidekick.ShouldStartSidekicking(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Player
---@return boolean
function CreateSidekick.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Sidekick if we're killing someone already.
    local inv = lib.GetComp(bot, "inventory") ---@type CInventory
    if not (inv and inv:GetJackalGun()) then return false end -- Do not Sidekick if we don't have a jackal gun.
    return CreateSidekick.ValidateTarget(bot) or CreateSidekick.ShouldStartSidekicking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function CreateSidekick.OnStart(bot)
    if not CreateSidekick.ValidateTarget(bot) then
        CreateSidekick.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Player
---@return BStatus
function CreateSidekick.OnRunning(bot)
    if not CreateSidekick.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateSidekick.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (bot:Visible(target) and math.random(1, TTTBots.Tickrate * 2) == 1) then
        CreateSidekick.CheckForBetterTarget(bot)
        if CreateSidekick.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    local inv = lib.GetComp(bot, "inventory") ---@type CInventory
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
        loco:StartAttack()
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Player
function CreateSidekick.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Player
function CreateSidekick.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function CreateSidekick.OnEnd(bot)
    CreateSidekick.ClearTarget(bot)
    local loco = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    if not loco then return end
    loco:StopAttack()
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = lib.GetComp(bot, "inventory") ---@type CInventory
        if not (inv) then return end
        inv:ResumeAutoSwitch()
    end)
end
