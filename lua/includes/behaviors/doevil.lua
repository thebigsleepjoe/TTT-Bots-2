TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.DoEvil = {}

local lib = TTTBots.Lib

local DoEvil = TTTBots.Behaviors.DoEvil
DoEvil.Name = "DoEvil"
DoEvil.Description = "Follow commands from the Evil Coordinator module."
DoEvil.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

local SETTINGS = {
    GATHER_DISTANCE = 500,
}

local EvilCoordinator = TTTBots.EvilCoordinator

--- Validate the behavior
function DoEvil:Validate(bot)
    ---@type CPersonality
    local personality = bot.components.personality
    local isDisabled = lib.GetConVarBool("disable_coordinator")
    return not isDisabled and personality:GetIgnoresOrders() and lib.IsPlayerAlive(bot) and lib.IsEvil(bot)
end

--- Called when the behavior is started
function DoEvil:OnStart(bot)
    return STATUS.RUNNING
end

--- Order "GATHER" to move towards the determined location under EvilCoordinator.GetGatherPos
function DoEvil:Gather(bot)
    local gatherPos = EvilCoordinator.GetGatherPos()
    if not gatherPos then error("Gather position is nil! Why are we being told to gather???") end

    local distTo = bot:GetPos():Distance(gatherPos)
    if distTo < SETTINGS.GATHER_DISTANCE then return STATUS.SUCCESS end

    local locomotor = bot.components.locomotor
    locomotor:SetGoal(gatherPos)

    return STATUS.RUNNING
end

--- Order "ATTACKALL" to attack all nearby non-evil players.
function DoEvil:AttackAll(bot)
    -- local innocentsVisible = lib.GetAllVisible(bot:EyePos(), true)
    local memory = bot.component.memory
    local knownTargets = memory:GetKnownInnocentsPos()
    if #knownTargets == 0 then return STATUS.FAILURE end -- For technical reasons, we must return FAILURE. Otherwise, the bot will be stuck in this state forever.
    local target = table.Random(knownTargets)
    if not lib.IsPlayerAlive(target) then return STATUS.FAILURE end
    bot.attackTarget = target
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function DoEvil:OnRunning(bot)
    local order = EvilCoordinator.GetOrders(bot)
    if not order then return STATUS.FAILURE end
    local ordersHash = {
        GATHER = self.Gather,
    }

    local orderFunc = ordersHash[order]
    if not orderFunc then return error(string.format("%s is an order that does not exist (for %s).", order, bot:Nick())) end
    return orderFunc(self, bot)
end

--- Called when the behavior returns a success state
function DoEvil:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function DoEvil:OnFailure(bot)
end

--- Called when the behavior ends
function DoEvil:OnEnd(bot)
end
