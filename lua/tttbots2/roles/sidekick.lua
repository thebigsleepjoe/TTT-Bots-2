if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SIDEKICK then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
}

local allyRoles = {
    jackal = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Restore,
    _bh.FollowMaster,
    _prior.Minge,
    _prior.Patrol
}

local sidekick = TTTBots.RoleData.New("sidekick", TEAM_SIDEKICK)
sidekick:SetDefusesC4(false)
sidekick:SetCanCoordinate(false)
sidekick:SetStartsFights(false)
sidekick:SetUsesSuspicion(false)
sidekick:SetTeam(TEAM_SIDEKICK)
sidekick:SetAlliedTeams(allyTeams)
sidekick:SetBTree(bTree)
sidekick:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(sidekick)

-- Sidekick helps jackal when shooting/attacked
TTTBots.Lib.RegisterMasterMinionHooks("sidekick", "jackal", "TTTBots_Sidekick")

return true
