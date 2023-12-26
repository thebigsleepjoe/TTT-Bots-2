if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SERIALKILLER then return false end

local allyTeams = { TEAM_SERIALKILLER = true }

local serialkiller = TTTBots.RoleData.New("serialkiller", TEAM_SERIALKILLER)
serialkiller:SetDefusesC4(true)
serialkiller:SetStartsFights(true)
serialkiller:SetTeam(TEAM_SERIALKILLER)
serialkiller:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent) -- TODO: Btree for serialkiller
serialkiller:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(serialkiller)

return true
