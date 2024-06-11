if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BODYGUARD then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Bodyguard
}

local bodyguard = TTTBots.RoleData.New("bodyguard", TEAM_NONE)
bodyguard:SetDefusesC4(false)
bodyguard:SetPlantsC4(false)
bodyguard:SetCanHaveRadar(false)
bodyguard:SetCanCoordinate(false)
bodyguard:SetStartsFights(false)
bodyguard:SetUsesSuspicion(false)
bodyguard:SetBTree(bTree)
bodyguard:SetAlliedTeams({})
bodyguard:SetCanSnipe(false)
bodyguard:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(bodyguard)

return true
