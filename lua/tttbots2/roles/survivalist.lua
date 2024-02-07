if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SURVIVALIST then return false end

local survivalist = TTTBots.RoleData.New("survivalist")
survivalist:SetDefusesC4(true)
survivalist:SetTeam(TEAM_INNOCENT)
survivalist:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
survivalist:SetCanHide(true)
survivalist:SetCanSnipe(true)
survivalist:SetUsesSuspicion(true)
survivalist:SetAlliedRoles({})
survivalist:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(survivalist)

return true
