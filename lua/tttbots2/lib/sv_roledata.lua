---@class RoleData
TTTBots.RoleData = {}
TTTBots.RoleData.__index = TTTBots.RoleData

local lib = TTTBots.Lib
local isTTT2 = lib.IsTTT2() -- Only needs to be called once, as the script will refresh every mapchange/server reset.

---Creates a new RoleData object.
---@return RoleData
function TTTBots.RoleData.New(rolename)
    ---@class RoleData
    local newRole = {}
    setmetatable(newRole, TTTBots.RoleData)

    local getSet = lib.GetSet

    newRole.Name = rolename

    --- Allies are people we know for sure are on our team.
    newRole.GetAllies, newRole.SetAllies = getSet("allies", {})

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
    newRole.GetKillsNonAllies, newRole.SetKillsNonAllies = getSet("killsNonAllies", false)

    --- Is auto-switch enabled/disabled? Auto-switch is what makes the bots automatically swap between weapons.
    --- This is useful if a role requires a specific weapon to be held.
    newRole.GetAutoSwitch, newRole.SetAutoSwitch = getSet("autoSwitch", true)

    --- Set the preferred weapon class to hold out at all times. This is useful for roles that require a specific weapon.
    --- You must disable SetAutoSwitch for this to work. You should control your bot weapon with the behavior tree if your role is more nuanced.
    newRole.GetPreferredWeapon, newRole.SetPreferredWeapon = getSet("preferredWeapon", nil)

    --- Set the team for this role.
    newRole.GetTeam, newRole.SetTeam = getSet("team", TEAM_INNOCENT)

    return newRole
end

--- Try to register our allies automatically if we're in TTT2.
function TTTBots.RoleData:RegisterAllies()

end
