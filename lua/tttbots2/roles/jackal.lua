if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JACKAL then return false end

local allyTeams = {
    TEAM_JESTER = true,
    TEAM_JACKAL = true,
}

local Bhvr = TTTBots.Behaviors
local bTree = {
    Bhvr.ClearBreakables,
    Bhvr.CreateSidekick,
    Bhvr.AttackTarget,
    Bhvr.Follow,
    Bhvr.Wander,
}

local jackal = TTTBots.RoleData.New("jackal", TEAM_JACKAL)
jackal:SetDefusesC4(false)
jackal:SetCanCoordinate(false)
jackal:SetStartsFights(true)
jackal:SetTeam(TEAM_JACKAL)
jackal:SetBTree(bTree)
jackal:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(jackal)

return true
