TTTBots.Behaviors = {}

---@enum BStatus
TTTBots.STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

TTTBots.Lib.IncludeDirectory("tttbots2/behaviors")

---@alias Tree table<BBase|Tree>

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

---@type table<string, Tree>
TTTBots.Behaviors.DefaultTrees = {
    innocent = {
        _prior.FightBack,
        _bh.Defuse,
        _prior.Restore,
        _bh.Interact,
        _prior.Investigate,
        _prior.Minge,
        _bh.Decrowd,
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
        _bh.Decrowd,
        _prior.Patrol
    }
}
TTTBots.Behaviors.DefaultTreesByTeam = {
    [TEAM_TRAITOR] = TTTBots.Behaviors.DefaultTrees.traitor,
    [TEAM_INNOCENT] = TTTBots.Behaviors.DefaultTrees.innocent,
    [TEAM_NONE] = TTTBots.Behaviors.DefaultTrees.innocent,
}

local STATUS = TTTBots.STATUS

---@class Bot
---@field lastBehavior BBase?

--- Returns the highest priority tree that has a callback which returned true on this bot.
---@param bot Bot
---@return Tree
function TTTBots.Behaviors.GetTreeFor(bot)
    return TTTBots.Roles.GetRoleFor(bot):GetBTree()
end

--- Iterates over the node (or Tree if you're pedantic)
--- and performs logic accordingly. Can set bot.lastBehavior if successful
---@param bot Bot
---@param tree Tree
---@return boolean yield Should we stop any further calls?
function TTTBots.Behaviors.IterateNode(bot, tree)
    local lastBehavior = bot.lastBehavior
    -- Iterate through each node in this tree to see if we can find something that will work.
    for _, node in ipairs(tree) do
        if node.Validate == nil then
            -- If validate is nil then this is another Tree within this Tree, which is acceptable.
            local yield = TTTBots.Behaviors.IterateNode(bot, node)
            if yield then return true end

            -- If our tree-child didn't want us to yield, let's keep iterating through our other kiddos.
            -- Continue to the next node.
            continue
        end

        ---@cast node BBase
        local valid = node.Validate(bot)
        if not valid then continue end

        if lastBehavior == node then
            -- If we have already ran this action once just now, then try OnRunning instead.
            local ranResult = node.OnRunning(bot)

            if ranResult == STATUS.RUNNING then
                return true
            elseif ranResult == STATUS.FAILURE then
                bot.lastBehavior = nil
                node.OnFailure(bot)
                node.OnEnd(bot)
            elseif ranResult == STATUS.SUCCESS then
                bot.lastBehavior = nil
                node.OnSuccess(bot)
                node.OnEnd(bot)
            end

            return true
        end

        if lastBehavior ~= nil then
            -- If we have a last behavior, then we need to end it.
            lastBehavior.OnFailure(bot)
            lastBehavior.OnEnd(bot)
        end

        -- We just got here. Run OnStart.
        node.OnStart(bot)
        bot.lastBehavior = node

        return true
    end

    return false
end

---Executes the tree of a bot
---@param bot Bot
---@param tree Tree
function TTTBots.Behaviors.RunTree(bot, tree)
    local lastBehavior = bot.lastBehavior

    -- Obligatory nil-safety.
    if not (bot and IsValid(bot)) then return end
    if not bot.initialized then return end

    -- If we have a behavior that is currently running and cannot be suddenly stopped, then we must
    -- try to run it again and see what happens.
    if lastBehavior and not lastBehavior.Interruptible then
        local result = lastBehavior.OnRunning(bot)
        if result == STATUS.RUNNING then return end
    end

    -- Now we've either finished the last behavior or it was interruptible.
    -- Try running the tree.
    TTTBots.Behaviors.IterateNode(bot, tree)
end

function TTTBots.Behaviors.RunTreeOnBots()
    for _, bot in ipairs(TTTBots.Bots) do
        TTTBots.Behaviors.RunTree(
            bot,
            TTTBots.Behaviors.GetTreeFor(bot)
        )
    end
end


timer.Create("TTTBots.Debug.Brain", 0.5, 0, function()
    if not TTTBots.DebugServer then return end
    if not TTTBots.Lib.GetConVarBool("debug_brain") then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (bot and IsValid(bot)) then continue end
        if not (TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        if not (bot.lastBehavior and bot.lastBehavior.Name) then continue end

        TTTBots.DebugServer.DrawText(
            bot:GetPos(),
            bot:Nick() .. ": " .. bot.lastBehavior.Name,
            0.5,
            bot:Nick() .. "_behavior"
        )
    end
end)