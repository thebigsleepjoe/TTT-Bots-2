TTTBots.Behaviors = {}

TTTBots.Lib.IncludeDirectory("tttbots2/behaviors")


TEAM_TRAITOR = TEAM_TRAITOR or "traitors"
TEAM_INNOCENT = TEAM_INNOCENT or "innocents"
TEAM_NONE = TEAM_NONE or "none"

local _bh = TTTBots.Behaviors

TTTBots.Behaviors.PriorityNodes = {
    --- Fight back vs the environment (blocking props) or other players.
    FightBack = {
        _bh.ClearBreakables,
        _bh.AttackTarget
    },
    --- Restore values, like health, ammo, etc.
    Restore = {
        _bh.FindWeapon,
        _bh.UseHealthStation
    },
    --- Investigate corpses/noises.
    Investigate = {
        _bh.InvestigateCorpse,
        _bh.InvestigateNoise
    },
    --- Patrolling stuffs
    Patrol = {
        _bh.Follow,
        _bh.Wander
    },
    --- Minge around with others
    Minge = {
        _bh.MingeCrowbar,
    }
}

local _prior = TTTBots.Behaviors.PriorityNodes

TTTBots.Behaviors.DefaultTrees = {
    innocent = {
        _prior.FightBack,
        _bh.Defuse,
        _prior.Restore,
        _bh.Interact,
        _prior.Investigate,
        _prior.Minge,
        _prior.Patrol
    },
    traitor = {
        _prior.FightBack,
        _bh.Defib,
        _bh.PlantBomb,
        _bh.InvestigateCorpse,
        _prior.Restore,
        _bh.FollowPlan,
        _bh.Interact,
        _prior.Minge,
        _prior.Investigate,
        _prior.Patrol
    },
    detective = {
        _prior.FightBack,
        _bh.Defib,
        _bh.Defuse,
        _prior.Restore,
        _bh.Interact,
        _prior.Minge,
        _prior.Investigate,
        _prior.Patrol
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
        local bh = behavior
        if type(behavior) == "table" and not behavior.Validate then
            bh = TTTBots.Behaviors.GetFirstValid(behavior, bot)
        end
        if bh and bh.Validate(bot) then
            return bh
        end
    end

    return false
end

function TTTBots.Behaviors.CallTree(bot, tree)
    if not IsValid(bot) or not (bot.components and bot:BotLocomotor()) then return end -- Prevent strange errors from happening on bot DC
    tree = tree or TTTBots.Behaviors.GetTreeFor(bot)
    if not tree then return end

    local lastBehavior = bot.lastBehavior ---@type BBase?
    local lastState = bot.lastState ---@type BStatus?
    local canInterrupt =
        not lastBehavior
        or lastState ~= STATUS.RUNNING
        or lastBehavior.Interruptible

    local behavior = canInterrupt and TTTBots.Behaviors.GetFirstValid(tree, bot) or lastBehavior
    local behaviorChanged = lastBehavior ~= behavior

    local newState = STATUS.FAILURE

    if not behavior then return end -- no valid behaviors

    if behaviorChanged then
        -- clean up past bhvr and start new one
        if lastBehavior then lastBehavior.OnEnd(bot) end
        newState = behavior.OnStart(bot)
        bot.lastBehavior = behavior
    elseif behavior.Validate(bot) then
        -- otherwise keep running the same one
        newState = behavior.OnRunning(bot)
    end

    if newState == STATUS.SUCCESS or newState == STATUS.FAILURE then
        -- if our current behavior is done, do cleanup
        if lastBehavior then lastBehavior.OnEnd(bot) end
        bot.lastBehavior = nil
        bot.lastState = nil

        if newState == STATUS.SUCCESS then
            behavior.OnSuccess(bot)
            behavior.OnEnd(bot)
        elseif newState == STATUS.FAILURE then
            behavior.OnFailure(bot)
            behavior.OnEnd(bot)
        end
    else
        -- otherwise set the lastState for the next tick
        bot.lastState = newState
    end
end

function TTTBots.Behaviors.CallTreeOnBots()
    for _, bot in ipairs(TTTBots.Bots) do
        TTTBots.Behaviors.CallTree(bot)
    end
end
