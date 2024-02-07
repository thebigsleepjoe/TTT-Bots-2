if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JESTER then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
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
