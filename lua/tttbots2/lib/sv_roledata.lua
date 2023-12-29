---@class RoleData
TTTBots.RoleData = {}
TTTBots.RoleData.__index = TTTBots.RoleData

local lib = TTTBots.Lib
local isTTT2 = lib.IsTTT2() -- Only needs to be called once, as the script will refresh every mapchange/server reset.

---Creates a new RoleData object.
---@param rolename string
---@param roleteam? string A TEAM_ enum, or nil (defaults to TEAM_INNOCENT). This is usually a string, like 'jesters' or 'traitors'
---@return RoleData
function TTTBots.RoleData.New(rolename, roleteam)
    ---@class RoleData
    local newRole = {}
    setmetatable(newRole, TTTBots.RoleData)

    local getSet = lib.GetSet

    --- Get the name
    newRole.GetName, newRole.SetName = getSet("name", rolename)

    --- Enemies are players we know immediately that they are enemies.
    newRole.GetEnemies, newRole.SetEnemies = getSet("enemies", {})

    --- The behavior tree that is ran across this role
    newRole.GetBTree, newRole.SetBTree = getSet("btree", {})

    --- Get whether or not we are a "planting" role, aka we can plant C4.
    newRole.GetPlantsC4, newRole.SetPlantsC4 = getSet("plantsC4", false)

    --- Whether or not this role can defuse C4.
    newRole.GetDefusesC4, newRole.SetDefusesC4 = getSet("defusesC4", false)

    --- Get a list of weapon names
    newRole.GetBuyableWeapons, newRole.SetBuyableWeapons = getSet("buyableItems", {})

    --- Can this role simulate owning radar?
    newRole.GetCanHaveRadar, newRole.SetCanHaveRadar = getSet("canHaveRadar", false)

    --- Can/do we coordinate with other traitors?
    newRole.GetCanCoordinate, newRole.SetCanCoordinate = getSet("canCoordinate", false)

    --- Do we kill players that aren't on our team? Essentially, this disables/enables if the bot will
    --- "randomly" shoot at nearby non-allies. Particularly useful for traitors.
    newRole.GetStartsFights, newRole.SetStartsFights = getSet("killsNonAllies", false)

    --- Is auto-switch enabled/disabled? Auto-switch is what makes the bots automatically swap between weapons.
    --- This is useful if a role requires a specific weapon to be held.
    newRole.GetAutoSwitch, newRole.SetAutoSwitch = getSet("autoSwitch", true)

    --- Set the preferred weapon class to hold out at all times. This is useful for roles that require a specific weapon.
    --- You must disable SetAutoSwitch for this to work. You should control your bot weapon with the behavior tree if your role is more nuanced.
    newRole.GetPreferredWeapon, newRole.SetPreferredWeapon = getSet("preferredWeapon", nil)

    --- Get the team for this role. E.g., TEAM_INNOCENT, TEAM_INNOCENT, etc.
    newRole.GetTeam, newRole.SetTeam = getSet("team", roleteam or TEAM_INNOCENT)

    --- Some roles are more likely to follow due to their nature. This is a boolean that determines if this role is more likely to follow.
    --- This is particularly useful for traitors, because it tends to make them follow someone until they are alone.
    newRole.GetIsFollower, newRole.SetIsFollower = getSet("follower", false)

    --- If the bot can "look at the scoreboard" to see who is dead and alive. Functionally this just makes the bot know who is dead/alive at all times.
    newRole.GetKnowsLifeStates, newRole.SetKnowsLifeStates = getSet("knowsLifeStates", false)

    --- If the player appears as a police player. Useful for the 'defective' role, so bots trust them.
    newRole.GetAppearsPolice, newRole.SetAppearsPolice = getSet("appearsPolice", false)

    --- If the bot uses the suspicion system to determine who is good and bad.
    newRole.GetUsesSuspicion, newRole.SetUsesSuspicion = getSet("appearsPolice", true)

    --- Allies are people we know for sure are on our team. For traitors, you want to also set "traitor" as one of these, because
    --- they know who each other are. This is particularly used for defending one another in combat.
    newRole.GetAlliedRoles, newRole.SetAlliedRoles = getSet("allies", { [rolename] = true })

    --- Allied teams are teams that are explicitly set as DO NOT ATTACK. This is helpful for allying jester towards traitors, for example. So they don't hurt each other.
    --- This should only be used for teams that know who each other are inherently. Such as omniscient roles.
    newRole.GetAlliedTeams, newRole.SetAlliedTeams = getSet("alliedTeams", { [newRole:GetTeam()] = true })

    return newRole
end

---Basically just returns if team == TEAM_TRAITOR
---@return boolean
function TTTBots.RoleData:IsTraitor()
    return self:GetTeam() == TEAM_TRAITOR
end
