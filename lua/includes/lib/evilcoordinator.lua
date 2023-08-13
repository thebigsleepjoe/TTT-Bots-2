--[[
    This module directs traitors (evil players) to collaborate with one another during rounds.
]]

---@class ACT : table
local ACT = {
    GATHER = 1, --- Gather the bots at a location
    ATTACK = 2, --- Attack a certain target
    DEFEND = 3, --- Defend a location
    ROAM = 4,   --- Roam around the map
}

---@class EvilCoordinator
TTTBots.EvilCoordinator = {
    ---@class RoundInfo : table
    ---@field public Tick number
    ---@field public ActionGoal number
    ---@field public BotActions table<number, number>
    ---@field public Started boolean
    RoundInfo = {
        --- Reset RoundInfo stats to default values
        ---@see RoundInfo
        Reset = function(self, started)
            self.Tick = 0
            self.ActionGoal = ACT.GATHER
            self.BotActions = {}
            self.Started = started or false
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
    -- TODO: do some logic here or something
end

hook.Add("TTTBeginRound", "TTTBots.EvilCoordinator.OnRoundStart", EvilCoordinator.OnRoundStart)

function EvilCoordinator.OnRoundEnd()
    RoundInfo:Reset(false)
    -- TODO: do some logic here or something
end

hook.Add("TTTEndRound", "TTTBots.EvilCoordinator.OnRoundEnd", EvilCoordinator.OnRoundEnd)

function EvilCoordinator.Tick()
    if RoundInfo.Tick == 0 then EvilCoordinator.Init() end
    if not RoundInfo.Started then return end
    print("EvilCoordinator.Tick")
end
