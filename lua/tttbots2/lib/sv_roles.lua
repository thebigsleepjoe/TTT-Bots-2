--- This module is an abstraction layer for TTT/2 compatibility.

TTTBots.Roles = {}

local lib = TTTBots.Lib
TTTBots.Roles.m_roles = {}

include("sv_roledata.lua")

function TTTBots.Roles.RegisterRole(roleData, priority)
    TTTBots.Roles.m_roles[roleData:GetName()] = roleData
end

--- Return a role by its name.
---@param name string
---@return RoleData
function TTTBots.Roles.GetRole(name)
    return TTTBots.Roles.m_roles[name] or TTTBots.Roles.m_roles["default"]
end

---Returns the RoleData of the player, else nil if it doesn't exist.
---@param ply Player
---@return RoleData
function TTTBots.Roles.GetRoleFor(ply)
    local roleString = ply:GetRoleStringRaw()
    return TTTBots.Roles.GetRole(roleString)
end

--- Return a comprehensive table of the defined roles.
---@return table<RoleData>
function TTTBots.Roles.GetRoles() return TTTBots.Roles.m_roles end

function TTTBots.Roles.GetTeamMembers(player)
    -- TODO: Use GetRoleString and check if there are any defined RoleDatas for this role.
    -- If not then just error out.
end

function TTTBots.Roles.IsAllies(ply1, ply2)
    -- TODO: Write this. Check if allies or if team value is equivalent -- can't just use InSameTeam
end

--- Registers the TTT default roles. traitor, detective, innocent
function TTTBots.Roles.RegisterDefaultRoles()
    -- A generic role to default back to if we can't find a role.
    local default = TTTBots.RoleData.New("default")
    default:SetTeam(TEAM_INNOCENT)
    TTTBots.Roles.RegisterRole(default)

    local traitor = TTTBots.RoleData.New("traitor")
    traitor:SetDefusesC4(false)
    traitor:SetPlantsC4(true)
    traitor:SetCanHaveRadar(true)
    traitor:SetCanCoordinate(true)
    traitor:SetKillsNonAllies(true)
    traitor:SetTeam(TEAM_TRAITOR)
    traitor:SetUsesSuspicion(false)
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

---Returns if the bot's team is that of a traitor. Not recommende for determining who is friendly, as this is only based on the team, and not the role's allies.
---@param bot any
---@return boolean
function TTTBots.Roles.IsTraitor(bot)
    return bot:GetTeam() == TEAM_TRAITOR
end

function TTTBots.Roles.GenerateRegisterForRole(customRole)
    -- TODO: Write this, probably rename this function as well
end

TTTBots.Roles.RegisterDefaultRoles()
