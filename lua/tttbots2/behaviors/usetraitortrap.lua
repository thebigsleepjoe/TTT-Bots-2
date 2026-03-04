--- Behavior for traitor-team bots to find and activate traitor buttons (map traps).
--- In TTT, map makers place ttt_traitor_button entities that only traitors can use.
--- These trigger traps like falling floors, turrets, tesla gates, etc.
--- The bot will scan for nearby traitor buttons, path to them, and press +USE to activate.

---@class BUseTraitorTrap
TTTBots.Behaviors.UseTraitorTrap = {}

local lib = TTTBots.Lib

---@class BUseTraitorTrap
local UseTraitorTrap = TTTBots.Behaviors.UseTraitorTrap
UseTraitorTrap.Name = "UseTraitorTrap"
UseTraitorTrap.Description = "Activate a traitor trap button"
UseTraitorTrap.Interruptible = true

UseTraitorTrap.SCAN_RANGE = 2000         --- Max distance to consider a trap button
UseTraitorTrap.USE_RANGE = 100           --- Distance at which the bot can press the button
UseTraitorTrap.MIN_VICTIMS_NEARBY = 1    --- At least this many non-allies near the trap to bother
UseTraitorTrap.VICTIM_RANGE = 800        --- How close a non-ally must be to the button for us to consider activating
UseTraitorTrap.COOLDOWN = 15             --- Seconds between trap usage attempts (per bot)
UseTraitorTrap.CHANCE_PER_TICK = 3       --- X% chance per tick to consider using a trap (to add variance)

local STATUS = TTTBots.STATUS

---@class Bot
---@field trapTarget Entity? The traitor button we're heading towards
---@field trapCooldown number Next time we can try to use a trap
---@field trapStartTime number When we started heading towards the trap

--- Check if a bot's role is on the traitor team (can use traitor buttons).
---@param bot Bot
---@return boolean
function UseTraitorTrap.IsTraitorTeam(bot)
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role then return false end
    return role:GetStartsFights() -- Traitor-team roles start fights
end

--- Get all ttt_traitor_button entities on the map (cached per round).
---@return table<Entity>
UseTraitorTrap._buttonCache = nil
function UseTraitorTrap.GetAllTraitorButtons()
    if not UseTraitorTrap._buttonCache then
        UseTraitorTrap._buttonCache = ents.FindByClass("ttt_traitor_button")
    end
    return UseTraitorTrap._buttonCache
end
hook.Add("TTTBeginRound", "TTTBots.UseTraitorTrap.ClearCache", function()
    UseTraitorTrap._buttonCache = nil
end)
hook.Add("TTTEndRound", "TTTBots.UseTraitorTrap.ClearCacheEnd", function()
    UseTraitorTrap._buttonCache = nil
end)

--- Check if a traitor button is currently usable.
---@param btn Entity
---@return boolean
function UseTraitorTrap.IsButtonUsable(btn)
    if not IsValid(btn) then return false end

    -- Check if the button has a "locked" state (some mappers use this)
    if btn.IsLocked and btn:IsLocked() then return false end

    -- Check for the TTT-specific delay/wait system
    -- ttt_traitor_button stores next usable time in dt.next_use
    local nextUse = btn.GetNextUseTime and btn:GetNextUseTime()
    if nextUse and nextUse > CurTime() then return false end

    -- Also check the standard delay field
    if btn.dt and btn.dt.next_use and btn.dt.next_use > CurTime() then return false end

    return true
end

--- Count how many non-allies are near a given position.
---@param bot Bot
---@param pos Vector
---@param range number
---@return number count
---@return table<Player> victims
function UseTraitorTrap.CountNearbyVictims(bot, pos, range)
    local victims = {}
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local rangeSqr = range * range
    for i = 1, #nonAllies do
        local ply = nonAllies[i]
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply:GetPos():DistToSqr(pos) <= rangeSqr then
            victims[#victims + 1] = ply
        end
    end
    return #victims, victims
end

--- Count how many allies are near a given position (to avoid friendly fire).
---@param bot Bot
---@param pos Vector
---@param range number
---@return number
function UseTraitorTrap.CountNearbyAllies(bot, pos, range)
    local count = 0
    local allies = TTTBots.Roles.GetLivingAllies(bot)
    local rangeSqr = range * range
    for i = 1, #allies do
        local ply = allies[i]
        if ply == bot then continue end
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply:GetPos():DistToSqr(pos) <= rangeSqr then
            count = count + 1
        end
    end
    return count
end

--- Find the best traitor button to use right now.
---@param bot Bot
---@return Entity|nil bestButton
function UseTraitorTrap.FindBestButton(bot)
    local buttons = UseTraitorTrap.GetAllTraitorButtons()
    local botPos = bot:GetPos()
    local bestButton = nil
    local bestScore = -math.huge
    local scanRangeSqr = UseTraitorTrap.SCAN_RANGE * UseTraitorTrap.SCAN_RANGE

    for _, btn in pairs(buttons) do
        if not UseTraitorTrap.IsButtonUsable(btn) then continue end

        local btnPos = btn:GetPos()
        local distSqr = botPos:DistToSqr(btnPos)
        if distSqr > scanRangeSqr then continue end

        -- Score this button: more victims nearby = better, closer = better, allies nearby = bad
        local victimCount = UseTraitorTrap.CountNearbyVictims(bot, btnPos, UseTraitorTrap.VICTIM_RANGE)
        if victimCount < UseTraitorTrap.MIN_VICTIMS_NEARBY then continue end

        local allyCount = UseTraitorTrap.CountNearbyAllies(bot, btnPos, UseTraitorTrap.VICTIM_RANGE)
        if allyCount > 0 then continue end -- Don't activate traps near allies

        local score = (victimCount * 10) - (math.sqrt(distSqr) / 100)
        if score > bestScore then
            bestScore = score
            bestButton = btn
        end
    end

    return bestButton
end

--- Validate the behavior.
---@param bot Bot
---@return boolean
function UseTraitorTrap.Validate(bot)
    -- Check if traitor traps are enabled via cvar
    if not lib.GetConVarBool("traitor_trap") then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UseTraitorTrap.IsTraitorTeam(bot) then return false end

    -- Cooldown check
    if (bot.trapCooldown or 0) > CurTime() then return false end

    -- Already heading to a trap
    if IsValid(bot.trapTarget) then return true end

    -- Random chance gate to add variance
    if not lib.TestPercent(UseTraitorTrap.CHANCE_PER_TICK) then return false end

    -- Try to find a usable button
    local btn = UseTraitorTrap.FindBestButton(bot)
    return btn ~= nil
end

---@param bot Bot
---@return BStatus
function UseTraitorTrap.OnStart(bot)
    local btn = UseTraitorTrap.FindBestButton(bot)
    if not IsValid(btn) then return STATUS.FAILURE end

    bot.trapTarget = btn
    bot.trapStartTime = CurTime()
    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function UseTraitorTrap.OnRunning(bot)
    local btn = bot.trapTarget
    if not IsValid(btn) then return STATUS.FAILURE end
    if not UseTraitorTrap.IsButtonUsable(btn) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local btnPos = btn:GetPos()
    local dist = bot:GetPos():Distance(btnPos)

    -- Timeout: don't spend forever walking to a button
    if (CurTime() - (bot.trapStartTime or CurTime())) > 20 then
        return STATUS.FAILURE
    end

    -- Re-check that victims are still nearby (they might have moved)
    local victimCount = UseTraitorTrap.CountNearbyVictims(bot, btnPos, UseTraitorTrap.VICTIM_RANGE)
    if victimCount < UseTraitorTrap.MIN_VICTIMS_NEARBY then
        return STATUS.FAILURE -- No point anymore
    end

    -- Make sure no allies wandered into the danger zone
    local allyCount = UseTraitorTrap.CountNearbyAllies(bot, btnPos, UseTraitorTrap.VICTIM_RANGE)
    if allyCount > 0 then
        return STATUS.FAILURE -- Abort, ally is too close
    end

    -- Path towards the button
    loco:SetGoal(btnPos)

    -- Get the use range from the button entity if available, otherwise use default
    local useRange = UseTraitorTrap.USE_RANGE
    if btn.GetUsableRange then
        useRange = btn:GetUsableRange() or useRange
    end

    if dist <= useRange then
        -- We're close enough. Look at the button and press it.
        loco:LookAt(btnPos)
        loco:SetGoal() -- Stop moving

        -- Activate the trap by calling Use directly on the entity.
        -- ttt_traitor_button:Use(activator, caller) handles the traitor check internally.
        btn:Use(bot, bot)

        bot.trapCooldown = CurTime() + UseTraitorTrap.COOLDOWN
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

---@param bot Bot
function UseTraitorTrap.OnSuccess(bot)
end

---@param bot Bot
function UseTraitorTrap.OnFailure(bot)
end

---@param bot Bot
function UseTraitorTrap.OnEnd(bot)
    bot.trapTarget = nil
    bot.trapStartTime = nil
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal()
    end
end
