if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SIDEKICK then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
}

local allyRoles = {
    jackal = true
}

local Bhvr = TTTBots.Behaviors
local bTree = {
    Bhvr.ClearBreakables,
    Bhvr.AttackTarget,
    Bhvr.FollowMaster,
    Bhvr.Follow,
    Bhvr.Wander,
}

local sidekick = TTTBots.RoleData.New("sidekick", TEAM_SIDEKICK)
sidekick:SetDefusesC4(false)
sidekick:SetCanCoordinate(false)
sidekick:SetStartsFights(false)
sidekick:SetUsesSuspicion(false)
sidekick:SetTeam(TEAM_SIDEKICK)
sidekick:SetAlliedTeams(allyTeams)
sidekick:SetBTree(bTree)
TTTBots.Roles.RegisterRole(sidekick)

return true
