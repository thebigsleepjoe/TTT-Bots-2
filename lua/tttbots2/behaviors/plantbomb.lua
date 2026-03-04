--- PlantBomb: equip C4, travel to a plant spot, arm it, then flee.


TTTBots.Behaviors.PlantBomb = {}

local lib = TTTBots.Lib

local PlantBomb = TTTBots.Behaviors.PlantBomb
PlantBomb.Name = "PlantBomb"
PlantBomb.Description = "Plant a bomb in a safe location"
PlantBomb.Interruptible = true

PlantBomb.PLANT_RANGE = 80     --- Distance to the site to which we can plant the bomb
PlantBomb.ARM_DURATION = 3     --- Seconds the bot holds C4 visibly while "arming" it
PlantBomb.FLEE_DISTANCE = 900  --- How far the bot tries to run from the bomb after planting

---@enum PlantPhase
PlantBomb.PHASE = {
    TRAVEL = 1,  -- Walking to the plant spot
    ARMING = 2,  -- Holding C4 at the spot (visible, catchable)
    FLEE   = 3,  -- Running away after planting
}

local STATUS = TTTBots.STATUS

---@class Bot
---@field bombFailCounter number The number of times the bot has failed to plant a bomb.
---@field bombPlantSpot Vector|nil The position of the bomb plant spot.
---@field bombPhase PlantPhase Current planting phase.
---@field bombArmStart number CurTime() when arming began.
---@field bombFleeSpot Vector|nil Position to flee toward after planting.

function PlantBomb.HasBomb(bot)
    return bot:HasWeapon("weapon_ttt_c4")
end

function PlantBomb.IsPlanterRole(bot)
    local role = TTTBots.Roles.GetRoleFor(bot) ---@type RoleData
    return role:GetPlantsC4()
end

--- Validate the behavior
function PlantBomb.Validate(bot)
    if not lib.GetConVarBool("plant_c4") then return false end
    local inRound = TTTBots.Match.IsRoundActive()
    local isPlanter = PlantBomb.IsPlanterRole(bot)
    -- Allow validation while fleeing even if C4 was already placed
    local hasBomb = PlantBomb.HasBomb(bot)
    local isFleeing = bot.bombPhase == PlantBomb.PHASE.FLEE
    return inRound and isPlanter and (hasBomb or isFleeing)
end

---@type table<Vector, number> -- A list of spots that have been penalized for being impossible to plant at.
local penalizedBombSpots = {}

---Gets the best spot to plant a bomb around the bot.
---@param bot Bot
---@return Vector|nil
function PlantBomb.FindPlantSpot(bot)
    local options = TTTBots.Spots.GetSpotsInCategory("bomb")
    local weightedOptions = {}
    local extantBombs = ents.FindByClass("ttt_c4")

    for _, spot in pairs(options) do
        weightedOptions[spot] = 0
        local witnesses = lib.GetAllVisible(spot, true, bot)

        -- Check for existing bombs near this spot
        local bombTooClose = false
        for _, bomb in pairs(extantBombs) do
            if bomb:GetPos():Distance(spot) < 512 then
                bombTooClose = true
                break
            end
        end
        if bombTooClose then continue end

        -- Bonus if visible to us
        if bot:VisibleVec(spot) then
            weightedOptions[spot] = weightedOptions[spot] + 2
        end

        -- Big penalty for current witnesses
        for _, witness in pairs(witnesses) do
            weightedOptions[spot] = weightedOptions[spot] - 2
        end

        -- Disqualify suspected broken spots
        if penalizedBombSpots[spot] then
            if penalizedBombSpots[spot] > 25 then continue end
            weightedOptions[spot] = weightedOptions[spot] - penalizedBombSpots[spot]
        end

        -- Penalize or reward based on distance to targets
        for _, ply in pairs(TTTBots.Roles.GetNonAllies(bot)) do
            if not lib.IsPlayerAlive(ply) then continue end

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

--- Find a position far from the bomb to flee toward.
---@param bot Bot
---@param bombPos Vector
---@return Vector
function PlantBomb.FindFleeSpot(bot, bombPos)
    -- Try to find a nav area that's far from the bomb
    local bestSpot = nil
    local bestDist = 0
    local botPos = bot:GetPos()

    -- Use patrol/wander spots if available, otherwise just pick a direction away from the bomb
    local navAreas = TTTBots.Lib.GetCachedNavAreas()
    if navAreas and #navAreas > 0 then
        -- Sample a handful of random nav areas and pick the one farthest from the bomb
        -- that isn't too far from us (so the path is reachable)
        for i = 1, math.min(20, #navAreas) do
            local nav = navAreas[math.random(#navAreas)]
            if not IsValid(nav) then continue end
            local center = nav:GetCenter()
            local distFromBomb = center:Distance(bombPos)
            local distFromBot = center:Distance(botPos)
            -- Must be far from bomb but not absurdly far from us
            if distFromBomb > bestDist and distFromBomb > PlantBomb.FLEE_DISTANCE and distFromBot < 3000 then
                bestDist = distFromBomb
                bestSpot = center
            end
        end
    end

    -- Fallback: just run in the opposite direction
    if not bestSpot then
        local awayDir = (botPos - bombPos):GetNormalized()
        bestSpot = botPos + awayDir * PlantBomb.FLEE_DISTANCE
    end

    return bestSpot
end

--- Called when the behavior is started
function PlantBomb.OnStart(bot)
    local spot = PlantBomb.FindPlantSpot(bot)
    if not spot then
        ErrorNoHaltWithStack("PlantBomb.OnStart: No valid bomb plant spot found for " .. bot:Nick() .. "\n")
        return STATUS.FAILURE
    end
    local inventory = bot:BotInventory()
    inventory:PauseAutoSwitch()

    bot.bombPlantSpot = spot
    bot.bombPhase = PlantBomb.PHASE.TRAVEL
    bot.bombArmStart = nil
    bot.bombFleeSpot = nil
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function PlantBomb.OnRunning(bot)
    local spot = bot.bombPlantSpot
    if not spot then return STATUS.FAILURE end

    local phase = bot.bombPhase or PlantBomb.PHASE.TRAVEL
    local locomotor = bot:BotLocomotor()

    ---------------------------------------------------------------------------
    -- PHASE 1: TRAVEL — walk to the plant spot
    ---------------------------------------------------------------------------
    if phase == PlantBomb.PHASE.TRAVEL then
        locomotor:SetGoal(spot)

        if locomotor.status == locomotor.PATH_STATUSES.IMPOSSIBLE then
            penalizedBombSpots[spot] = (penalizedBombSpots[spot] or 0) + 3
            bot.bombFailCounter = (bot.bombFailCounter or 0) + 2
            return STATUS.FAILURE
        end

        local distToSpot = bot:GetPos():Distance(spot)
        if distToSpot > PlantBomb.PLANT_RANGE then
            return STATUS.RUNNING
        end

        -- We arrived at the spot. Wait for witnesses to clear, then begin arming.
        local witnesses = lib.GetAllVisible(spot, true, bot)
        local currentTime = CurTime()

        if #witnesses > 0 then
            bot.lastWitnessTime = currentTime
            return STATUS.RUNNING
        elseif bot.lastWitnessTime and currentTime - bot.lastWitnessTime <= 3 then
            return STATUS.RUNNING
        end

        -- No witnesses: equip C4 and start arming phase
        local c4Wep = bot:GetWeapon("weapon_ttt_c4")
        if IsValid(c4Wep) then
            pcall(bot.SelectWeapon, bot, "weapon_ttt_c4")
        end
        bot.bombPhase = PlantBomb.PHASE.ARMING
        bot.bombArmStart = CurTime()
        locomotor:LookAt(spot)
        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE 2: ARMING — hold C4 visibly for ARM_DURATION seconds
    -- During this phase the bot is holding weapon_ttt_c4, so any innocent bot
    -- who sees them can catch them red-handed (the "HoldingC4" detection).
    ---------------------------------------------------------------------------
    if phase == PlantBomb.PHASE.ARMING then
        locomotor:LookAt(spot)

        -- Make sure we're still holding C4
        local activeWep = bot:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt_c4") then
            local c4Wep = bot:GetWeapon("weapon_ttt_c4")
            if IsValid(c4Wep) then
                pcall(bot.SelectWeapon, bot, "weapon_ttt_c4")
            else
                return STATUS.FAILURE -- Lost the C4 somehow
            end
        end

        local elapsed = CurTime() - (bot.bombArmStart or CurTime())
        if elapsed < PlantBomb.ARM_DURATION then
            -- Still arming... standing there holding C4
            -- Alert any witnesses who can see us during the arming phase
            PlantBomb.AlertWitnesses(bot)
            return STATUS.RUNNING
        end

        -- Arming complete: place and arm the C4
        local success = PlantBomb.PlaceAndArmC4(bot, spot)
        if not success then
            bot.bombFailCounter = (bot.bombFailCounter or 0) + 1
            return STATUS.FAILURE
        end

        -- Transition to flee phase
        bot.bombPhase = PlantBomb.PHASE.FLEE
        bot.bombFleeSpot = PlantBomb.FindFleeSpot(bot, spot)
        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE 3: FLEE — run away from the bomb as fast as possible
    ---------------------------------------------------------------------------
    if phase == PlantBomb.PHASE.FLEE then
        local fleeSpot = bot.bombFleeSpot
        if not fleeSpot then return STATUS.SUCCESS end

        locomotor:SetGoal(fleeSpot)

        local distFromBomb = bot:GetPos():Distance(spot)
        -- We've fled far enough, or we reached our flee target
        if distFromBomb >= PlantBomb.FLEE_DISTANCE then
            return STATUS.SUCCESS
        end

        local distToFlee = bot:GetPos():Distance(fleeSpot)
        if distToFlee < 100 then
            return STATUS.SUCCESS
        end

        -- Path impossible? Just succeed and move on to other behaviors
        if locomotor.status == locomotor.PATH_STATUSES.IMPOSSIBLE then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    return STATUS.FAILURE
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
        local chatter = bot:BotChatter()
        chatter:On("BombArmed", {}, true)
        return true
    end

    return false
end

--- Directly places and arms a C4 at the target position. This bypasses the VGUI menu
--- that would normally open when a player uses the C4 weapon, which bots cannot interact with.
---@param bot Bot
---@param pos Vector The position to place the C4
---@return boolean success Whether the C4 was placed and armed successfully
function PlantBomb.PlaceAndArmC4(bot, pos)
    -- Remove the C4 weapon from the bot's inventory
    local c4Wep = bot:GetWeapon("weapon_ttt_c4")
    if not IsValid(c4Wep) then return false end
    bot:StripWeapon("weapon_ttt_c4")

    -- Create the C4 entity in the world
    local c4 = ents.Create("ttt_c4")
    if not IsValid(c4) then
        bot:Give("weapon_ttt_c4")
        return false
    end

    c4:SetPos(pos + Vector(0, 0, 4))
    c4:Spawn()

    local armTime = math.random(30, 90)
    c4:Arm(bot, armTime)

    -- Track who planted this C4
    c4.oTTTBotsPlanter = bot

    -- Mark the planter as red-handed for a longer duration than the standard kill red-handed timer.
    local redHandedDuration = lib.GetConVarInt("cheat_redhanded_time")
    bot.redHandedTime = CurTime() + math.max(redHandedDuration * 3, 10)

    -- Final witness alert for anyone watching at the moment of planting
    PlantBomb.AlertWitnesses(bot)

    local chatter = bot:BotChatter()
    if chatter then
        chatter:On("BombArmed", {}, true)
    end

    return true
end

--- Notify all bot witnesses who can see the planter that they just saw someone plant C4.
--- This raises PlantC4 suspicion (value 10, basically instant KOS) on the planter.
---@param planter Bot
function PlantBomb.AlertWitnesses(planter)
    local witnesses = lib.GetAllWitnesses(planter:GetPos(), true)

    for _, witness in pairs(witnesses) do
        if witness == planter then continue end
        if not (IsValid(witness) and witness.components) then continue end
        if TTTBots.Roles.IsAllies(witness, planter) then continue end

        local morality = witness.components.morality
        if morality then
            morality:ChangeSuspicion(planter, "PlantC4")
        end
    end
end

--- Called when the behavior ends
function PlantBomb.OnEnd(bot)
    bot.bombPlantSpot = nil
    bot.bombPhase = nil
    bot.bombArmStart = nil
    bot.bombFleeSpot = nil
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
end

-- Decrement 'bomb fail' counter on each bot once per 20 seconds to prevent infinite retry loops.
timer.Create("TTTBots.Behavior.PlantBomb.PreventInfinitePlants", 20, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot ~= NULL and bot.components) then continue end
        bot.bombFailCounter = math.max(bot.bombFailCounter or 0, 0) - 1
    end
end)
