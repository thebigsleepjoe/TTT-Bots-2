---@class BehaviorTree
---@field Priority number A number priority for this tree to be selected. Higher numbers = highest priority.
---@field Conditions function A function, passed the Player (bot) it's called on, that determines (true/false) if the bot should use this tree.
---@field Behaviors table A table of behaviors to run if the conditions are met. This functions as a Priority node.


TTTBots.Behaviors = {}

include("tttbots2/behaviors/sv_wander.lua")
include("tttbots2/behaviors/sv_findweapon.lua")
include("tttbots2/behaviors/sv_clearbreakables.lua")
include("tttbots2/behaviors/sv_attacktarget.lua")
include("tttbots2/behaviors/sv_investigatenoise.lua")
include("tttbots2/behaviors/sv_investigatecorpse.lua")
include("tttbots2/behaviors/sv_follow.lua")
include("tttbots2/behaviors/sv_followplan.lua")
include("tttbots2/behaviors/sv_defuse.lua")
include("tttbots2/behaviors/sv_plantbomb.lua")
include("tttbots2/behaviors/sv_usehealthstation.lua")

local b = TTTBots.Behaviors

---@type table<string, BehaviorTree>
TTTBots.Behaviors.Trees = {
    Innocent = {
        Priority = -1,
        Conditions = function(ply) return true end,
        Behaviors = {
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
    },
    Evil = {
        Priority = 0,
        Conditions = function(ply) return TTTBots.Lib.IsEvil(ply) end,
        Behaviors = {
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
        }
    },
    Detective = {
        Priority = 0,
        Conditions = function(ply) return TTTBots.Lib.IsPolice(ply) end,
        Behaviors = {
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
}

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- Returns the highest priority tree that has a callback which returned true on this bot.
---@param ply Player
function TTTBots.Behaviors.GetTreeFor(ply)
    local trees = TTTBots.Behaviors.Trees
    local highestPriority = -math.huge
    local highestPriorityTree

    for name, tree in pairs(trees) do
        if tree.Priority > highestPriority and tree.Conditions(ply) then
            highestPriority = tree.Priority
            highestPriorityTree = tree
        end
    end

    return highestPriorityTree
end

--- Add a behavior tree to the list of possible trees. This is useful for modders wanting to modify TTT bot behavior trees. Namely, this is useful for custom roles.
---@param name string The name of the tree. This is used to reference the tree later.
---@param priority number A number priority for this tree to be selected. Higher numbers = highest priority. TTT Bots uses <= 0 for its default trees. Just make yours 1 or higher.
---@param condition function A true/false function that determines if the bot should use this tree. Is passed the player (bot) it's called on.
---@param tree table<table> A table of behaviors. First come, first served.
---@return BehaviorTree tree The tree which was created.
function TTTBots.Behaviors.CreateBehaviorTree(name, priority, condition, tree)
    local tree = {
        Priority = priority,
        Conditions = condition,
        Behaviors = tree
    }

    TTTBots.Behaviors.Trees[name] = tree

    return tree
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

        local tree = TTTBots.Behaviors.GetTreeFor(bot).Behaviors
        local lastBehavior = bot.lastBehavior
        local lastStatus = bot.lastBStatus
        local lastIsInterruptable = lastBehavior and lastBehavior.Interruptible
        local lastIsOver = not (lastStatus and lastStatus == STATUS.RUNNING)

        local currentBehavior = nil
        local behaviorChanged = false

        if not (lastIsOver or lastIsInterruptable) then
            currentBehavior = lastBehavior
        else
            local firstValid = TTTBots.Behaviors.GetFirstValid(tree, bot)
            if not firstValid then return STATUS.FAILURE end
            behaviorChanged = firstValid ~= lastBehavior
            currentBehavior = firstValid
        end

        local newState = STATUS.FAILURE

        if behaviorChanged then
            newState = currentBehavior.OnStart(bot)
        elseif lastStatus == STATUS.RUNNING then
            newState = currentBehavior.OnRunning(bot)
        end

        if newState == STATUS.SUCCESS or newState == STATUS.FAILURE then
            currentBehavior.OnEnd(bot)
            bot.lastBehavior = nil
        else
            bot.lastBehavior = currentBehavior
        end

        if newState == STATUS.SUCCESS then
            currentBehavior.OnSuccess(bot)
        elseif newState == STATUS.FAILURE then
            currentBehavior.OnFailure(bot)
        end

        bot.lastBStatus = newState
    end

    return STATUS.FAILURE
end
