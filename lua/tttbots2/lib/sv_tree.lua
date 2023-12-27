TTTBots.Behaviors = {}

TTTBots.Lib.IncludeDirectory("tttbots2/behaviors")


TEAM_TRAITOR = TEAM_TRAITOR or "traitors"
TEAM_INNOCENT = TEAM_INNOCENT or "innocents"
TEAM_NONE = TEAM_NONE or "none"

local b = TTTBots.Behaviors

TTTBots.Behaviors.DefaultTrees = {
    innocent = {
        b.ClearBreakables,
        b.AttackTarget,
        b.Defuse,
        b.InvestigateCorpse,
        b.FindWeapon,
        b.InvestigateNoise,
        b.UseHealthStation,
        b.Follow,
        b.Wander,
    },
    traitor = {
        b.ClearBreakables,
        b.AttackTarget,
        b.PlantBomb,
        b.InvestigateCorpse,
        b.FindWeapon,
        b.FollowPlan,
        b.InvestigateNoise,
        b.UseHealthStation,
        b.Follow,
        b.Wander,
    },
    detective = {
        b.ClearBreakables,
        b.AttackTarget,
        b.Defuse,
        b.InvestigateCorpse,
        b.FindWeapon,
        b.InvestigateNoise,
        b.UseHealthStation,
        b.Follow,
        b.Wander,
    }
}
TTTBots.Behaviors.DefaultTreesByTeam = {
    [TEAM_TRAITOR] = TTTBots.Behaviors.DefaultTrees.traitor,
    [TEAM_INNOCENT] = TTTBots.Behaviors.DefaultTrees.innocent,
    [TEAM_NONE] = TTTBots.Behaviors.DefaultTrees.innocent,
}

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Returns the highest priority tree that has a callback which returned true on this bot.
---@param ply Player
function TTTBots.Behaviors.GetTreeFor(ply)
    return TTTBots.Roles.GetRoleFor(ply):GetBTree()
end

--- Return the first behavior in the given tree that is valid for the given bot. If none, then returns false.
---@param tree table<BBase>
---@param bot Player
---@return BBase|false
function TTTBots.Behaviors.GetFirstValid(tree, bot)
    for _, behavior in ipairs(tree) do
        if behavior.Validate(bot) then
            return behavior
        end
    end

    return false
end

function TTTBots.Behaviors.CallTreeOnBots()
    for _, bot in pairs(TTTBots.Bots) do
        if not IsValid(bot) or not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        local tree = TTTBots.Behaviors.GetTreeFor(bot)
        if not tree then continue end

        local behaviorChanged
        local lastBehavior = bot.lastBehavior
        local interruptible = lastBehavior and lastBehavior.Interruptible or true
        local newState = STATUS.FAILURE

        if lastBehavior and lastBehavior.Validate(bot) then
            newState = lastBehavior.OnRunning(bot)
        end

        if interruptible then
            for _, behavior in ipairs(tree) do
                if behavior.Validate(bot) then
                    if lastBehavior ~= behavior then
                        if lastBehavior then
                            lastBehavior.OnEnd(bot)
                        end
                        lastBehavior = behavior
                        bot.lastBehavior = behavior
                        behaviorChanged = true
                    end
                    break
                end
            end
        end

        if behaviorChanged then
            newState = lastBehavior.OnStart(bot)
        end

        if newState == STATUS.SUCCESS or newState == STATUS.FAILURE then
            if lastBehavior then lastBehavior.OnEnd(bot) end
            bot.lastBehavior = nil
        end

        if newState == STATUS.SUCCESS then
            if lastBehavior then lastBehavior.OnSuccess(bot) end
        elseif newState == STATUS.FAILURE then
            if lastBehavior then lastBehavior.OnFailure(bot) end
        end
    end

    return STATUS.FAILURE
end
