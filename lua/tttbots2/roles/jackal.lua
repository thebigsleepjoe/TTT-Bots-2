if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JACKAL then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_JACKAL] = true,
}
local allyRoles = {
    sidekick = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _bh.CreateSidekick,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local jackal = TTTBots.RoleData.New("jackal", TEAM_JACKAL)
jackal:SetDefusesC4(false)
jackal:SetCanCoordinate(false)
jackal:SetStartsFights(true)
jackal:SetUsesSuspicion(false)
jackal:SetTeam(TEAM_JACKAL)
jackal:SetBTree(bTree)
jackal:SetAlliedTeams(allyTeams)
jackal:SetAlliedRoles(allyRoles)
TTTBots.Roles.RegisterRole(jackal)

return true
