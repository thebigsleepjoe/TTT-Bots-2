if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPEEDRUNNER then return false end

--- Speedrunner: A public evil role with enhanced speed, jump height, and fire rate.
--- Must kill all other players before their timer runs out. Respawns on death
--- while the timer is active. Uses the FuseHunt behavior for aggressive target hunting.

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_SPEEDRUNNER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.FightBack,           -- Always fight back
    _bh.FuseHunt,               -- PRIMARY: urgently hunt and engage targets
    _bh.Stalk,                  -- Fallback: stalk someone if FuseHunt can't find a target
    _prior.Restore,             -- Quick heal between kills
    _prior.Minge,               -- Occasional minging
    _prior.Investigate,         -- Investigate noises (might find a target)
    _prior.Patrol               -- Patrol when nothing else to do
}

local speedrunner = TTTBots.RoleData.New("speedrunner", TEAM_SPEEDRUNNER)
speedrunner:SetDefusesC4(false)              -- Focused on direct combat
speedrunner:SetPlantsC4(false)               -- No C4 — speed kills only
speedrunner:SetCanHaveRadar(true)            -- Helps find targets faster
speedrunner:SetCanCoordinate(false)          -- Solo role
speedrunner:SetStartsFights(true)            -- Very aggressive
speedrunner:SetTeam(TEAM_SPEEDRUNNER)
speedrunner:SetUsesSuspicion(false)          -- Public evil, everyone knows
speedrunner:SetKnowsLifeStates(true)         -- Needs to track remaining players
speedrunner:SetBTree(bTree)
speedrunner:SetAlliedTeams(allyTeams)
speedrunner:SetLovesTeammates(true)
speedrunner:SetCanSnipe(true)                -- Will use any weapon
speedrunner:SetCanHide(false)                -- No time for hiding — must be aggressive
TTTBots.Roles.RegisterRole(speedrunner)

return true
