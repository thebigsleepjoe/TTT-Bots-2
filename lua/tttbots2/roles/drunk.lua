if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DRUNK then return false end

-- Drunk is extremely simple. Just stay out of trouble until you get your real role. -Z
local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
}

local drunk = TTTBots.RoleData.New("drunk")
drunk:SetDefusesC4(false)
drunk:SetTeam(TEAM_NONE)
drunk:SetBTree(bTree)
drunk:SetCanHide(true)
drunk:SetCanSnipe(true)
drunk:SetUsesSuspicion(false)
drunk:SetAlliedRoles({})
drunk:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(drunk)

return true
