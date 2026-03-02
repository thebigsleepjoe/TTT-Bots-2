--- MesmeristRevive: use the Mesmerist's defibrillator to revive corpses as Thralls.

---@class BMesmeristRevive
TTTBots.Behaviors.MesmeristRevive = {}

local lib = TTTBots.Lib

---@class BMesmeristRevive
local MesRevive = TTTBots.Behaviors.MesmeristRevive
MesRevive.Name = "MesmeristRevive"
MesRevive.Description = "Revive any corpse using the mesmerist defibrillator."
MesRevive.Interruptible = true

--- Weapon class for the mesmerist defib.
MesRevive.WeaponClass = "weapon_ttt_mesdefi"

local STATUS = TTTBots.STATUS

---------------------------------------------------------------------------
-- Weapon detection
---------------------------------------------------------------------------

function MesRevive.HasDefib(bot)
    if bot:HasWeapon(MesRevive.WeaponClass) then return true end
    return lib.FindWeaponByPattern(bot, { "mesdefi", "mesmerist" }) ~= nil
end

function MesRevive.GetDefib(bot)
    local wep = bot:GetWeapon(MesRevive.WeaponClass)
    if IsValid(wep) then return wep end
    return lib.FindWeaponByPattern(bot, { "mesdefi", "mesmerist" })
end

---------------------------------------------------------------------------
-- Corpse finding — revives ANY corpse (converts to traitor)
---------------------------------------------------------------------------

function MesRevive.GetCorpse(bot)
    local options = TTTBots.Lib.GetRevivableCorpses()
    local cTime = CurTime()
    local botPos = bot:GetPos()
    local bestDist = math.huge
    local bestPly, bestRag = nil, nil

    for _, rag in pairs(options) do
        if not lib.IsValidBody(rag) then continue end
        local deadply = player.GetBySteamID64(rag.sid64)
        if not IsValid(deadply) then continue end
        if (deadply.reviveCooldown or 0) > cTime then continue end

        -- Skip corpses of existing traitor allies — no point converting them
        if TTTBots.Roles.IsAllies(bot, deadply) then continue end

        local dist = botPos:Distance(rag:GetPos())
        if dist < bestDist then
            bestDist = dist
            bestPly = deadply
            bestRag = rag
        end
    end

    -- If no non-ally corpses, fall back to any corpse
    if not bestPly then
        for _, rag in pairs(options) do
            if not lib.IsValidBody(rag) then continue end
            local deadply = player.GetBySteamID64(rag.sid64)
            if not IsValid(deadply) then continue end
            if (deadply.reviveCooldown or 0) > cTime then continue end

            local dist = botPos:Distance(rag:GetPos())
            if dist < bestDist then
                bestDist = dist
                bestPly = deadply
                bestRag = rag
            end
        end
    end

    return bestPly, bestRag
end

---------------------------------------------------------------------------
-- Spine position helper
---------------------------------------------------------------------------

function MesRevive.GetSpinePos(rag)
    local default = rag:GetPos()
    local spine = rag:LookupBone("ValveBiped.Bip01_Spine")
    if spine then
        return rag:GetBonePosition(spine)
    end
    return default
end

---------------------------------------------------------------------------
-- Revival logic
---------------------------------------------------------------------------

local function failFunc(bot, target)
    if not IsValid(target) then return end
    target.reviveCooldown = CurTime() + 30
end

local function successFunc(bot)
    -- The mesmerist addon handles its own sounds on successful revive.
end

function MesRevive.FullRevive(bot, target)
    -- Guard against round-end: don't call Revive during round transition
    if not TTTBots.Match.IsRoundActive() then return end
    if not (IsValid(bot) and IsValid(target)) then return end

    target:Revive(
        0,                                        -- delay
        nil,                                      -- OnRevive (addon handles conversion)
        nil,                                      -- DoCheck
        true,                                     -- needsCorpse
        REVIVAL_BLOCK_NONE,                       -- blockRound
        function() failFunc(bot, target) end,     -- OnFail
        nil,                                      -- spawnPos
        nil                                       -- spawnAng
    )
end

---------------------------------------------------------------------------
-- Behavior lifecycle
---------------------------------------------------------------------------

function MesRevive.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not MesRevive.HasDefib(bot) then return false end

    -- Re-use existing target if still valid
    if bot.mesRag and lib.IsValidBody(bot.mesRag) then
        return true
    end

    local corpse, rag = MesRevive.GetCorpse(bot)
    if not corpse then return false end
    if not lib.IsValidBody(rag) then return false end

    return true
end

function MesRevive.OnStart(bot)
    bot.mesTarget, bot.mesRag = MesRevive.GetCorpse(bot)
    return STATUS.RUNNING
end

function MesRevive.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defib = MesRevive.GetDefib(bot)
    local target = bot.mesTarget
    local rag = bot.mesRag
    if not (target and rag and defib) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag) and IsValid(defib)) then return STATUS.FAILURE end

    local ragPos = MesRevive.GetSpinePos(rag)

    loco:SetGoal(ragPos)
    loco:LookAt(ragPos)

    local dist = bot:GetPos():Distance(ragPos)

    if dist < 40 then
        -- Extra sneaky: Mesmerist is a traitor, reviving is very suspicious.
        -- Abort if ANY non-ally witnesses are present (not just > 1 like defib).
        local numWitnesses = #lib.GetAllWitnessesBasic(
            bot:GetPos(), TTTBots.Roles.GetNonAllies(bot)
        )
        if numWitnesses > 0 and bot.mesReviveStartTime == nil then
            return STATUS.RUNNING -- Wait for all witnesses to leave
        end

        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defib)
        loco:SetGoal()
        loco:PauseAttackCompat()
        loco:Crouch(true)
        loco:PauseRepel()

        if bot.mesReviveStartTime == nil then
            bot.mesReviveStartTime = CurTime()
        end

        -- Default revive time is 3 seconds
        if bot.mesReviveStartTime + 3 < CurTime() then
            MesRevive.FullRevive(bot, target)
            return STATUS.SUCCESS
        end
    else
        inventory:ResumeAutoSwitch()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
        loco:ResumeRepel()
        bot.mesReviveStartTime = nil
    end

    return STATUS.RUNNING
end

function MesRevive.OnSuccess(bot)
end

function MesRevive.OnFailure(bot)
end

function MesRevive.OnEnd(bot)
    bot.mesTarget = nil
    bot.mesRag = nil
    bot.mesReviveStartTime = nil

    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end

    loco:ResumeAttackCompat()
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
