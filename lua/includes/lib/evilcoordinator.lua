--[[
    This module directs traitors (evil players) to collaborate with one another during rounds.
]]

---@enum ACT
local ACT = {
    GATHER = 1,    --- Gather the bots at a location
    ATTACK = 2,    --- Attack a certain target
    DEFEND = 3,    --- Defend a location
    ROAM = 4,      --- Roam around the map
    IGNORE = 5,    --- Ignore our instructions (used for bots w certain personality types)
    ATTACKALL = 6, --- Attack all players you can see
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
    RoundInfo = {
        --- Reset RoundInfo stats to default values
        ---@see RoundInfo
        Reset = function(self, started)
            self.Tick = 0
            self.ActionGoal = ACT.GATHER
            self.BotActions = {}
            self.Started = started or false
            self.MeetingPos = nil
            self.RoundStartTime = CurTime()
            self.TimeThreshold = math.random(20, 50) -- The time before we stop doing the GATHER action.
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

function EvilCoordinator.OnRoundStart()
    RoundInfo:Reset(true)
    local meetingArea = table.Random(lib.GetNavsOfGreaterArea(1000) or navmesh.GetAllNavAreas() or {})
    if IsValid(meetingArea) then
        RoundInfo.MeetingPos = meetingArea:GetCenter()
    end
end

--- Wrapper to set RoundInfo.ActionGoal and maybe call something else in the future
function EvilCoordinator.SetAllAction(action)
    RoundInfo.ActionGoal = action
end

function EvilCoordinator.CommandBots()
    if RoundInfo.ActionGoal == ACT.ATTACKALL then return end -- We have already decided to attack all players. No need to do anything fancy
    local evilBots = lib.GetAliveEvilBots()
    local numEvil = #evilBots
    if #numEvil == 1 then -- No need to coordinate a single bot.
        RoundInfo.ActionGoal = ACT.ATTACKALL
        return
    end

    -- TODO: Logic for gathering, attacking, etc.
end

hook.Add("TTTBeginRound", "TTTBots.EvilCoordinator.OnRoundStart", EvilCoordinator.OnRoundStart)

function EvilCoordinator.OnRoundEnd()
    RoundInfo:Reset(false)
end

hook.Add("TTTEndRound", "TTTBots.EvilCoordinator.OnRoundEnd", EvilCoordinator.OnRoundEnd)

function EvilCoordinator.Tick()
    if RoundInfo.Tick == 0 then EvilCoordinator.Init() end
    if not RoundInfo.Started then return end
    print("EvilCoordinator.Tick")
    EvilCoordinator.CommandBots()
end
