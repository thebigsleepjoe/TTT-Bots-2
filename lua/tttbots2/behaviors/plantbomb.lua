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

function PlantBomb.IsPlanterRole(bot)
    local role = TTTBots.Roles.GetRoleFor(bot) ---@type RoleData
    return role:GetPlantsC4()
end

--- Validate the behavior
function PlantBomb.Validate(bot)
    if not lib.GetConVarBool("plant_c4") then return false end -- This behavior is disabled per the user's choice.
    local inRound = TTTBots.Match.IsRoundActive()
    local isPlanter = PlantBomb.IsPlanterRole(bot)
    local hasBomb = PlantBomb.HasBomb(bot)
    return inRound and isPlanter and hasBomb
end

---@type table<Vector, number> -- A list of spots that have been penalized for being impossible to plant at.
local penalizedBombSpots = {}

---Gets the best spot to plant a bomb around the bot.
---@param bot Player
---@return Vector|nil
function PlantBomb.FindPlantSpot(bot)
    local options = TTTBots.Spots.GetSpotsInCategory("bomb")
    local weightedOptions = {}
    local extantBombs = ents.FindByClass("ttt_c4")

    -- We will use a weighting system for this.
    for _, spot in pairs(options) do
        weightedOptions[spot] = 0
        local witnesses = lib.GetAllVisible(spot, true, bot)

        -- 💣 Check for existing bombs near this spot
        local bombTooClose = false
        for _, bomb in pairs(extantBombs) do
            if bomb:GetPos():Distance(spot) < 512 then
                bombTooClose = true
                break
            end
        end
        if bombTooClose then continue end -- Skip this spot if a bomb is too close

        -- 👀 Bonus if visible
        if bot:VisibleVec(spot) then
            weightedOptions[spot] = weightedOptions[spot] + 2
        end

        -- 🧍🏽Big penalty for current witnesses
        for _, witness in pairs(witnesses) do -- Get a list of all non-evils that can see this pos
            weightedOptions[spot] = weightedOptions[spot] - 2
        end

        -- ❌ Disqualify suspected broken spots
        if penalizedBombSpots[spot] then
            if penalizedBombSpots[spot] > 25 then continue end -- This spot is too penalized to be considered.
            weightedOptions[spot] = weightedOptions[spot] - penalizedBombSpots[spot]
        end

        -- 🤏🏽Penalize or reward based on distance to targets
        for _, ply in pairs(player.GetAll()) do
            if not (not TTTBots.Roles.IsAllies(bot, ply) and lib.IsPlayerAlive(ply)) then continue end

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

    if not bestSpot then
        bot.bombFailCounter = (bot.bombFailCounter or 0) + 1
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
    local inventory = lib.GetComp(bot, "inventory") ---@type CInventory
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
    locomotor:SetGoal(spot)

    if locomotor.status == locomotor.PATH_STATUSES.IMPOSSIBLE then
        penalizedBombSpots[spot] = (penalizedBombSpots[spot] or 0) + 3
        bot.bombFailCounter = (bot.bombFailCounter or 0) +
            2 -- Increment by 2 specifically to prevent the bot from trying to plant indefinitely.
        return STATUS.FAILURE
    end

    if distToSpot > PlantBomb.PLANT_RANGE then
        return STATUS.RUNNING
    end
    -- We are close enough to plant.
    local witnesses = lib.GetAllVisible(spot, true, bot)
    local currentTime = CurTime()

    if #witnesses > 0 then
        bot.lastWitnessTime = currentTime
        return STATUS.RUNNING
    elseif bot.lastWitnessTime and currentTime - bot.lastWitnessTime <= 3 then
        return STATUS.RUNNING
    end

    -- We are safe to plant.
    bot:SelectWeapon("weapon_ttt_c4")
    locomotor:LookAt(spot)
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
        local chatter = lib.GetComp(bot, "chatter") ---@type CChatter
        chatter:On("BombArmed", {}, true)
        return true
    end

    return false
end

--- Called when the behavior ends
function PlantBomb.OnEnd(bot)
    bot.bombPlantSpot = nil
    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    local inventory = lib.GetComp(bot, "inventory") ---@type CInventory
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    PlantBomb.ArmNearbyBomb(bot)
end

-- This part of the code is referencing preevnting a bot trying to plant indefinitely (and thus failing)
-- Specifically, we decrement the 'bomb fail' counter on each bot once per 20 seconds as to not break the behavior.
timer.Create("TTTBots.Behavior.PlantBomb.PreventInfinitePlants", 20, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot ~= NULL and bot.components) then continue end
        bot.bombFailCounter = math.max(bot.bombFailCounter or 0, 0) - 1
    end
end)
