TTTBots.Behaviors = TTTBots.Behaviors or {}
---@class InvestigateCorpse
TTTBots.Behaviors.InvestigateCorpse = {}

local lib = TTTBots.Lib
---@class InvestigateCorpse
local InvestigateCorpse = TTTBots.Behaviors.InvestigateCorpse
InvestigateCorpse.Name = "InvestigateCorpse"
InvestigateCorpse.Description = "Investigate the corpse of a fallen player"
InvestigateCorpse.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

---@deprecated deprecated until distance check, technically works tho
function InvestigateCorpse:GetVisibleCorpses(bot)
    local corpses = TTTBots.Match.Corpses
    local visibleCorpses = {}
    for i, corpse in pairs(corpses) do
        local visible = bot:VisibleVec(corpse:GetPos())
        if visible then
            table.insert(visibleCorpses, corpse)
        end
    end
    return visibleCorpses
end

local CORPSE_MAXDIST = 2000
function InvestigateCorpse:GetVisibleUnidentified(bot)
    local corpses = TTTBots.Match.Corpses
    local results = {}
    for i, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        local visible = bot:Visible(corpse)
        local found = CORPSE.GetFound(corpse, false)
        local distTo = bot:GetPos():Distance(corpse:GetPos())
        -- TTTBots.DebugServer.DrawCross(corpse:GetPos(), 10, Color(255, 0, 0), 1, "body")
        if not found and visible and distTo < CORPSE_MAXDIST then
            table.insert(results, corpse)
        end
    end
    return results
end

--- Called every tick; basically just rolls a dice for if we should investigate any corpses this tick
function InvestigateCorpse:GetShouldInvestigateCorpses(bot)
    local BASE_PCT = 75
    local MIN_PCT = 5
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return false end
    local mult = personality:GetTraitMult("investigateCorpse")
    return lib.CalculatePercentChance(
        math.max(MIN_PCT, BASE_PCT * mult)
    )
end

function InvestigateCorpse:CorpseValid(rag)
    if rag == nil then return false, "nil" end                          -- The corpse is nil.
    if not IsValid(rag) then return false, "invalid" end                -- The corpse is invalid.
    if not CORPSE.IsValidBody(rag) then return false, "invalidbody" end -- The corpse is not a valid body.
    if CORPSE.GetFound(rag, false) then return false, "discovered" end  -- The corpse was discovered.

    return true, "valid"
end

--- Validate the behavior
function InvestigateCorpse:Validate(bot)
    if not self:GetShouldInvestigateCorpses(bot) then return false end

    -- First, let's prevent traitors from immediately self-reporting.
    local lastKillTime = bot.lastKillTime or 0
    local killedRecently = (CurTime() - lastKillTime) < 7 -- killed someone within X seconds
    if killedRecently then return false end

    local curCorpse = bot.corpseTarget
    if self:CorpseValid(curCorpse) then
        return true
    end

    local options = self:GetVisibleUnidentified(bot)
    if options and #options == 0 then return false end

    local closest = lib.GetClosest(options, bot:GetPos())
    if not self:CorpseValid(closest) then return false end

    -- local unreachable = TTTBots.PathManager.IsUnreachableVec(bot:GetPos(), closest:GetPos())
    -- if not unreachable then
    --     print("Found corpse but it was unreachable")
    --     return false
    -- end

    bot.corpseTarget = closest
    return true
end

--- Called when the behavior is started
function InvestigateCorpse:OnStart(bot)
    bot.components.chatter:On("InvestigateCorpse", { corpse = bot.corpseTarget })
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function InvestigateCorpse:OnRunning(bot)
    local validation, result = self:CorpseValid(bot.corpseTarget)
    if not validation then
        return STATUS.FAILURE
    end
    local loco = bot.components.locomotor
    loco:AimAt(bot.corpseTarget:GetPos())
    loco:SetGoalPos(bot.corpseTarget:GetPos())

    local distToBody = bot:GetPos():Distance(bot.corpseTarget:GetPos())
    if distToBody < 80 then
        loco:Stop()
        CORPSE.ShowSearch(bot, bot.corpseTarget, false, false)
        CORPSE.SetFound(bot.corpseTarget, true)
        return STATUS.SUCCESS
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function InvestigateCorpse:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function InvestigateCorpse:OnFailure(bot)
end

--- Called when the behavior ends
function InvestigateCorpse:OnEnd(bot)
    bot.corpseTarget = nil
end
