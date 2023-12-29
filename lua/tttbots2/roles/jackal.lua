if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JACKAL then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_JACKAL] = true,
}
local allyRoles = {
    sidekick = true
}

local Bhvr = TTTBots.Behaviors
local bTree = {
    Bhvr.ClearBreakables,
    Bhvr.CreateSidekick,
    Bhvr.AttackTarget,
    Bhvr.Stalk,
    Bhvr.Follow,
    Bhvr.Wander,
}

local jackal = TTTBots.RoleData.New("jackal", TEAM_JACKAL)
jackal:SetDefusesC4(false)
jackal:SetCanCoordinate(false)
jackal:SetStartsFights(false)
jackal:SetUsesSuspicion(false)
jackal:SetTeam(TEAM_JACKAL)
jackal:SetBTree(bTree)
jackal:SetAlliedTeams(allyTeams)
jackal:SetAlliedRoles(allyRoles)
TTTBots.Roles.RegisterRole(jackal)

return true
