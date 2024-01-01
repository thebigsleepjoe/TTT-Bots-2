if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JESTER then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
}

local Bhvr = TTTBots.Behaviors
local bTree = {
    Bhvr.ClearBreakables,
    Bhvr.AttackTarget,
    Bhvr.UseHealthStation,
    Bhvr.FindWeapon,
    Bhvr.Stalk,
    Bhvr.InvestigateNoise,
    Bhvr.Follow,
    Bhvr.Wander,
}

local jester = TTTBots.RoleData.New("jester", TEAM_JESTER)
jester:SetDefusesC4(false)
jester:SetStartsFights(true)
jester:SetTeam(TEAM_JESTER)
jester:SetBTree(bTree)
jester:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(jester)

-- TTTBotsModifySuspicion hook
hook.Add("TTTBotsModifySuspicion", "TTTBots.jester.sus", function(bot, target, reason, mult)
    local role = target:GetRoleStringRaw()
    if role == 'jester' then
        if TTTBots.Lib.GetConVarBool("cheat_know_jester") then
            return mult * 0.3
        end
    end
end)

return true
