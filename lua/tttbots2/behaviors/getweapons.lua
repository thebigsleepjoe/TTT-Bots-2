TTTBots.Behaviors.GetWeapons = {}

local lib = TTTBots.Lib

local GetWeapons = TTTBots.Behaviors.GetWeapons
GetWeapons.Name = "GetWeapons"
GetWeapons.Description = "Acquire a weapon to use"
GetWeapons.Interruptible = true

local STATUS = TTTBots.STATUS

local globalWeapons = {}
local globalPrimaries = {}
local globalSecondaries = {}

---@class Bot
---@field botTargetWeapon Weapon?

---Get the needed weapon type for the bot, else "none"
---@param bot Bot
---@return string type
function GetWeapons.GetNeededWeapon(bot)
    local inventory = bot:BotInventory()

    local hasPrimary = inventory:HasPrimary()
    local hasSecondary = inventory:HasSecondary()

    return (
        not hasPrimary and "primary" or
        not hasSecondary and "secondary" or
        "none"
    )
end

---@param bot Bot
function GetWeapons.NeedsWeapon(bot)
    return GetWeapons.GetNeededWeapon(bot) ~= "none"
end

---@param bot Bot
function GetWeapons.Validate(bot)
    return (
        GetWeapons.NeedsWeapon(bot)
        and (
            GetWeapons.AssignTargetWeapon(bot)
            or bot.botTargetWeapon ~= nil
        )
    )
end

---Sets the bot.botTargetWeapon field to the nearest weapon, else nil. Returns true if it found one.
---@param bot Bot
---@return boolean success
function GetWeapons.AssignTargetWeapon(bot)
    local neededWeapon = GetWeapons.GetNeededWeapon(bot)
    local weapons = (neededWeapon == "primary") and globalPrimaries or globalSecondaries

    local closestWeapon = nil
    local closestDistance = math.huge

    for k, v in pairs(weapons) do
        if not GetWeapons.IsAvailable(v) then continue end
        local distance = bot:GetPos():DistToSqr(v:GetPos())
        if distance < closestDistance then
            closestWeapon = v
            closestDistance = distance
        end
    end

    bot.botTargetWeapon = closestWeapon
    return closestWeapon ~= nil
end

---@param bot Bot
---@return BStatus
function GetWeapons.OnStart(bot)
    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function GetWeapons.OnRunning(bot)
    local target = bot.botTargetWeapon

    if not (target and GetWeapons.IsAvailable(target)) then
        bot.botTargetWeapon = nil
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    loco:SetGoal(target:GetPos())

    return STATUS.RUNNING
end

---@param bot Bot
function GetWeapons.OnEnd(bot)
    bot:BotLocomotor():StopMoving()
end

---@param bot Bot
function GetWeapons.OnSuccess(bot) end

---@param bot Bot
function GetWeapons.OnFailure(bot) end

---Tests for validity and returns if a weapon can be currently picked up
---@param ent Entity?
---@return boolean
function GetWeapons.IsAvailable(ent)
    if not (ent and IsValid(ent)) then return false end
    if not ent:IsWeapon() then return false end

    ---@cast ent Weapon

    -- Skip unavailable weapons
    if ent:GetOwner() ~= nil then return false end

    -- If it ain't droppable then it aint' pickable.
    if not ent.AllowDrop then return false end
    if not ent.Kind then return false end

    return true
end

function GetWeapons.UpdateCache()
    globalWeapons = {}
    globalPrimaries = {}
    globalSecondaries = {}
    for k, v in pairs(ents.GetAll()) do
        if not GetWeapons.IsAvailable(v) then continue end

        table.insert(globalWeapons, v)

        local kindTable = {
            [2] = globalSecondaries,
            [3] = globalPrimaries,
        }

        if kindTable[v.Kind] then
            table.insert(kindTable[v.Kind], v)
        end
    end
end

timer.Create("TTTBots.Weapons.UpdateCache", 3, 0, GetWeapons.UpdateCache)
hook.Add("TTTBeginRound", "TTTBots.Weapons.UpdateCacheRound", GetWeapons.UpdateCache)
