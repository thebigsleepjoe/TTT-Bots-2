local allyTeams = {
    [TEAM_TRAITOR] = true,
    [TEAM_JESTER or 'jesters'] = true,
}

local traitor = TTTBots.RoleData.New("traitor", TEAM_TRAITOR)
traitor:SetDefusesC4(false)
traitor:SetPlantsC4(true)
traitor:SetCanHaveRadar(true)
traitor:SetCanCoordinate(true)
traitor:SetStartsFights(true)
traitor:SetTeam(TEAM_TRAITOR)
traitor:SetUsesSuspicion(false)
traitor:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
traitor:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(traitor)

return true
