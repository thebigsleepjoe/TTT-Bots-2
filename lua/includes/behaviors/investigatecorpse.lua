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

function InvestigateCorpse:GetVisibleUnidentified(bot)
    local corpses = TTTBots.Match.Corpses
    local results = {}
    for i, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        local visible = bot:Visible(corpse)
        local found = CORPSE.GetFound(corpse, false)
        -- TTTBots.DebugServer.DrawCross(corpse:GetPos(), 10, Color(255, 0, 0), 1, "body")
        if not found and visible then
            table.insert(results, corpse)
        end
    end
    return results
end

--- Called every tick; basically just rolls a dice for if we should investigate any corpses this tick
function InvestigateCorpse:GetShouldNoticeCorpse(bot)
    local basePct = 100
    -- TODO: Personality should affect this
    local mult = 1
    return lib.CalculatePercentChance(basePct * mult)
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
    local curCorpse = bot.corpseTarget
    if self:CorpseValid(curCorpse) then
        return true
    end

    local options = self:GetVisibleUnidentified(bot)
    if options and #options == 0 then return false end

    local closest = lib.GetClosest(options, bot:GetPos())
    if not self:CorpseValid(closest) then return false end

    local unreachable = TTTBots.PathManager.IsUnreachableVec(bot:GetPos(), closest:GetPos())
    if not unreachable then return false end

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
