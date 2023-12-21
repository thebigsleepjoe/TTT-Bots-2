TTTBots.Roles = {}
include("sv_roledata.lua")


local lib = TTTBots.Lib

TTTBots.Roles.m_roles = {}
function TTTBots.Roles.RegisterRole(roleData)
    -- TODO
end

function TTTBots.Roles.GetRole(name) return TTTBots.Roles.m_roles[name] end

function TTTBots.Roles.GetRoles() return TTTBots.Roles.m_roles end

function TTTBots.Roles.GetTeamMembers(player)
    if lib.IsTTT2() then
        -- roles.GetTeamMembers(team)
    end
end

--- Registers the TTT default roles. traitor, detective, innocent
function TTTBots.Roles.RegisterDefaultRoles()
    local traitor = TTTBots.RoleData.New("traitor")
    traitor:SetDefusesC4(false)
    traitor:SetPlantsC4(true)
    traitor:SetCanHaveRadar(true)
    traitor:SetCanCoordinate(true)
    traitor:SetKillsNonAllies(true)
    TTTBots.Roles.RegisterRole(traitor)

    local detective = TTTBots.RoleData.New("detective")
    detective:SetDefusesC4(true)
    detective:SetCanHaveRadar(true)
    TTTBots.Roles.RegisterRole(detective)

    local innocent = TTTBots.RoleData.New("innocent")
    innocent:SetDefusesC4(true)
    TTTBots.Roles.RegisterRole(innocent)
end

TTTBots.Roles.RegisterDefaultRoles()
