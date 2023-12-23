--- This module is an abstraction layer for TTT/2 compatibility. TTT2 does provide a lot of functionality for this,
--- but TTT does not.

TTTBots.Roles = {}

local lib = TTTBots.Lib
TTTBots.Roles.m_roles = {}

include("sv_roledata.lua")
include("sv_buyables.lua")

function TTTBots.Roles.RegisterRole(roleData, priority)
    TTTBots.Roles.m_roles[roleData:GetName()] = roleData
end

--- Return a role by its name.
---@param name string
---@return table<RoleData>|nil
function TTTBots.Roles.GetRole(name) return TTTBots.Roles.m_roles[name] end

--- Return a comprehensive table of the defined roles.
---@return table<RoleData>
function TTTBots.Roles.GetRoles() return TTTBots.Roles.m_roles end

function TTTBots.Roles.GetTeamMembers(player)
    -- TODO: Use GetRoleString and check if there are any defined RoleDatas for this role.
    -- If not then just error out.
end

--- Registers the TTT default roles. traitor, detective, innocent
function TTTBots.Roles.RegisterDefaultRoles()
    local traitor = TTTBots.RoleData.New("traitor")
    traitor:SetDefusesC4(false)
    traitor:SetPlantsC4(true)
    traitor:SetCanHaveRadar(true)
    traitor:SetCanCoordinate(true)
    traitor:SetKillsNonAllies(true)
    traitor:SetTeam(TEAM_TRAITOR)
    TTTBots.Roles.RegisterRole(traitor)

    local detective = TTTBots.RoleData.New("detective")
    detective:SetDefusesC4(true)
    detective:SetCanHaveRadar(true)
    detective:SetTeam(TEAM_INNOCENT)
    TTTBots.Roles.RegisterRole(detective)

    local innocent = TTTBots.RoleData.New("innocent")
    innocent:SetDefusesC4(true)
    innocent:SetTeam(TEAM_INNOCENT)
    TTTBots.Roles.RegisterRole(innocent)
end

function TTTBots.Roles.GenerateRegisterForRole(customRole)
    -- TODO: Write this, probably rename this function as well
end

TTTBots.Roles.RegisterDefaultRoles()