if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HITMAN then return false end

local allyTeams = {
    TEAM_TRAITOR = true,
    TEAM_JESTER = true,
}

local traitor = TTTBots.RoleData.New("traitor", TEAM_TRAITOR)
traitor:SetDefusesC4(false)
traitor:SetPlantsC4(false)
traitor:SetCanHaveRadar(true)
traitor:SetCanCoordinate(false)
traitor:SetStartsFights(false)
traitor:SetTeam(TEAM_TRAITOR)
traitor:SetUsesSuspicion(false)
traitor:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor) -- TODO: Btree for hitman
traitor:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(traitor)

return true
