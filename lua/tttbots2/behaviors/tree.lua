TTTBots.Behaviors = {}

include("tttbots2/behaviors/wander.lua")
include("tttbots2/behaviors/findweapon.lua")
include("tttbots2/behaviors/clearbreakables.lua")
include("tttbots2/behaviors/attacktarget.lua")
include("tttbots2/behaviors/investigatenoise.lua")
include("tttbots2/behaviors/investigatecorpse.lua")
include("tttbots2/behaviors/follow.lua")
include("tttbots2/behaviors/followplan.lua")
include("tttbots2/behaviors/defuse.lua")
include("tttbots2/behaviors/plantbomb.lua")

local b = TTTBots.Behaviors

TTTBots.Behaviors.BehaviorTree = { -- Acts as one big priority node
    b.ClearBreakables,
    b.AttackTarget,
    b.PlantBomb,
    b.Defuse,
    b.InvestigateCorpse,
    b.FindWeapon,
    b.FollowPlan,
    b.InvestigateNoise,
    -- b.FindAmmo,
    -- b.Heal,
    b.Follow,
    b.Wander,
}

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

function TTTBots.Behaviors.Tree()
    local tree = TTTBots.Behaviors.BehaviorTree

    for _, bot in pairs(TTTBots.Bots) do
        if not IsValid(bot) or not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        local behaviorChanged

        local currentBehavior = bot.currentBehavior
        local interruptible = currentBehavior and currentBehavior.Interruptible or true
        local newState = STATUS.FAILURE

        if currentBehavior and currentBehavior.Validate(bot) then
            newState = currentBehavior.OnRunning(bot)
        end

        if interruptible then
            for _, behavior in ipairs(tree) do
                if behavior.Validate(bot) then
                    if currentBehavior ~= behavior then
                        if currentBehavior then
                            currentBehavior.OnEnd(bot)
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
            newState = currentBehavior.OnStart(bot)
        end

        if newState == STATUS.SUCCESS or newState == STATUS.FAILURE then
            currentBehavior.OnEnd(bot)
            bot.currentBehavior = nil
        end

        if newState == STATUS.SUCCESS then
            currentBehavior.OnSuccess(bot)
        elseif newState == STATUS.FAILURE then
            currentBehavior.OnFailure(bot)
        end

        -- if not currentBehavior or not currentBehavior.Validate(bot) then
        --     print(string.format("Couldn't get any behaviors to tick on bot %s", bot:Nick()))
        -- else
        --     print(string.format("[BT] Bot %s is running behavior %s", bot:Nick(), currentBehavior.Name))
        --     -- local printf = function(...)
        --     --     print(string.format(...))
        --     -- end

        --     -- printf("============= BOT %s BEHAVIOR =============", bot:Nick())
        --     -- printf("Behavior: %s", currentBehavior.Name)
        --     -- printf("Status: %s",
        --     --     newState == STATUS.SUCCESS and "SUCCESS" or newState == STATUS.FAILURE and "FAILURE" or "RUNNING")
        --     -- printf(behaviorChanged and "Behavior changed" or "Behavior unchanged")
        --     -- printf(interruptible and "Behavior interruptible" or "Behavior uninterruptible")
        --     -- printf("============================================")
        -- end
    end

    return STATUS.FAILURE
end
