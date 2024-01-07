local detective = TTTBots.RoleData.New("detective")
detective:SetDefusesC4(true)
detective:SetCanHaveRadar(true)
detective:SetTeam(TEAM_INNOCENT)
detective:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
detective:SetUsesSuspicion(true)
detective:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(detective)

return true
