--- BurnCorpse: use flare gun to burn victim corpses and destroy evidence.

---@class BBurnCorpse
TTTBots.Behaviors.BurnCorpse = {}

local lib = TTTBots.Lib

---@class BBurnCorpse
local BurnCorpse = TTTBots.Behaviors.BurnCorpse
BurnCorpse.Name = "BurnCorpse"
BurnCorpse.Description = "Burn the corpse of a recent victim with the flare gun."
BurnCorpse.Interruptible = true

BurnCorpse.BURN_RANGE = 250          --- Max distance to shoot the flare at the corpse
BurnCorpse.APPROACH_RANGE = 200      --- Get this close before shooting
BurnCorpse.KILL_WINDOW = 12          --- Seconds after a kill during which we try to burn
BurnCorpse.SHOOT_TIME = 1.5          --- Seconds to hold attack when shooting the flare
BurnCorpse.FLEE_DISTANCE = 600       --- How far to run after burning
BurnCorpse.FLEE_TIME = 5             --- Seconds to spend fleeing

local STATUS = TTTBots.STATUS

--- Find the flare gun in the bot's inventory.
---@param bot Bot
---@return Weapon|nil
function BurnCorpse.GetFlareGun(bot)
    local candidates = {
        "weapon_ttt_flaregun",
        "weapon_ttt2_flaregun",
    }
    for _, cls in ipairs(candidates) do
        if bot:HasWeapon(cls) then
            return bot:GetWeapon(cls)
        end
    end
    return nil
end

--- Find the corpse of a specific player.
---@param victim Player
---@return Entity|nil
function BurnCorpse.FindCorpseOf(victim)
    if not IsValid(victim) then return nil end
    local corpses = TTTBots.Match.Corpses
    if not corpses then return nil end

    for _, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        -- TTT2 stores the player entity on the ragdoll
        local owner = CORPSE.GetPlayer(corpse)
        if owner == victim then
            return corpse
        end
    end
    return nil
end

--- Validate: only runs for traitor-side bots with bodyBurner trait and a flare gun,
--- who recently killed someone.
---@param bot Bot
---@return boolean
function BurnCorpse.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end

    -- Must have bodyBurner trait
    if not bot:GetTraitBool("bodyBurner") then return false end

    -- Allow continuing flee phase
    if bot.burnPhase == "flee" then return true end

    -- Must have a flare gun
    if not BurnCorpse.GetFlareGun(bot) then return false end

    -- Check if we already have a valid burn target in progress
    if bot.tttbots_burnTarget and IsValid(bot.tttbots_burnTarget) then
        -- Still within the kill window or already approaching/shooting
        if bot.burnPhase == "approach" or bot.burnPhase == "shoot" then
            return true
        end
    end

    -- Must have killed recently
    local lastKillTime = bot.lastKillTime or 0
    local elapsed = CurTime() - lastKillTime
    if elapsed > BurnCorpse.KILL_WINDOW then return false end

    -- Must have a kill victim whose corpse we can find
    local victim = bot.tttbots_lastKillVictim
    if not IsValid(victim) then return false end

    local corpse = BurnCorpse.FindCorpseOf(victim)
    if not corpse or not IsValid(corpse) then return false end

    -- Don't burn already-found corpses (no point, evidence already known)
    if CORPSE.GetFound(corpse, false) then return false end

    -- Store the burn target
    bot.tttbots_burnTarget = corpse
    return true
end

---@param bot Bot
---@return BStatus
function BurnCorpse.OnStart(bot)
    bot.burnPhase = "approach"
    bot.burnShootStart = nil
    bot.burnFleeStart = nil
    bot.burnFleeSpot = nil
    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function BurnCorpse.OnRunning(bot)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    local inv = bot:BotInventory()

    local phase = bot.burnPhase or "approach"

    ---------------------------------------------------------------------------
    -- PHASE: FLEE — run away after burning
    ---------------------------------------------------------------------------
    if phase == "flee" then
        local fleeSpot = bot.burnFleeSpot
        if not fleeSpot then return STATUS.SUCCESS end

        loco:SetGoal(fleeSpot)

        local elapsed = CurTime() - (bot.burnFleeStart or CurTime())
        if elapsed > BurnCorpse.FLEE_TIME then
            return STATUS.SUCCESS
        end

        if bot:GetPos():Distance(fleeSpot) < 100 then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- CORPSE VALIDATION
    ---------------------------------------------------------------------------
    local corpse = bot.tttbots_burnTarget
    if not (corpse and IsValid(corpse)) then
        return STATUS.FAILURE
    end

    -- If the corpse was found/confirmed while we're approaching, abort
    if CORPSE.GetFound(corpse, false) then
        return STATUS.FAILURE
    end

    local botPos = bot:GetPos()
    local corpsePos = corpse:GetPos()
    local dist = botPos:Distance(corpsePos)

    ---------------------------------------------------------------------------
    -- PHASE: APPROACH — get close to the corpse
    ---------------------------------------------------------------------------
    if phase == "approach" then
        loco:SetGoal(corpsePos)
        loco:LookAt(corpsePos + Vector(0, 0, 10))

        -- Check witnesses — if too many people watching, abort
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local witnesses = lib.GetAllWitnessesBasic(botPos, nonAllies, bot)
        if #witnesses > 1 then
            -- Too many witnesses, skip burning and just leave
            return STATUS.FAILURE
        end

        -- Equip the flare gun while approaching
        local flare = BurnCorpse.GetFlareGun(bot)
        if flare and IsValid(flare) then
            local activeWep = bot:GetActiveWeapon()
            if not (IsValid(activeWep) and activeWep == flare) then
                pcall(bot.SelectWeapon, bot, flare:GetClass())
                if inv then inv:PauseAutoSwitch() end
            end
        end

        if dist <= BurnCorpse.APPROACH_RANGE then
            bot.burnPhase = "shoot"
            bot.burnShootStart = CurTime()
        end

        return STATUS.RUNNING
    end

    ---------------------------------------------------------------------------
    -- PHASE: SHOOT — aim at the corpse and fire the flare
    ---------------------------------------------------------------------------
    if phase == "shoot" then
        -- Make sure we're still holding the flare gun
        local flare = BurnCorpse.GetFlareGun(bot)
        if not (flare and IsValid(flare)) then
            -- Lost the flare gun somehow, abort
            return STATUS.FAILURE
        end

        local activeWep = bot:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep == flare) then
            pcall(bot.SelectWeapon, bot, flare:GetClass())
        end

        -- Stop moving, aim at corpse center, and fire
        loco:StopMoving()
        -- Aim slightly above ground level to hit the ragdoll
        local aimPos = corpsePos + Vector(0, 0, 8)
        loco:LookAt(aimPos)
        loco:StartAttack()

        local elapsed = CurTime() - (bot.burnShootStart or CurTime())
        if elapsed > BurnCorpse.SHOOT_TIME then
            -- Done shooting, flee the scene
            loco:StopAttack()
            BurnCorpse.StartFlee(bot, corpsePos)
        end

        return STATUS.RUNNING
    end

    return STATUS.FAILURE
end

--- Start fleeing after burning a corpse.
---@param bot Bot
---@param burnPos Vector
function BurnCorpse.StartFlee(bot, burnPos)
    bot.burnPhase = "flee"
    bot.burnFleeStart = CurTime()

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    -- Find a nav area away from the burn site
    local botPos = bot:GetPos()
    local fleeSpot = botPos
    local navAreas = TTTBots.Lib.GetCachedNavAreas()
    if navAreas and #navAreas > 0 then
        local bestSpot = nil
        local bestDist = 0
        local samples = math.min(20, #navAreas)
        for i = 1, samples do
            local nav = navAreas[math.random(#navAreas)]
            if not IsValid(nav) then continue end
            local center = nav:GetCenter()
            local distFromBurn = center:Distance(burnPos)
            local distFromBot = center:Distance(botPos)
            if distFromBurn > BurnCorpse.FLEE_DISTANCE and distFromBot < 2500 then
                if distFromBurn > bestDist then
                    bestDist = distFromBurn
                    bestSpot = center
                end
            end
        end
        if bestSpot then fleeSpot = bestSpot end
    end

    -- Fallback: run in the opposite direction
    if fleeSpot == botPos then
        local awayDir = (botPos - burnPos):GetNormalized()
        awayDir.z = 0
        awayDir:Normalize()
        local rawSpot = botPos + awayDir * BurnCorpse.FLEE_DISTANCE
        local nearNav = navmesh.GetNearestNavArea(rawSpot)
        if nearNav and IsValid(nearNav) then
            fleeSpot = nearNav:GetCenter()
        end
    end

    bot.burnFleeSpot = fleeSpot
end

function BurnCorpse.OnSuccess(bot)
end

function BurnCorpse.OnFailure(bot)
end

function BurnCorpse.OnEnd(bot)
    bot.tttbots_burnTarget = nil
    bot.burnPhase = nil
    bot.burnShootStart = nil
    bot.burnFleeStart = nil
    bot.burnFleeSpot = nil
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

---------------------------------------------------------------------------
-- Track the last kill victim on bots so the burn behavior knows whose
-- corpse to look for. This piggybacks on the existing PlayerDeath hook.
---------------------------------------------------------------------------
hook.Add("PlayerDeath", "TTTBots.Behavior.BurnCorpse.TrackVictim", function(victim, weapon, attacker)
    if not (IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot()) then return end
    if not TTTBots.Match.IsRoundActive() then return end
    if not (IsValid(victim) and victim:IsPlayer()) then return end

    -- Only track for bots with the bodyBurner trait
    if not attacker:GetTraitBool("bodyBurner") then return end

    attacker.tttbots_lastKillVictim = victim
end)
