--- Plants a bomb in a safe location. Does not do anything if the bot does not have C4 in its inventory.

TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.PlantBomb = {}

local lib = TTTBots.Lib

local PlantBomb = TTTBots.Behaviors.PlantBomb
PlantBomb.Name = "PlantBomb"
PlantBomb.Description = "Plant a bomb in a safe location"
PlantBomb.Interruptible = true

PlantBomb.PLANT_RANGE = 80 --- Distance to the site to which we can plant the bomb

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

function PlantBomb.HasBomb(bot)
    return bot:HasWeapon("weapon_ttt_c4")
end

--- Validate the behavior
function PlantBomb.Validate(bot)
    local inRound = TTTBots.Match.IsRoundActive()
    local isEvil = lib.IsEvil(bot)
    local hasBomb = PlantBomb.HasBomb(bot)
    return inRound and isEvil and hasBomb
end

---Gets the best spot to plant a bomb around the bot.
---@param bot Player
---@return Vector|nil
function PlantBomb.FindPlantSpot(bot)
    local options = TTTBots.Spots.GetSpotsInCategory("bomb")
    local weightedOptions = {}

    -- We will use a weighting system for this.
    for _, spot in pairs(options) do
        weightedOptions[spot] = 0
        local witnesses = lib.GetAllVisible(spot, true)
        -- If we can see the spot, it's a good spot.
        if bot:VisibleVec(spot) then
            weightedOptions[spot] = weightedOptions[spot] + 2
        end

        for _, witness in pairs(witnesses) do -- Get a list of all non-evils that can see this pos
            weightedOptions[spot] = weightedOptions[spot] - 2
        end

        for _, ply in pairs(player.GetAll()) do
            if not (lib.IsGood(ply) and lib.IsPlayerAlive(ply)) then continue end

            --- We want to find spots in the 'goldilocks zone' -- not too close to targets, but not too far away either.
            local distToSpot = ply:GetPos():Distance(spot)
            if distToSpot < 256 then
                weightedOptions[spot] = weightedOptions[spot] - 1
            elseif distToSpot < 1024 then
                weightedOptions[spot] = weightedOptions[spot] + 0.5
            elseif distToSpot > 2048 then
                weightedOptions[spot] = weightedOptions[spot] - 0.5
            end
        end
    end

    local bestSpot = nil
    local bestWeight = -math.huge
    for spot, weight in pairs(weightedOptions) do
        if weight > bestWeight then
            bestWeight = weight
            bestSpot = spot
        end
    end

    return bestSpot
end

--- Called when the behavior is started
function PlantBomb.OnStart(bot)
    local spot = PlantBomb.FindPlantSpot(bot)
    if not spot then
        print("No spot to plant bomb;", spot)
        return STATUS.FAILURE
    end
    local inventory = lib.GetComp(bot, "inventorymgr") ---@type CInventory
    inventory:PauseAutoSwitch()

    bot.bombPlantSpot = spot
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function PlantBomb.OnRunning(bot)
    local spot = bot.bombPlantSpot
    if not spot then return STATUS.FAILURE end

    local distToSpot = bot:GetPos():Distance(spot)
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    locomotor:SetGoalPos(spot)
    if distToSpot > PlantBomb.PLANT_RANGE then
        return STATUS.RUNNING
    end

    -- We are close enough to plant.
    local witnesses = lib.GetAllVisible(spot, true)
    local currentTime = CurTime()

    if #witnesses > 0 then
        bot.lastWitnessTime = currentTime
        return STATUS.RUNNING
    elseif bot.lastWitnessTime and currentTime - bot.lastWitnessTime <= 3 then
        return STATUS.RUNNING
    end

    -- We are safe to plant.
    bot:SelectWeapon("weapon_ttt_c4")
    locomotor:AimAt(spot)
    locomotor:StartAttack()

    return STATUS.RUNNING -- This behavior depends on the validation call ending it.
end

--- Called when the behavior returns a success state
function PlantBomb.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function PlantBomb.OnFailure(bot)
end

function PlantBomb.ArmNearbyBomb(bot)
    local bombs = ents.FindByClass("ttt_c4")
    local closestBomb = nil
    local closestDist = math.huge
    for _, bomb in pairs(bombs) do
        if bomb:GetArmed() then continue end
        local dist = bot:GetPos():Distance(bomb:GetPos())
        if dist < closestDist then
            closestDist = dist
            closestBomb = bomb
        end
    end

    if closestBomb and closestDist < PlantBomb.PLANT_RANGE then
        closestBomb:Arm(bot, 45)
        return true
    end

    return false
end

--- Called when the behavior ends
function PlantBomb.OnEnd(bot)
    bot.bombPlantSpot = nil
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    local inventory = lib.GetComp(bot, "inventorymgr") ---@type CInventory
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    PlantBomb.ArmNearbyBomb(bot)
end
