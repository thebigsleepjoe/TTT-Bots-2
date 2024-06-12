--- This module is specific to the TTT2 Bodyguard role.
if not (TTT2 and ROLE_BODYGUARD) then return end



---@class BBodyguard : BBase
TTTBots.Behaviors.Bodyguard = {}

local lib = TTTBots.Lib

---@class BBodyguard
local Bodyguard = TTTBots.Behaviors.Bodyguard
Bodyguard.Name = "Bodyguard"
Bodyguard.Description = "Protect bodyguard target from harm."
Bodyguard.Interruptible = true

---@class Bot

local STATUS = TTTBots.STATUS

---@param bot Bot
function Bodyguard.Validate(bot)
    return true
end

---@param bot Bot
function Bodyguard.OnStart(bot)
    return STATUS.RUNNING
end

---@param bot Bot
function Bodyguard.GetTarget(bot)
    return BODYGRD_DATA:GetGuardedPlayer(bot)
end

---@param bot Bot
function Bodyguard.OnRunning(bot)
    local target = Bodyguard.GetTarget(bot)

    if not (target and IsValid(target)) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()

    local distToTarget = bot:GetPos():Distance(target:GetPos())
    local maxDist = 250

    if distToTarget > maxDist then
        loco:SetGoal(target:GetPos())
        loco:DisableAvoid()
    else
        loco:StopMoving()
    end

    return STATUS.RUNNING
end

---@param bot Bot
function Bodyguard.OnSuccess(bot)
end

---@param bot Bot
function Bodyguard.OnFailure(bot)
end

---@param bot Bot
function Bodyguard.OnEnd(bot)
    local loco = bot:BotLocomotor()
    loco:StopMoving()
    loco:EnableAvoid()
end

---@param player Player
function Bodyguard.GetBodyguards(player)
    return BODYGRD_DATA:GetGuards(player) or {}
end

---@param bot Bot
---@param victim Player
function Bodyguard.SetAttackTarget(bot, victim)
    bot:SetAttackTarget(victim)
    -- maybe some more logic here in the future
end

local function fullValidatePlayer(player)
    return player and IsValid(player) and player:IsPlayer() and lib.IsPlayerAlive(player)
end

---Checks the victim for any possible bodyguards they have, then assigns their targets to the offender.
---@param victim Player
---@param offender Player
local function defendPossibleFriend(victim, offender)
    if not (fullValidatePlayer(victim)) then return false end
    if not (fullValidatePlayer(offender)) then return false end

    local guardsForVictim = Bodyguard.GetBodyguards(victim)

    for i, defender in pairs(guardsForVictim) do
        if not fullValidatePlayer(defender) then continue end
        if not defender:IsBot() then continue end
        ---@cast defender Bot

        if not defender.attackTarget then
            Bodyguard.SetAttackTarget(defender, offender)
            defender:BotMemory():UpdateKnownPositionFor(offender, offender:GetPos())
        end
    end
end

hook.Add("PlayerHurt", "TTTBots.Bodyguard.PlayerHurt", function(victim, attacker)
    if not TTTBots.Match.IsRoundActive() then return end

    -- First check if the victim of the hurt needs to be protected
    defendPossibleFriend(victim, attacker)

    -- Then check if this is actually combat we should be helping with
    defendPossibleFriend(attacker, victim)
end)