if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HITMAN then return false end

local allyTeams = {
    TEAM_TRAITOR = true,
    TEAM_JESTER = true,
}

local hitman = TTTBots.RoleData.New("hitman", TEAM_TRAITOR)
hitman:SetDefusesC4(false)
hitman:SetPlantsC4(false)
hitman:SetCanHaveRadar(true)
hitman:SetCanCoordinate(false)
hitman:SetStartsFights(false)
hitman:SetTeam(TEAM_TRAITOR)
hitman:SetUsesSuspicion(false)
hitman:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor) -- TODO: Btree for hitman
hitman:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(hitman)

return true
