--- This file is a base behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta

TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BDefib
TTTBots.Behaviors.Defib = {}

local lib = TTTBots.Lib

---@class BDefib
local Defib = TTTBots.Behaviors.Defib
Defib.Name = "Defib"
Defib.Description = "Use the defibrillator on a corpse."
Defib.Interruptible = true
Defib.WeaponClasses = { "weapon_ttt_defibrillator" }

---@enum BStatus
local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

local function printf(...) print(string.format(...)) end

---Get the closest revivable corpse to our bot
---@param bot any
---@param allyOnly boolean
---@return Player? closest
---@return any? ragdoll
function Defib.GetCorpse(bot, allyOnly)
    local closest, rag = TTTBots.Lib.GetClosestRevivable(bot, allyOnly or true)
    if not closest then return end

    -- local canSee = lib.CanSeeArc(bot, rag:GetPos() + Vector(0, 0, 16), 120)
    -- print(canSee)
    -- if canSee then
    return closest, rag
    -- end
end

function Defib.HasDefib(bot)
    for i, class in pairs(Defib.WeaponClasses) do
        if bot:HasWeapon(class) then return true end
    end

    return false
end

function Defib.GetDefib(bot)
    for i, class in pairs(Defib.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
end

local function failFunc(bot, target)
    target.reviveCooldown = CurTime() + 30
    local defib = Defib.GetDefib(bot)
    if not IsValid(defib) then return end

    defib:StopSound("hum")
    defib:PlaySound("beep")
end

local function startFunc(bot)
    local defib = Defib.GetDefib(bot)
    if not IsValid(defib) then return end

    defib:PlaySound("hum")
end

local function successFunc(bot)
    local defib = Defib.GetDefib(bot)
    if not IsValid(defib) then return end

    defib:StopSound("hum")
    defib:PlaySound("zap")

    timer.Simple(1, function()
        if not IsValid(defib) then return end
        defib:Remove()
    end)
end
---Revives a player from the dead, assuming the target is alive
---@param bot Player
---@param target Player
function Defib.FullDefib(bot, target)
    print("Running FullDefib on " .. target:Nick())
    target:Revive(
        0,                                    -- delay number=3
        function() successFunc(bot) end,      -- OnRevive function?
        nil,                                  -- DoCheck function?
        true,                                 -- needsCorpse
        REVIVAL_BLOCK_NONE,                   -- blockRound number=REVIVAL_BLOCK_NONE
        function() failFunc(bot, target) end, -- OnFail function?
        nil,                                  -- spawnPos Vector?
        nil                                   -- spawnAng Angle?
    )
end

function Defib.ValidateCorpse(bot, corpse)
    return lib.IsValidBody(corpse or bot.defibRag)
end

function Defib.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.preventDefib then return false end         -- just an extra feature to prevent defibbing

    -- cant defib without defib
    local hasDefib = Defib.HasDefib(bot)
    if not hasDefib then return false end

    -- re-use existing
    local hasCorpse = Defib.ValidateCorpse(bot, bot.defibRag)
    if hasCorpse then return true end

    -- get new target
    local corpse, rag = Defib.GetCorpse(bot, true)
    if not corpse then return false end

    -- one last valid check
    local cValid = Defib.ValidateCorpse(bot, rag)
    if not cValid then return false end
end

function Defib.OnStart(bot)
    bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, true)


    return STATUS.RUNNING
end

function Defib.GetSpinePos(rag)
    local default = rag:GetPos()

    local spineName = "ValveBiped.Bip01_Spine"
    local spine = rag:LookupBone(spineName)

    if spine then
        return rag:GetBonePosition(spine)
    end

    return default
end

---@param bot Player
function Defib.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defib = Defib.GetDefib(bot)
    local target = bot.defibTarget
    local rag = bot.defibRag
    if not (IsValid(target) and IsValid(rag) and IsValid(defib)) then return STATUS.FAILURE end
    local ragPos = Defib.GetSpinePos(rag)

    loco:SetGoal(ragPos)
    loco:LookAt(ragPos)

    if loco:IsCloseEnough(ragPos) then
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defib)
        loco:SetGoal() -- reset goal to stop moving
        loco:PauseAttackCompat()
        loco:Crouch(true)
        loco:PauseRepel()
        if bot.defibStartTime == nil then
            bot.defibStartTime = bot.defibStartTime
            print(bot:Nick() .. " trying to defib a teammate Calling startfunc!")
            startFunc(bot)
        end
        if bot.defibStartTime + 3 < CurTime() then
            Defib.FullDefib(bot, target)
            return STATUS.SUCCESS
        end
    else
        inventory:ResumeAutoSwitch()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
        loco:ResumeRepel()
        bot.defibStartTime = nil
    end

    return STATUS.RUNNING
end

function Defib.OnSuccess(bot) end

function Defib.OnFailure(bot) end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Player
function Defib.OnEnd(bot)
    bot.defibTarget, bot.defibRag = nil, nil
    bot.defibStartTime = nil
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end

    loco:ResumeAttackCompat()
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
