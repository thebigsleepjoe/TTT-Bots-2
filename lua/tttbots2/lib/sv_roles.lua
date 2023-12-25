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
---@return boolean - Whether or not the role is the default role.
function TTTBots.Roles.GetRole(name)
    local selected = TTTBots.Roles.m_roles[name]
    local isDefault = false
    if not selected then
        selected = TTTBots.Roles.m_roles["innocent"]
        isDefault = true
    end

    return selected, isDefault
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

function TTTBots.Roles.GetLivingAllies(player)
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(other)
        return TTTBots.Roles.IsAllies(player, other)
    end)
end

---Gets if the player is the ally of another player. This is based on the role's allies.
---@param ply1 Player
---@param ply2 Player
---@return boolean
function TTTBots.Roles.IsAllies(ply1, ply2)
    if not (IsValid(ply1) and IsValid(ply2)) then return false end
    if ply1:IsInTeam(ply2) and ply2:Team() ~= TEAM_INNOCENT then return true end
    local roleData = TTTBots.Roles.GetRoleFor(ply1)
    return roleData:GetAllies()[ply2:GetRoleStringRaw()] or false
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
    traitor:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
    TTTBots.Roles.RegisterRole(traitor)

    local detective = TTTBots.RoleData.New("detective")
    detective:SetDefusesC4(true)
    detective:SetCanHaveRadar(true)
    detective:SetTeam(TEAM_INNOCENT)
    detective:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
    TTTBots.Roles.RegisterRole(detective)

    local innocent = TTTBots.RoleData.New("innocent")
    innocent:SetDefusesC4(true)
    innocent:SetTeam(TEAM_INNOCENT)
    innocent:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
    TTTBots.Roles.RegisterRole(innocent)
end

---Returns if the bot's team is that of a traitor. Not recommende for determining who is friendly, as this is only based on the team, and not the role's allies.
---@param bot any
---@return boolean
function TTTBots.Roles.IsTraitor(bot)
    return bot:GetTeam() == TEAM_TRAITOR
end

--- Tries to automatically register a role, based on its base role or role info. This is far from perfect, but it's better than nothing.
---@param roleString string
---@return boolean - Whether or not we successfully registered a role.
function TTTBots.Roles.GenerateRegisterForRole(roleString)
    -- If we are in this function, this is definitely TTT2. But check anyway :)))
    if not TTTBots.Lib.IsTTT2() then return end
    local roleObj = roles.GetByName(roleString)
    if not roleObj then return end
    local baseRole = roleObj.baserole and roles.GetByIndex(roleObj.baserole)
    if baseRole then
        local baseData = TTTBots.Roles.GetRole(baseRole.name)
        if baseData:GetName() ~= "default" then
            local copy = table.Copy(baseData)
            copy:SetName(roleString)
            TTTBots.Roles.RegisterRole(copy)
            print(string.format("[TTT Bots 2] Auto-registered role '%s' based off of '%s'", roleString, baseRole.name))
            return true
        end
    end

    local roleTeam = roleObj.defaultTeam
    local isOmniscient = roleObj.isOmniscientRole or false
    -- local isPublicRole = role.isPublicRole or false     -- If the role is known to everyone. Unused here
    local isPolicingRole = roleObj.isPolicingRole or false -- if the role is a policing role

    local data = TTTBots.RoleData.New(roleString)
    data:SetTeam(roleTeam)
    data:SetUsesSuspicion(not isOmniscient)
    data:SetCanCoordinate(roleTeam == TEAM_TRAITOR)
    data:SetCanHaveRadar(isPolicingRole or roleTeam == TEAM_TRAITOR)
    data:SetAllies({ [roleString] = true })
    data:SetKnowsLifeStates(isOmniscient)
    data:SetBTree(TTTBots.Behaviors.DefaultTreesByTeam[roleTeam] or TTTBots.Behaviors.DefaultTrees.innocent)
    data:SetKillsNonAllies(roleTeam == TEAM_TRAITOR)
    print(string.format("[TTT Bots 2] Auto-registered role '%s' as a part of team ''", roleString, roleTeam))
    TTTBots.Roles.RegisterRole(data)
    return true
end

--- Create a timer on 2-second intervals to auto-generate roles if round started and we find an unknown role
timer.Create("TTTBots.AutoRegisterRoles", 2, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        local roleString = bot:GetRoleStringRaw()
        local roleObj, isDefault = TTTBots.Roles.GetRole(roleString)
        if isDefault then
            TTTBots.Roles.GenerateRegisterForRole(roleString)
        end
    end
end)

TTTBots.Roles.RegisterDefaultRoles()
