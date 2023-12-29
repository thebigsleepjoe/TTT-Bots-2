if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SERIALKILLER then return false end

local allyTeams = {
    [TEAM_SERIALKILLER] = true,
    [TEAM_JESTER] = true,
}

local Bhvr = TTTBots.Behaviors
local bTree = {
    Bhvr.ClearBreakables,
    Bhvr.AttackTarget,
    Bhvr.Stalk,
    Bhvr.Wander,
}

local serialkiller = TTTBots.RoleData.New("serialkiller", TEAM_SERIALKILLER)
serialkiller:SetDefusesC4(true)
serialkiller:SetStartsFights(true)
serialkiller:SetTeam(TEAM_SERIALKILLER)
serialkiller:SetBTree(bTree)
serialkiller:SetKnowsLifeStates(true)
serialkiller:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(serialkiller)

return true
