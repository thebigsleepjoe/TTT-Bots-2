TTTBots.Behaviors = {}

include("includes/behaviors/wander.lua")
include("includes/behaviors/findweapon.lua")
include("includes/behaviors/clearbreakables.lua")

local b = TTTBots.Behaviors
TTTBots.Behaviors.BehaviorTree = { -- Acts as one big priority node
    -- b.Attack,
    -- b.IDBody,
    b.ClearBreakables,
    b.FindWeapon,
    -- b.FindAmmo,
    -- b.Heal,
    b.Wander,
}

function TTTBots.Behaviors.Tree()
    local tree = TTTBots.Behaviors.BehaviorTree
    local status = {
        Running = 1,
        Success = 2,
        Failure = 3,
    }

    for x, bot in ipairs(player.GetBots()) do
        local currentBehavior = bot.currentBehavior
        local newState = status.Failure
        local behaviorChanged = false
        if currentBehavior and currentBehavior:Validate(bot) then
            newState = currentBehavior:OnRunning(bot)
            print("Running behavior named " .. currentBehavior.Name)
        else
            for i, behavior in pairs(tree) do
                if behavior:Validate(bot) then
                    if currentBehavior ~= behavior then
                        if currentBehavior then
                            currentBehavior:OnEnd(bot)
                        end
                        currentBehavior = behavior
                        bot.currentBehavior = currentBehavior
                        behaviorChanged = true
                    end
                    break
                end
            end
        end

        if behaviorChanged then
            newState = currentBehavior:OnStart(bot)
        end

        if newState == status.Success then
            currentBehavior:OnSuccess(bot)
            currentBehavior:OnEnd(bot)
            bot.currentBehavior = nil
        elseif newState == status.Failure then
            currentBehavior:OnFailure(bot)
            currentBehavior:OnEnd(bot)
            bot.currentBehavior = nil
        end
    end

    return status.Failure
end
