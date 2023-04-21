TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FindWeapon = {}

local lib = TTTBots.Lib

local FindWeapon = TTTBots.Behaviors.FindWeapon
FindWeapon.Name = "FindWeapon"
FindWeapon.Description = "Wanders around the map"

local status = {
    Running = 1,
    Success = 2,
    Failure = 3,
}

function FindWeapon:HasPrimary(bot)
    local im = bot.components.inventorymgr
    local primary = im:GetPrimary()
    return primary ~= nil
end

function FindWeapon:GetWeaponsNear(bot, radius)
    local im = bot.components.inventorymgr
    radius = radius or 1000
    local weapons = {}
    for k, v in pairs(ents.FindInSphere(bot:GetPos(), radius)) do
        if v.AllowDrop ~= nil then
            table.insert(weapons, v)
        end
    end
    return weapons
end

function FindWeapon:WeaponIsPrimary(weapon)
    return weapon.Kind == 3
end

function FindWeapon:WeaponOnGround(weapon)
    return not IsValid(weapon:GetOwner())
end

function FindWeapon:CanReachWeapon(ent)
    local func = TTTBots.Lib.BotCanReachPos
    return func(ent:GetPos())
end

function FindWeapon:GetWeaponFor(bot)
    -- Return the nearest weapon to bot:GetPos()
    local weapons = self:GetWeaponsNear(bot)
    local closestWeapon = nil
    local closestDist
    for k, v in pairs(weapons) do
        local dist = bot:GetPos():Distance(v:GetPos())
        if self:WeaponIsPrimary(v)
            and self:WeaponOnGround(v)
            and self:CanReachWeapon(v)
            and (closestDist == nil
            or dist < closestDist)
        then
            closestDist = dist
            closestWeapon = v
        end
    end
    return closestWeapon
end

function FindWeapon:ValidateTarget(bot)
    local target = bot.findweapon.target
    if target == nil then return false end
    if not IsValid(target) then return false end
    if not target:IsValid() then return false end
    if not self:WeaponOnGround(target) then return false end

    return true
end

--- Validate the behavior
function FindWeapon:Validate(bot)
    local debugPrint = false
    local a = not self:HasPrimary(bot)
    local b = a and #self:GetWeaponsNear(bot) > 0
    local c = b and self:GetWeaponFor(bot) ~= nil
    if debugPrint then
        print("Not HasPrimary: ", a)
        print("HasWeaponsNear: ", b)
        print("GetWeaponFor: ", c)
    end
    return a and b and c
end

--- Called when the behavior is started
function FindWeapon:OnStart(bot)
    bot.findweapon = {}
    bot.findweapon.target = self:GetWeaponFor(bot)

    local debugPrint = false
    if debugPrint then
        print("FindWeapon:OnStart")
        print("Target: ", bot.findweapon.target)
    end

    return status.Running
end

--- Called when the behavior's last state is running
function FindWeapon:OnRunning(bot)
    local debugPrint = false

    if IsValid(bot.findweapon.target) and bot.findweapon.target:GetOwner() == bot then return status.Success end

    bot.findweapon.target = (self:ValidateTarget(bot) and bot.findweapon.target) or self:GetWeaponFor(bot)
    if not self:ValidateTarget(bot) then
        print("Failed because target is invalid")
        return status.Failure
    end

    local target = bot.findweapon.target
    local loco = bot.components.locomotor
    loco:SetGoalPos(target:GetPos())

    return status.Running
end

--- Called when the behavior returns a success state
function FindWeapon:OnSuccess(bot)
    print("Finished grabbing a weapon")
    local im = bot.components.inventorymgr
    im:EquipPrimary()
end

--- Called when the behavior returns a failure state
function FindWeapon:OnFailure(bot)
end

--- Called when the behavior ends
function FindWeapon:OnEnd(bot)
end
