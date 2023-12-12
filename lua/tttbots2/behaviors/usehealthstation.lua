TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.UseHealthStation = {}

local lib = TTTBots.Lib

local UseHealthStation = TTTBots.Behaviors.UseHealthStation
UseHealthStation.Name = "Use Health Station"
UseHealthStation.Description = "Use or place a health station"
UseHealthStation.Interruptible = true

UseHealthStation.TargetClass = "ttt_health_station"

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

function UseHealthStation.HasHealthStation(bot)
    if not lib.GetConVarBool("plant_health") then return false end -- This behavior is disabled per the user's choice.
    return bot:HasWeapon("weapon_ttt_health_station")
end

function UseHealthStation.IsHurt(bot)
    local health = bot:Health()
    local maxHealth = bot:GetMaxHealth()
    local healthPercentage = health / maxHealth
    return healthPercentage < 0.9
end

function UseHealthStation.ValidateStation(hs)
    return (
        IsValid(hs)
        and hs:GetClass() == UseHealthStation.TargetClass
        and hs:GetStoredHealth() > 0
    )
end

function UseHealthStation.GetNearestStation(bot)
    local stations = ents.FindByClass(UseHealthStation.TargetClass)
    local validStations = {}
    for i, v in pairs(stations) do
        if not UseHealthStation.ValidateStation(v) then
            continue
        end
        table.insert(validStations, v)
    end

    local nearestStation = lib.GetClosest(validStations, bot:GetPos())
    return nearestStation
end

function UseHealthStation.TakeHealthFrom(bot, station)
    station:Use(bot)
end

--- Validate the behavior
function UseHealthStation.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end             --- We are preoccupied with an attacker.
    if not lib.GetConVarBool("use_health") then return false end -- This behavior is disabled per the user's choice.

    local isHurt = UseHealthStation.IsHurt(bot)
    local hasHealthStation = UseHealthStation.HasHealthStation(bot)

    return hasHealthStation or (isHurt and UseHealthStation.GetNearestStation(bot) ~= nil)
end

--- Called when the behavior is started
function UseHealthStation.OnStart(bot)
    if UseHealthStation.HasHealthStation(bot) then
        local inventory = lib.GetComp(bot, "inventorymgr") ---@type CInventory
        inventory:PauseAutoSwitch()
        return STATUS.RUNNING
    end

    local station = UseHealthStation.GetNearestStation(bot)
    bot.targetStation = station
    return STATUS.RUNNING
end

function UseHealthStation.PlaceHealthStation(bot)
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    bot:SelectWeapon("weapon_ttt_health_station")
    locomotor:StartAttack()
end

--- Called when the behavior's last state is running
function UseHealthStation.OnRunning(bot)
    if UseHealthStation.HasHealthStation(bot) then
        UseHealthStation.PlaceHealthStation(bot)
        return STATUS.RUNNING
    end

    if not UseHealthStation.IsHurt(bot) then return STATUS.SUCCESS end

    if not UseHealthStation.ValidateStation(bot.targetStation) then
        return STATUS.FAILURE
    end

    local station = bot.targetStation
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    locomotor:SetGoal(station:GetPos())
    local distToStation = bot:GetPos():Distance(station:GetPos())

    if distToStation < 500 then
        locomotor:LookAt(station:GetPos())
        if distToStation < 100 then
            UseHealthStation.TakeHealthFrom(bot, station)
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function UseHealthStation.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function UseHealthStation.OnFailure(bot)
end

--- Called when the behavior ends
function UseHealthStation.OnEnd(bot)
    bot.targetStation = nil
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    local inventory = lib.GetComp(bot, "inventorymgr") ---@type CInventory
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
end
