if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHERIFF then return false end

local allyRoles = {
    sheriff = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _bh.Defuse,
    _prior.Restore,
    _prior.Minge,
    _bh.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local deputy = TTTBots.RoleData.New("deputy", TEAM_INNOCENT)
deputy:SetDefusesC4(true)
deputy:SetCanCoordinate(false)
deputy:SetStartsFights(false)
deputy:SetUsesSuspicion(true)
deputy:SetTeam(TEAM_INNOCENT)
deputy:SetBTree(bTree)
deputy:SetLovesTeammates(true)
deputy:SetAppearsPolice(true)
deputy:SetAlliedRoles(allyRoles)
TTTBots.Roles.RegisterRole(deputy)

-- Deputy helps sheriff when shooting/attacked
TTTBots.Lib.RegisterMasterMinionHooks("deputy", "sheriff", "TTTBots_Deputy")

return true
