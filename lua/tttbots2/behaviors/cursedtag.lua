--- CursedTag: find an isolated player and tag them with +USE to swap roles.
---
--- The Cursed cannot deal damage and cannot win, so this is purely about
--- getting close to someone and interacting with them.

---@class BCursedTag
TTTBots.Behaviors.CursedTag = {}

local lib = TTTBots.Lib

---@class BCursedTag
local CursedTag = TTTBots.Behaviors.CursedTag
CursedTag.Name = "CursedTag"
CursedTag.Description = "Chase a player and tag them to swap roles."
CursedTag.Interruptible = true

local STATUS = TTTBots.STATUS

--- Range within which the bot will attempt to +USE tag the target.
--- The addon's default is ttt2_cursed_tag_dist = 150 units.
CursedTag.TAG_RANGE = 140

--- How often to re-evaluate targets (seconds).
CursedTag.RETARGET_INTERVAL = 4

---------------------------------------------------------------------------
-- Target selection
---------------------------------------------------------------------------

--- Find the best player to tag. Prefers isolated players we can reach.
--- Excludes the player we just swapped with ("no backsies").
---@param bot Bot
---@return Player?
function CursedTag.FindTarget(bot)
    local candidates = {}
    local botPos = bot:GetPos()

    for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
        if not (IsValid(ply) and ply ~= bot) then continue end

        -- Skip the "no backsies" target if the addon tracks it
        if bot.cursedLastSwap and bot.cursedLastSwap == ply then continue end

        -- Rate isolation — more isolated = easier to tag
        local isolation = lib.RateIsolation(bot, ply)
        local dist = botPos:Distance(ply:GetPos())

        -- Weight: prefer close + isolated targets
        local score = isolation - (dist * 0.001)
        table.insert(candidates, { ply = ply, score = score })
    end

    if #candidates == 0 then return nil end

    -- Sort by score descending
    table.sort(candidates, function(a, b) return a.score > b.score end)

    return candidates[1].ply
end

--- Check if the bot has a RoleSwap Deagle.
---@param bot Bot
---@return Weapon?
function CursedTag.GetDeagle(bot)
    return lib.FindWeaponByPattern(bot, { "cursed", "roleswap", "curs" })
end

---------------------------------------------------------------------------
-- Behavior lifecycle
---------------------------------------------------------------------------

function CursedTag.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end

    -- Only valid if we're actually Cursed
    local role = bot:GetRoleStringRaw()
    if role ~= "cursed" then return false end

    return true
end

function CursedTag.OnStart(bot)
    bot.cursedTarget = CursedTag.FindTarget(bot)
    bot.cursedNextRetarget = CurTime() + CursedTag.RETARGET_INTERVAL
    return STATUS.RUNNING
end

function CursedTag.OnRunning(bot)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Periodically re-evaluate target
    if not bot.cursedTarget or not IsValid(bot.cursedTarget)
        or not lib.IsPlayerAlive(bot.cursedTarget)
        or CurTime() > (bot.cursedNextRetarget or 0) then

        bot.cursedTarget = CursedTag.FindTarget(bot)
        bot.cursedNextRetarget = CurTime() + CursedTag.RETARGET_INTERVAL
    end

    local target = bot.cursedTarget
    if not (target and IsValid(target)) then return STATUS.RUNNING end

    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Navigate toward the target
    loco:SetGoal(targetPos)
    loco:LookAt(targetPos + Vector(0, 0, 40))

    if dist < CursedTag.TAG_RANGE then
        -- Close enough to tag — look directly at the target and press USE.
        -- The addon detects the USE key input via PlayerUse/KeyPress hooks,
        -- which relies on GMod's internal eye trace. The bot MUST actually be
        -- facing the target when IN_USE fires, not just have a pending LookAt.
        local targetEyePos = target:GetPos() + Vector(0, 0, 40)
        loco:LookAt(targetEyePos)

        -- Check if we're actually facing the target before pressing USE.
        -- RotateEyeAnglesTo interpolates, so we may not be aimed yet.
        local eyeAng = bot:EyeAngles()
        local aimDir = eyeAng:Forward()
        local toTarget = (targetEyePos - bot:GetShootPos()):GetNormalized()
        local dot = aimDir:Dot(toTarget)

        -- dot > 0.95 ≈ within ~18 degrees — close enough for USE trace to hit
        if dot > 0.95 then
            -- Rate-limit so we don't spam USE every tick
            if not bot.cursedLastUseTime or (CurTime() - bot.cursedLastUseTime) > 0.3 then
                loco:PressUse()
                bot.cursedLastUseTime = CurTime()
            end
        end

        -- Check if swap occurred (role changed away from cursed)
        local ok, role = pcall(bot.GetRoleStringRaw, bot)
        if ok and role ~= "cursed" then
            bot.cursedLastSwap = target
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    elseif dist < 800 then
        -- Medium range: try using the RoleSwap Deagle if we have one
        local deagle = CursedTag.GetDeagle(bot)
        if deagle and IsValid(deagle) then
            local canSee = lib.CanSeeArc(bot, targetPos + Vector(0, 0, 40), 30)
            if canSee then
                local inventory = bot:BotInventory()
                if inventory then inventory:PauseAutoSwitch() end
                pcall(bot.SelectWeapon, bot, deagle:GetClass())
                loco:LookAt(targetPos + Vector(0, 0, 40))

                -- Shoot the deagle at the target via locomotor
                loco:StartAttack()
                timer.Simple(0.3, function()
                    if not IsValid(bot) then return end
                    if not TTTBots.Match.IsRoundActive() then return end
                    local l = bot:BotLocomotor()
                    if l then l:StopAttack() end
                    local inv = bot:BotInventory()
                    if inv then inv:ResumeAutoSwitch() end
                end)
            end
        end
    end

    return STATUS.RUNNING
end

function CursedTag.OnSuccess(bot)
end

function CursedTag.OnFailure(bot)
end

function CursedTag.OnEnd(bot)
    bot.cursedTarget = nil
    bot.cursedNextRetarget = nil
    bot.cursedLastUseTime = nil

    -- Clear locomotor goal to prevent "Owner must be a living player" errors
    -- during Cursed resurrection (bot dies but entity stays valid with components)
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal()
        loco:StopAttack()
    end
end
