TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FindWeapon = {}

local lib = TTTBots.Lib

local FindWeapon = TTTBots.Behaviors.FindWeapon
FindWeapon.Name = "FindWeapon"
FindWeapon.Description = "Wanders around the map"
FindWeapon.Interruptible = true

local STATUS = TTTBots.STATUS

function FindWeapon.HasPrimary(bot)
    local im = bot.components.inventory
    local primary = im:GetPrimary()
    return primary ~= nil
end

--- Cache for GetWeaponsNear'
---@class GetWeaponsNearCache
---@field weapons table<Weapon>
---@field time number?
local GetWeaponsNearCache = {}
local GWNC_EXPIRY = 2

function FindWeapon.GetWeaponsNear(bot, radius)
    local cacheTime = GetWeaponsNearCache and GetWeaponsNearCache.time or -math.huge
    if cacheTime + GWNC_EXPIRY > CurTime() then
        return GetWeaponsNearCache.weapons
    end
    local im = bot.components.inventory
    radius = radius or 1000
    local weapons = {}
    for k, v in pairs(ents.FindInSphere(bot:GetPos(), radius)) do
        if (v.AllowDrop ~= nil) then
            table.insert(weapons, v)
        end
    end
    GetWeaponsNearCache = {
        weapons = weapons,
        time = CurTime(),
    }
    return weapons
end

function FindWeapon.WeaponIsPrimary(weapon)
    return weapon.Kind == 3
end

--- Leverage the pathmanager module to determine if a path has been attempted to this weapon yet it is still unreachable
function FindWeapon.WeaponIsPathable(bot, weapon)
    return not TTTBots.PathManager.IsUnreachableVec(bot:GetPos(), weapon:GetPos())
end

function FindWeapon.WeaponOnGround(weapon)
    return not IsValid(weapon:GetOwner())
end

function FindWeapon.CanReachWeapon(ent)
    local func = TTTBots.Lib.BotCanReachPos
    return func(ent:GetPos())
end

--- Cache the result of GetWeaponFor;
---@class GetWeaponForCache
---@field ent Weapon? the weapon/ent
---@field time number? the time the cache was created
local GetWeaponForCache = {}
local GWFC_EXPIRY = 1
--- Find a **primary** weapon on the ground nearest to **bot**
---@param bot Bot
---@return Weapon?
function FindWeapon.GetWeaponFor(bot)
    local cacheTime = GetWeaponForCache and GetWeaponForCache.time or -math.huge
    if (cacheTime + GWFC_EXPIRY) > CurTime() then
        return GetWeaponForCache.ent
    end
    -- Return the nearest weapon to bot:GetPos()
    local weapons = FindWeapon.GetWeaponsNear(bot)
    local closestWeapon = nil
    local closestDist
    for k, v in pairs(weapons) do
        if not IsValid(v) then continue end
        local dist = bot:GetPos():Distance(v:GetPos())
        if FindWeapon.WeaponIsPrimary(v)
            and FindWeapon.WeaponOnGround(v)
            and FindWeapon.CanReachWeapon(v)
            and FindWeapon.WeaponIsPathable(bot, v)
            and (closestDist == nil
                or dist < closestDist)
        then
            closestDist = dist
            closestWeapon = v
        end
    end

    GetWeaponForCache = {
        ent = closestWeapon,
        time = CurTime(),
    }
    return closestWeapon
end

function FindWeapon.ValidateTarget(bot)
    local target = bot.findweapon.target
    if target == nil then return false end
    if not IsValid(target) then return false end
    if not target:IsValid() then return false end
    if not FindWeapon.WeaponOnGround(target) then return false end
    if not FindWeapon.WeaponIsPathable(bot, target) then return false end

    return true
end

--- Validate the behavior
function FindWeapon.Validate(bot)
    local debugPrint = false
    local a = not FindWeapon.HasPrimary(bot)
    local b = a and #FindWeapon.GetWeaponsNear(bot) > 0
    local c = b and FindWeapon.GetWeaponFor(bot) ~= nil
    if debugPrint then
        print("Not HasPrimary: ", a)
        print("HasWeaponsNear: ", b)
        print("GetWeaponFor: ", c)
    end
    return a and b and c
end

--- Called when the behavior is started
function FindWeapon.OnStart(bot)
    bot.findweapon = {}
    bot.findweapon.target = FindWeapon.GetWeaponFor(bot)

    local debugPrint = false
    if debugPrint then
        print("FindWeapon.OnStart")
        print("Target: ", bot.findweapon.target)
    end

    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function FindWeapon.OnRunning(bot)
    local debugPrint = false

    local pastTarget = bot.findweapon.target
    if pastTarget and IsValid(pastTarget) and pastTarget:GetOwner() == bot then return STATUS.SUCCESS end

    bot.findweapon.target = (FindWeapon.ValidateTarget(bot) and bot.findweapon.target) or FindWeapon.GetWeaponFor(bot)
    if not FindWeapon.ValidateTarget(bot) then
        return STATUS.FAILURE
    end

    local target = bot.findweapon.target

    assert(target, "Target is nil when it shouldn't be.")

    local loco = bot:BotLocomotor()
    loco:SetGoal(target:GetPos())

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function FindWeapon.OnSuccess(bot)
    print("Finished grabbing a weapon")
    local im = bot.components.inventory
    im:EquipPrimary()
end

--- Called when the behavior returns a failure state
function FindWeapon.OnFailure(bot)
end

--- Called when the behavior ends
function FindWeapon.OnEnd(bot)
end
