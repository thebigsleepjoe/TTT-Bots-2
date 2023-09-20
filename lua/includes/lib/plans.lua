TTTBots.Plans = {
    PLANSTATES = {
        START = "Starting",    --- Initializing the plan.
        RUNNING = "Running",   --- Plan is in action.
        FINISHED = "Finished", --- Plan finished, everyone do your own thing.
        FAILED = "Failed",     --- Plan failed, everyone do your own thing.
        WAITING = "Waiting"    --- Waiting for round to start.
    },
    --- What a bot reports as its current state on its assigned ACTION
    BOTSTATES = {
        IDLE = "Idle/Preparing",   --- Idle or preparing to perform the assigned action.
        INPROGRESS = "InProgress", --- Attempting to perform the assigned action.
        FINISHED = "Finished",     --- Either failed or completed the action.
    },
    --- The actions assigned to a bot by the coordinator.
    ACTIONS = {
        PLANT = "PlantC4",       --- Plant C$ in a discreet location determined by the assigned bot.
        DEFUSE = "DefuseC4",     --- Defuse C4
        FOLLOW = "FollowPly",    --- Follow a target player peacefully (either a teammate or a future victim)
        GATHER = "Gather",       --- Gather with traitors around a position.
        ATTACK = "Attack",       --- Attack a certain target, or the nearest innocent if none specified.
        ATTACKANY = "AttackAny", --- Attack any player you can see that are on the enemy team.
        DEFEND = "Defend",       --- Defend a position from intruders, used after an attack order if we know others are around.
        ROAM = "Roam",           --- Roam around the map, primarily to be used for hunting players at low player counts.
        IGNORE = "Ignore",       --- Ignore orders. This is seldom used and is mainly for bots who ignore orders. (personality quirk)
    },
    --- A list of all things/people that can be targeted by a bot. Mosly calculated at runtime
    PLANTARGETS = {
        CALC_POPULAR_AREA = "CalculatedPopularArea", --- The most popular area, calculated by the coordinator.
        CALC_BOMBSPOT = "CalculatedBombSpot",        --- The best calculated bomb spot, calculated by the coordinator.
        RAND_FRIENDLY = "RandomFriendly",            --- A friendly player, selected randomly
        RAND_FRIENDLY_HUMAN = "RandomFriendlyHuman", --- A friendly human player, selected randomly
        RAND_ENEMY = "RandomEnemy",                  --- A non-traitor player, selected randomly
        RAND_POLICE = "RandomPolice",                --- A police player, selected randomly
        NEAREST_HIDINGSPOT = "NearestHidingSpot",    --- The nearest hiding spot
        FARTHEST_HIDINGSPOT = "FarthestHidingSpot",  --- The farthest hiding spot
        NEAREST_SNIPERSPOT = "NearestSniperSpot",    --- The nearest sniper spot
        FARTHEST_SNIPERSPOT = "FarthestSniperSpot",  --- The farthest sniper spot
        NOT_APPLICABLE = "N/A",                      --- Not applicable, used for actions that don't require a target.
    },
    BotStatuses = {},
    CurrentPlanState = "",
}
include("includes/data/planpresets.lua") --- Load data into TTTBots.Plans.PRESETS

function TTTBots.Plans.IsRoundActive()
    return TTTBots.Match.RoundActive
end

--- When a bot wants to share the status with this module (bot->server), it will call this function.
function TTTBots.Plans.BotUpdateStatus(bot, status)
    local tbl = {
        bot = bot,
        status = status,
    }
    TTTBots.Plans.BotStatuses[bot] = tbl
end

--- Return the BOTSTATUS string of the bot's table within BotStatuses, else nil.
function TTTBots.Plans.GetBotState(bot)
    local tbl = TTTBots.Plans.BotStatuses[bot]
    if not tbl then return nil end
    return tbl.status
end

function TTTBots.Plans.Cleanup()
    TTTBots.Plans.BotStatuses = {}
    TTTBots.Plans.CurrentPlanState = "Waiting"
end

TTTBots.Plans.Cleanup() -- Call when this is first executed

function TTTBots.Plans.Tick()
    if not TTTBots.Plans.IsRoundActive() then
        TTTBots.Plans.Cleanup()
        return
    end
    -- TODO: Implement this.
end
