--[[
    This module directs traitors (evil players) to collaborate with one another during rounds.
]]

local PSTATE = {
    PREP = 1,
    EXECUTE = 3,
    ATWILL = 4,
}

---@class EvilCoordinator
TTTBots.EvilCoordinator = {
    RoundInfo = {
        Tick = 0,
        RoundState = PSTATE.PREP,
    }
}

local lib = TTTBots.Lib

local EvilCoordinator = TTTBots.EvilCoordinator

function EvilCoordinator.Tick() end
