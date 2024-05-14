--- This module is an abstraction layer for TTT/2 compatibility.

TTTBots.Roles = {}

local lib = TTTBots.Lib
TTTBots.Roles.m_roles = {}

include("sv_roledata.lua")

function TTTBots.Roles.RegisterRole(roleData)
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
---@return boolean - Whether or not the role is the default role.
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
    local role1 = TTTBots.Roles.GetRoleFor(ply1)
    local role2 = TTTBots.Roles.GetRoleFor(ply2)

    local allied1 = role1:GetAlliedRoles()[role2:GetName()] or role1:GetAlliedTeams()[role2:GetTeam()] or false
    local allied2 = role2:GetAlliedRoles()[role1:GetName()] or role2:GetAlliedTeams()[role1:GetTeam()] or false

    -- Using 'or' here intentionally, as the mode does not currently support one-sided alliances.
    return allied1 or allied2
end

---Get a table of players that are not allies with ply1, and are alive.
---@param ply1 Player
---@return table<Player>
function TTTBots.Roles.GetNonAllies(ply1)
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(other)
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then return false end
        return not TTTBots.Roles.IsAllies(ply1, other)
    end)
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
    if not TTTBots.Lib.IsTTT2() then return false end
    local roleObj = roles.GetByName(roleString)
    if not roleObj then return false end
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
    data:SetAlliedRoles({ [roleString] = true })
    data:SetKnowsLifeStates(isOmniscient)
    data:SetBTree(TTTBots.Behaviors.DefaultTreesByTeam[roleTeam] or TTTBots.Behaviors.DefaultTrees.innocent)
    data:SetStartsFights(roleTeam == TEAM_TRAITOR)
    if roleString ~= 'none' then
        local registeredManually = hook.Run("TTTBotsRoleRegistered", data)
        print(string.format("[TTT Bots 2] Registered role '%s' as a part of team '%s'!", roleString, data:GetTeam()))
        if not registeredManually then
            print(
                "[TTT Bots 2] The above role was not caught by any compatibility scripts! You may experience strange bot behavior for this role.")
        end
    end
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

local includedFilesTbl = TTTBots.Lib.IncludeDirectory("tttbots2/roles")
local includedFilesStr = TTTBots.Lib.StringifyTable(includedFilesTbl)
print("[TTT Bots 2] Registered officially supported roles: " .. string.gsub(includedFilesStr, ".lua", ""))

if TTTBots.Lib.IsTTT2() then return end

local plyMeta = FindMetaTable("Player")

function plyMeta:GetTeam()
    if self:IsTraitor() then return 'traitors' end
    if self:IsDetective() then return 'detectives' end
    return 'innocents'
end

function plyMeta:IsInTeam(ply1, ply2)
    return ply1:Team() == ply2:Team()
end
