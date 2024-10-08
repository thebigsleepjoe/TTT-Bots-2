if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHERIFF then return false end

TEAM_INNOCENT = TEAM_INNOCENT or 'innocent'

local allyRoles = {
    deputy = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _bh.Defib,
    _bh.Defuse,
    _bh.CreateDeputy,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local sheriff = TTTBots.RoleData.New("sheriff", TEAM_INNOCENT)
sheriff:SetDefusesC4(true)
sheriff:SetCanHaveRadar(true)
sheriff:SetUsesSuspicion(true)
sheriff:SetTeam(TEAM_INNOCENT)
sheriff:SetBTree(bTree)
sheriff:SetAlliedRoles(allyRoles)
sheriff:SetLovesTeammates(true)
sheriff:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(sheriff)

return true
