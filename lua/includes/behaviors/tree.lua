TTTBots.Behaviors = {}

include("includes/behaviors/wander.lua")
include("includes/behaviors/findweapon.lua")
include("includes/behaviors/clearbreakables.lua")
include("includes/behaviors/attacktarget.lua")
include("includes/behaviors/investigatenoise.lua")
include("includes/behaviors/investigatecorpse.lua")

local b = TTTBots.Behaviors

TTTBots.Behaviors.BehaviorTree = { -- Acts as one big priority node
    b.AttackTarget,
    -- b.IDBody,
    b.ClearBreakables,
    b.InvestigateCorpse,
    b.FindWeapon,
    b.InvestigateNoise,
    -- b.FindAmmo,
    -- b.Heal,
    b.Wander,
}

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

function TTTBots.Behaviors.Tree()
    local tree = TTTBots.Behaviors.BehaviorTree

    for _, bot in pairs(player.GetBots()) do
        if not IsValid(bot) or not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        local behaviorChanged

        local currentBehavior = bot.currentBehavior
        local interruptible = currentBehavior and currentBehavior.Interruptible or true
        local newState = STATUS.FAILURE

        if currentBehavior and currentBehavior:Validate(bot) then
            newState = currentBehavior:OnRunning(bot)
        end

        if interruptible then
            for _, behavior in ipairs(tree) do
                if behavior:Validate(bot) then
                    if currentBehavior ~= behavior then
                        if currentBehavior then
                            currentBehavior:OnEnd(bot)
                        end
                        currentBehavior = behavior
                        bot.currentBehavior = behavior
                        behaviorChanged = true
                    end
                    break
                end
            end
        end

        if behaviorChanged then
            newState = currentBehavior:OnStart(bot)
        end

        if newState == STATUS.SUCCESS or newState == STATUS.FAILURE then
            currentBehavior:OnEnd(bot)
            bot.currentBehavior = nil
        end

        if newState == STATUS.SUCCESS then
            currentBehavior:OnSuccess(bot)
        elseif newState == STATUS.FAILURE then
            currentBehavior:OnFailure(bot)
        end
    end

    return STATUS.FAILURE
end
