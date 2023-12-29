if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JESTER then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
}

local jester = TTTBots.RoleData.New("jester", TEAM_JESTER)
jester:SetDefusesC4(false)
jester:SetCanCoordinate(false)
jester:SetStartsFights(true)
jester:SetTeam(TEAM_JESTER)
jester:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
jester:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(jester)

return true
