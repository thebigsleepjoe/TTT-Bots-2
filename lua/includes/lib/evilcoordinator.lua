--[[
    This module directs traitors (evil players) to collaborate with one another during rounds.
]]

---@enum ACT
local ACT = {
    GATHER = "GATHER",       --- Gather the bots at a location
    ATTACK = "ATTACK",       --- Attack a certain target
    DEFEND = "DEFEND",       --- Defend a location
    ROAM = "ROAM",           --- Roam around the map
    IGNORE = "IGNORE",       --- Ignore our instructions (used for bots w certain personality types)
    ATTACKALL = "ATTACKALL", --- Attack all players you can see
}

---@class EvilCoordinator
TTTBots.EvilCoordinator = {
    ---@class RoundInfo : table
    ---@field public Tick number The current tick of the round
    ---@field public ActionGoal ACT ACT
    ---@field public BotActions table<Player, ACT> Bot index to action
    ---@field public Started boolean Whether the round has started or not
    ---@field public MeetingPos Vector Where the evil bots are gathering
    ---@field public RoundStartTime number The CurTime the round started at
    ---@field public TimeThreshold number The time before we stop doing the GATHER action.
    RoundInfo = {
        --- Reset RoundInfo stats to default values
        ---@see RoundInfo
        Reset = function(self, started)
            self.ActionGoal = ACT.GATHER
            self.BotActions = {}
            self.Started = started or false
            self.MeetingPos = nil
            self.RoundStartTime = CurTime()
            self.TimeThreshold = math.random(20, 40)
        end,
        TimeSinceStart = function(self)
            return CurTime() - self.RoundStartTime
        end,
    }
}


local lib = TTTBots.Lib

---@class EvilCoordinator
local EvilCoordinator = TTTBots.EvilCoordinator
---@type RoundInfo
local RoundInfo = EvilCoordinator.RoundInfo

function EvilCoordinator.Init()
    RoundInfo:Reset()
end

--- Wrapper to set RoundInfo.ActionGoal and maybe call something else in the future
---@param action ACT
---@return ACT Action The same as param action.
function EvilCoordinator.SetAllAction(action)
    if RoundInfo.ACtionGoal == action then return action end
    local isDebug = lib.GetConVarBool("debug_evil")
    if isDebug then
        print(string.format("Evil Coordinator: Commanding bots to do %s", action or "<UNDEFINED>"))
    end
    RoundInfo.ActionGoal = action
    return action
end

--- Get the orders for a bot, as assigned per the coordinator.
--- TODO: Implement this properly later.
function EvilCoordinator.GetOrders(bot)
    return RoundInfo.ActionGoal
end

--- Equivalent to EvilCoordinator.RoundInfo.MeetingPos
function EvilCoordinator.GetGatherPos()
    return RoundInfo.MeetingPos
end

function EvilCoordinator.CommandBots()
    if RoundInfo.ActionGoal == ACT.ATTACKALL then return end -- We have already decided to attack all players. No need to do anything fancy
    local evilBots = lib.GetAliveEvilBots()
    local numEvil = #evilBots
    if numEvil == 1 then -- No need to coordinate a single bot.
        return EvilCoordinator.SetAllAction(ACT.ATTACKALL)
    end

    if RoundInfo:TimeSinceStart() > RoundInfo.TimeThreshold then
        return EvilCoordinator.SetAllAction(ACT.ATTACKALL)
    else
        return EvilCoordinator.SetAllAction(ACT.GATHER)
    end
end

function EvilCoordinator.OnRoundStart()
    RoundInfo:Reset(true)
    local meetingArea = table.Random(lib.GetNavsOfGreaterArea(1000) or navmesh.GetAllNavAreas() or {})
    if IsValid(meetingArea) then
        RoundInfo.MeetingPos = meetingArea:GetCenter()
    end
end

hook.Add("TTTBeginRound", "TTTBots.EvilCoordinator.OnRoundStart", EvilCoordinator.OnRoundStart)

function EvilCoordinator.OnRoundEnd()
    RoundInfo:Reset(false)
end

hook.Add("TTTEndRound", "TTTBots.EvilCoordinator.OnRoundEnd", EvilCoordinator.OnRoundEnd)

function EvilCoordinator.Tick()
    RoundInfo.Tick = (RoundInfo.Tick or 0) + 1
    if RoundInfo.Tick == 1 then EvilCoordinator.Init() end
    if not RoundInfo.Started then
        return
    end
    EvilCoordinator.CommandBots()
end
