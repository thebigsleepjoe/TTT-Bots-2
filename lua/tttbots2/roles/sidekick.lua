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

-- Sidekick help master when shooting a victim
hook.Add("TTTBotsOnWitnessFireBullets", "TTTBotsOnWitnessFireBullets", function(witness, attacker, data, angleDiff)
    local attackerRole = attacker:GetRoleStringRaw()
    local witnessRole = witness:GetRoleStringRaw()

    if witnessRole == 'sidekick' and attackerRole == 'jackal' then
        local eyeTracePos = attacker:GetEyeTrace().HitPos
        if not IsValid(eyeTracePos) then return end
        local target = TTTBots.Lib.GetClosest(TTTBots.Roles.GetNonAllies(witness), eyeTracePos)
        if not target then return end
        witness:SetAttackTarget(target)
    end
end)

-- Sidekick help its master when he's attacked
hook.Add("TTTBotsOnWitnessHurt", "TTTBotsOnWitnessHurt",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not IsValid(attacker) then return end

        local victimRole = victim:GetRoleStringRaw()
        local witnessRole = witness:GetRoleStringRaw()

        if witnessRole == 'sidekick' and victimRole == 'jackal' then
            witness:SetAttackTarget(attacker)
        end
    end)

return true
