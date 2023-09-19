TTTBots.Plans = {
    PLANSTATES = {
        START = "Starting",    --- Initializing the plan
        RUNNING = "Running",   --- Plan is in action
        FINISHED = "Finished", --- Plan finished, everyone do your own thing.
        FAILED = "Failed"      --- Plan failed, everyone do your own thing.
    },
    BOTSTATES = {
        IDLE = "Idle",
        INPROGRESS = "InProgress",
        FINISHED = "Finished",
    },
    ACTIONS = {
        PLANT = "PlantC4",
        DEFUSE = "DefuseC4",
        FOLLOW_PLY = "FollowPly",
    },
    BotStatuses = {},
}

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

function TTTBots.Plans.Cleanup()
    TTTBots.Plans.BotStatuses = {}
end

function TTTBots.Plans.Tick()
    if not TTTBots.Plans.IsRoundActive() then
        TTTBots.Plans.Cleanup()
        return
    end
    -- TODO: Implement this.
end
