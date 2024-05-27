TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.UseHealthStation = {}

local lib = TTTBots.Lib

local UseHealthStation = TTTBots.Behaviors.UseHealthStation
UseHealthStation.Name = "Use Health Station"
UseHealthStation.Description = "Use or place a health station"
UseHealthStation.Interruptible = true
UseHealthStation.UseRange = 50 --- The range at which we can use a health station

UseHealthStation.TargetClass = "ttt_health_station"

local STATUS = TTTBots.STATUS

function UseHealthStation.HasHealthStation(bot)
    if not lib.GetConVarBool("plant_health") then return false end -- This behavior is disabled per the user's choice.
    return bot:HasWeapon("weapon_ttt_health_station")
end

function UseHealthStation.IsHurt(bot)
    local health = bot:Health()
    local maxHealth = bot:GetMaxHealth()
    return health + 1 < maxHealth
end

function UseHealthStation.ValidateStation(hs)
    local isvalid = (
        IsValid(hs)
        and hs:GetClass() == UseHealthStation.TargetClass
        and hs:GetStoredHealth() > 0
    )
    return isvalid
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
    local isStationNearby = (bot.targetStation or UseHealthStation.GetNearestStation(bot) ~= nil)

    return hasHealthStation or (isHurt and isStationNearby)
end

--- Called when the behavior is started
function UseHealthStation.OnStart(bot)
    if UseHealthStation.HasHealthStation(bot) then
        local inventory = bot:BotInventory()
        inventory:PauseAutoSwitch()
        return STATUS.RUNNING
    end

    local station = UseHealthStation.GetNearestStation(bot)
    bot.targetStation = station
    return STATUS.RUNNING
end

function UseHealthStation.PlaceHealthStation(bot)
    local locomotor = bot:BotLocomotor()
    bot:SelectWeapon("weapon_ttt_health_station")
    locomotor:StartAttack()
end

--- Called when the behavior's last state is running
function UseHealthStation.OnRunning(bot)
    if UseHealthStation.HasHealthStation(bot) then
        UseHealthStation.PlaceHealthStation(bot)
        return STATUS.RUNNING
    end

    if not UseHealthStation.IsHurt(bot) then
        return STATUS.SUCCESS
    end

    if not UseHealthStation.ValidateStation(bot.targetStation) then
        return STATUS.FAILURE
    end

    local station = bot.targetStation
    local locomotor = bot:BotLocomotor()
    locomotor:SetGoal(station:GetPos())
    locomotor:PauseRepel()
    local distToStation = bot:GetPos():Distance(station:GetPos())

    if distToStation < 300 then
        locomotor:LookAt(station:GetPos())
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
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    locomotor:ResumeRepel()
end

timer.Create("TTTBots.Behaviors.UseHealthStation.UseNearbyStations", 0.5, 0, function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local healthStation = bot.targetStation
        if not (healthStation and UseHealthStation.ValidateStation(healthStation)) then continue end
        local distToStation = bot:GetPos():Distance(healthStation:GetPos())
        if distToStation < UseHealthStation.UseRange then
            UseHealthStation.TakeHealthFrom(bot, healthStation)
        end
    end
end)
