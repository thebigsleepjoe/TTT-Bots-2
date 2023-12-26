if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_NONE then return false end

local none = TTTBots.RoleData.New("none")
none:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
none:SetUsesSuspicion(false)
none:SetIsFollower(false)
TTTBots.Roles.RegisterRole(none)

return true
