--[[
Note: This is largely copied from Jackal, since the behavior is so similar.
Also forgive the code quality, this is my first time contributing to a github project.
-Z
--]]

---@class BSidekick
TTTBots.Behaviors.CreateDeputy = {}

local lib = TTTBots.Lib

---@class BSidekick
local CreateDeputy = TTTBots.Behaviors.CreateDeputy
CreateDeputy.Name = "Deputy"
CreateDeputy.Description = "Deputize a player (or random bot)."
CreateDeputy.Interruptible = true


local STATUS = TTTBots.STATUS

---Since Isolation isn't important when choosing a Deputy, we can just choose a random person nearby.
---@param bot Bot
---@return Player?
---@return number
function CreateDeputy.FindTarget(bot)
    local players = lib.GetAllWitnessesBasic(bot:GetPos(), nil, bot)
    local closest = lib.GetClosest(players, bot:GetPos())

    if closest then
        print(closest)
        return closest
    else
        print("Nobody around!")
    end
end

function CreateDeputy.ClearTarget(bot)
    bot.SidekickTarget = nil
end

---@class Bot
---@field SidekickTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Sidekick.ClearTarget.
---@see Sidekick.ClearTarget
---@param bot Bot
---@param target Player?
function CreateDeputy.SetTarget(bot, target)
    bot.SidekickTarget = target or CreateDeputy.FindTarget(bot)
end

function CreateDeputy.GetTarget(bot)
    return bot.SidekickTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateDeputy.ValidateTarget(bot, target)
    local target = target or CreateDeputy.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    return valid
end

---Should we start Deputizing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateDeputy.ShouldStartSidekicking(bot)
    local chance = math.random(0, 100) <= 4
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateDeputy.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Sidekick if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetSheriffGun()) then return false end -- Do not Sidekick if we don't have a jackal gun.
    return CreateDeputy.ValidateTarget(bot) or CreateDeputy.ShouldStartSidekicking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDeputy.OnStart(bot)
    if not CreateDeputy.ValidateTarget(bot) then
        CreateDeputy.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDeputy.OnRunning(bot)
    if not CreateDeputy.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateDeputy.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    --[[
    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateDeputy.CheckForBetterTarget(bot)
        if CreateDeputy.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end
    --]]

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()

    
    inv:PauseAutoSwitch()
    local equipped = inv:EquipSheriffGun()
    if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateDeputy.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateDeputy.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateDeputy.OnEnd(bot)
    CreateDeputy.ClearTarget(bot)
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
