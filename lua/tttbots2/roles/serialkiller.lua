if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SERIALKILLER then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_SERIALKILLER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Patrol
}

local serialkiller = TTTBots.RoleData.New("serialkiller", TEAM_SERIALKILLER)
serialkiller:SetDefusesC4(true)
serialkiller:SetStartsFights(true)
serialkiller:SetTeam(TEAM_SERIALKILLER)
serialkiller:SetBTree(bTree)
serialkiller:SetKnowsLifeStates(true)
serialkiller:SetAlliedTeams(allyTeams)
serialkiller:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(serialkiller)

return true
