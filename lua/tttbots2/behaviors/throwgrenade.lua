--- ThrowGrenade: throw a grenade at a cluster of enemies.

---@class BThrowGrenade
TTTBots.Behaviors.ThrowGrenade = {}

local lib = TTTBots.Lib

---@class BThrowGrenade
local ThrowGrenade = TTTBots.Behaviors.ThrowGrenade
ThrowGrenade.Name = "ThrowGrenade"
ThrowGrenade.Description = "Throw a grenade at a group of enemies"
ThrowGrenade.Interruptible = false

ThrowGrenade.MIN_CLUSTER = 2          --- Minimum enemies in the cluster
ThrowGrenade.CLUSTER_RADIUS = 250     --- Max spread between enemies to count as a cluster
ThrowGrenade.MIN_THROW_DIST = 200     --- Don't throw if closer than this
ThrowGrenade.MAX_THROW_DIST = 900     --- Don't throw if further than this
ThrowGrenade.COOLDOWN = 15            --- Seconds between throws
ThrowGrenade.AIM_TIME = 0.4           --- Seconds to settle aim before throwing
ThrowGrenade.RECOVER_TIME = 0.5       --- Seconds after throw before switching back

local STATUS = TTTBots.STATUS

--- Get the bot's first grenade weapon (Kind == 4).
---@param bot Player
---@return Weapon|nil
function ThrowGrenade.GetGrenade(bot)
    for _, wep in pairs(bot:GetWeapons()) do
        if IsValid(wep) and wep.Kind == 4 then
            return wep
        end
    end
    return nil
end

--- Find the center and count of a cluster of visible non-ally enemies near a position.
--- Returns clusterCenter, clusterCount.
---@param bot Player
---@return Vector|nil center
---@return number count
function ThrowGrenade.FindEnemyCluster(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    if #nonAllies < ThrowGrenade.MIN_CLUSTER then return nil, 0 end

    local botPos = bot:GetPos()

    -- Collect visible enemies within throw range
    local visible = {}
    for _, ply in pairs(nonAllies) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        local pos = ply:GetPos()
        local dist = botPos:Distance(pos)
        if dist < ThrowGrenade.MIN_THROW_DIST or dist > ThrowGrenade.MAX_THROW_DIST then continue end
        if not bot:VisibleVec(pos + Vector(0, 0, 36)) then continue end
        visible[#visible + 1] = pos
    end

    if #visible < ThrowGrenade.MIN_CLUSTER then return nil, 0 end

    -- Find the best cluster: for each enemy, count how many others are within CLUSTER_RADIUS
    local bestCenter = nil
    local bestCount = 0
    local radiusSqr = ThrowGrenade.CLUSTER_RADIUS * ThrowGrenade.CLUSTER_RADIUS

    for i = 1, #visible do
        local count = 0
        local sum = Vector(0, 0, 0)
        for j = 1, #visible do
            if visible[i]:DistToSqr(visible[j]) < radiusSqr then
                count = count + 1
                sum = sum + visible[j]
            end
        end
        if count > bestCount then
            bestCount = count
            bestCenter = sum / count
        end
    end

    if bestCount < ThrowGrenade.MIN_CLUSTER then return nil, 0 end
    return bestCenter, bestCount
end

function ThrowGrenade.Validate(bot)
    if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then return false end
    if not bot.attackTarget then return false end

    -- Cooldown check
    if (bot.tttbots_grenadeCooldown or 0) > CurTime() then return false end

    -- Must have a grenade
    if not ThrowGrenade.GetGrenade(bot) then return false end

    -- Must see a cluster
    local center, count = ThrowGrenade.FindEnemyCluster(bot)
    if not center then return false end

    -- Don't throw toward allies
    local botPos = bot:GetPos()
    local throwDir = (center - botPos):GetNormalized()
    local clusterDist = botPos:Distance(center)
    for _, ply in pairs(TTTBots.Roles.GetLivingAllies(bot)) do
        if not IsValid(ply) or ply == bot then continue end
        local allyDir = (ply:GetPos() - botPos):GetNormalized()
        if throwDir:Dot(allyDir) > 0.85 then
            if botPos:Distance(ply:GetPos()) < clusterDist + 200 then return false end
        end
    end

    -- Cache the target for OnStart
    bot.tttbots_grenadeTarget = center
    return true
end

function ThrowGrenade.OnStart(bot)
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    local nade = ThrowGrenade.GetGrenade(bot)
    if not nade then return STATUS.FAILURE end

    -- Store previous weapon to switch back
    local activeWep = bot:GetActiveWeapon()
    bot.tttbots_grenadeOldWep = IsValid(activeWep) and activeWep:GetClass() or nil

    -- Equip the grenade
    inv:PauseAutoSwitch()
    pcall(bot.SelectWeapon, bot, nade:GetClass())

    -- Aim at the cluster center, elevated for arc
    local target = bot.tttbots_grenadeTarget
    if target then
        local dist = bot:GetPos():Distance(target)
        local arcOffset = math.Clamp(dist * 0.15, 20, 120)
        loco:LookAt(target + Vector(0, 0, arcOffset), ThrowGrenade.AIM_TIME + 0.5)
    end

    bot.tttbots_grenadePhase = "aiming"
    bot.tttbots_grenadePhaseTime = CurTime()
    loco:StopMoving()

    return STATUS.RUNNING
end

function ThrowGrenade.OnRunning(bot)
    local loco = bot:BotLocomotor()
    local phase = bot.tttbots_grenadePhase
    local elapsed = CurTime() - (bot.tttbots_grenadePhaseTime or 0)

    if phase == "aiming" then
        if elapsed >= ThrowGrenade.AIM_TIME then
            loco:StartAttack()
            bot.tttbots_grenadePhase = "throwing"
            bot.tttbots_grenadePhaseTime = CurTime()
        end
        return STATUS.RUNNING
    end

    if phase == "throwing" then
        -- Hold attack for one tick to ensure the throw registers
        if elapsed >= 0.25 then
            loco:StopAttack()
            bot.tttbots_grenadePhase = "recovering"
            bot.tttbots_grenadePhaseTime = CurTime()
        end
        return STATUS.RUNNING
    end

    if phase == "recovering" then
        if elapsed >= ThrowGrenade.RECOVER_TIME then
            return STATUS.SUCCESS
        end
        return STATUS.RUNNING
    end

    return STATUS.FAILURE
end

function ThrowGrenade.OnSuccess(bot)
    ThrowGrenade.Cleanup(bot)
end

function ThrowGrenade.OnFailure(bot)
    ThrowGrenade.Cleanup(bot)
end

function ThrowGrenade.OnEnd(bot)
    ThrowGrenade.Cleanup(bot)
end

function ThrowGrenade.Cleanup(bot)
    local loco = bot:BotLocomotor()
    loco:StopAttack()

    -- Switch back to previous weapon
    if bot.tttbots_grenadeOldWep then
        pcall(bot.SelectWeapon, bot, bot.tttbots_grenadeOldWep)
    end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    -- Set cooldown
    bot.tttbots_grenadeCooldown = CurTime() + ThrowGrenade.COOLDOWN

    bot.tttbots_grenadeTarget = nil
    bot.tttbots_grenadeOldWep = nil
    bot.tttbots_grenadePhase = nil
    bot.tttbots_grenadePhaseTime = nil
end
