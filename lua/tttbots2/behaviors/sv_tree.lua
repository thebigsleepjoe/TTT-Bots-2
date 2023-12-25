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

---FIXME: Refactor this
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
            lastBehavior.OnEnd(bot)
            bot.lastBehavior = nil
        end

        if newState == STATUS.SUCCESS then
            lastBehavior.OnSuccess(bot)
        elseif newState == STATUS.FAILURE then
            lastBehavior.OnFailure(bot)
        end
    end

    return STATUS.FAILURE
end
