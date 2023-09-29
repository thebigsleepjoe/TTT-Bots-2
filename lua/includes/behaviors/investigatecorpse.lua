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

--- Validate the behavior
function InvestigateCorpse:Validate(bot)
    -- lib.IsGood(bot) and (self:GetShouldNoticeCorpse(bot) and #self:GetVisibleUnidentified(bot) > 0)
    local isGood = lib.IsGood(bot)
    -- local shouldNotice = self:GetShouldNoticeCorpse(bot)
    local visibleUnidentified = #self:GetVisibleUnidentified(bot) > 0
    return isGood and visibleUnidentified
end

--- Called when the behavior is started
function InvestigateCorpse:OnStart(bot)
    local visibleCorpses = self:GetVisibleUnidentified(bot)
    if #visibleCorpses == 0 then return STATUS.FAILURE end

    local closestCorpse = lib.GetClosest(visibleCorpses, bot:GetPos())
    if closestCorpse == nil then return STATUS.FAILURE end

    bot.corpseToID = closestCorpse
    bot.components.chatter:On("CorpseSpotted", { corpse = bot.corpseToID })
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function InvestigateCorpse:OnRunning(bot)
    if CORPSE.GetFound(bot.corpseToID, false) then
        return STATUS.SUCCESS
    end
    if not CORPSE.IsValidBody(bot.corpseToID) then
        return STATUS.FAILURE
    end
    local loco = bot.components.locomotor
    loco:AimAt(bot.corpseToID:GetPos())
    loco:SetGoalPos(bot.corpseToID:GetPos())

    local distToBody = bot:GetPos():Distance(bot.corpseToID:GetPos())
    if distToBody < 80 then
        loco:Stop()
        CORPSE.ShowSearch(bot, bot.corpseToID, false, false)
        CORPSE.SetFound(bot.corpseToID, true)
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
    bot.corpseToID = nil
end
