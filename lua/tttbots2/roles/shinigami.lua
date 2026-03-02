if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHINIGAMI then return false end

--- Shinigami: An innocent-team role that respawns after death with a knife,
--- enhanced speed, and constant health drain. Before death, acts as a normal
--- innocent. After respawn, the addon handles the special mechanics (speed,
--- knife, health loss). Stalk behavior helps the bot be aggressive post-respawn.

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.FightBack,
    _bh.Defuse,
    _prior.Restore,
    _bh.Stalk,
    _prior.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local shinigami = TTTBots.RoleData.New("shinigami", TEAM_INNOCENT)
shinigami:SetDefusesC4(true)
shinigami:SetTeam(TEAM_INNOCENT)
shinigami:SetBTree(bTree)
shinigami:SetCanHide(true)
shinigami:SetCanSnipe(true)
shinigami:SetUsesSuspicion(true)
shinigami:SetAlliedRoles({})
shinigami:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(shinigami)

return true
