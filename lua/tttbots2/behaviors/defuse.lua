TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Defuse = {}

local lib = TTTBots.Lib

local Defuse = TTTBots.Behaviors.Defuse
Defuse.Name = "Defuse"
Defuse.Description = "Defuse a spotted bomb"
Defuse.Interruptible = true

Defuse.DEFUSE_RANGE = 80       --- The maximum range that a defuse attempt can be made
Defuse.ABANDON_TIME = 5        --- Seconds until explosion to abandon defuse attempt
Defuse.DEFUSE_WIN_CHANCE = 3   --- 1 in X chance of a successful defuse
Defuse.DEFUSE_TRY_CHANCE = 30  --- 1 in X chance of attempting to defuse (per tick) if other conditions not met
Defuse.DEFUSE_TIME_DELAY = 1.5 --- Seconds to wait before defusing (when within range!)

local STATUS = TTTBots.STATUS


---Returns true if a bot is able to defuse C4 per their role data.
---@param bot Bot
---@return boolean
function Defuse.IsBotEligableRole(bot)
    local role = TTTBots.Roles.GetRoleFor(bot) ---@type RoleData
    if not role then return false end
    return role:GetDefusesC4()
end

---Return whether or not a bot is elligible to defuse a C4 (does not factor in if there is one nearby)
---@param bot Bot
---@return boolean
function Defuse.IsEligible(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not Defuse.IsBotEligableRole(bot) then return false end

    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return false end

    local isDefuser = personality:GetTraitBool("defuser")
    -- weapon_ttt_defuser
    local hasDefuseKit = bot:HasWeapon("weapon_ttt_defuser")
    local chance = math.random(1, Defuse.DEFUSE_TRY_CHANCE) == 1

    if hasDefuseKit or isDefuser or chance then
        return true
    end

    return false
end

---Returns the first visible C4 that has been spotted
---@param bot Bot
---@return Entity|nil C4
function Defuse.GetVisibleC4(bot)
    local allC4 = TTTBots.Match.AllArmedC4s
    for bomb, _ in pairs(allC4) do
        if not Defuse.IsC4Defusable(bomb) then continue end
        if lib.CanSeeArc(bot, bomb:GetPos() + Vector(0, 0, 16), 120) then
            return bomb
        end
    end

    return nil
end

--- Validate the behavior
function Defuse.Validate(bot)
    if not lib.GetConVarBool("defuse_c4") then return false end -- This behavior is disabled per the user's choice.
    if not TTTBots.Match.IsRoundActive() then return false end
    if not Defuse.IsBotEligableRole(bot) then return false end
    if bot.defuseTarget ~= nil then return true end
    if not Defuse.IsEligible(bot) then return false end
    return Defuse.GetVisibleC4(bot) ~= nil
end

--- Called when the behavior is started
function Defuse.OnStart(bot)
    bot.defuseTarget = Defuse.GetVisibleC4(bot)

    local chatter = lib.GetComp(bot, "chatter") ---@type CChatter
    if not chatter then return end
    chatter:On("DefusingC4")
end

function Defuse.IsC4Defusable(c4)
    if c4 == NULL then return false end
    if not IsValid(c4) then return false end
    if not c4:GetArmed() then return false end
    if c4:GetExplodeTime() <= CurTime() then return false end

    return true
end

function Defuse.GetTimeUntilExplode(c4)
    local explodeTime = c4:GetExplodeTime()
    local ct = CurTime()
    return explodeTime - ct
end

---Wrapper function to defuse a C4; called internally by Defuse.TryDefuse
---@param bot Bot
---@param c4 Entity
---@param isSuccess boolean If true then actually defuses, otherwise KABOOM!
function Defuse.DefuseC4(bot, c4, isSuccess)
    if (bot.lastDefuseTime or 0) + Defuse.DEFUSE_TIME_DELAY > CurTime() then return end
    bot.lastDefuseTime = CurTime()
    timer.Simple(Defuse.DEFUSE_TIME_DELAY, function()
        if not Defuse.IsC4Defusable(c4) then return end
        if not (bot and lib.IsPlayerAlive(bot)) then return end
        if isSuccess then
            c4:Disarm(bot)

            local chatter = lib.GetComp(bot, "chatter") ---@type CChatter
            if not chatter then return end
            chatter:On("DefusingSuccessful")
            Defuse.DestroyC4(c4)
        else
            c4:FailedDisarm(bot)
            -- No need to chat. We are dead.
        end
    end)
end

function Defuse.TryDefuse(bot, c4)
    local dist = bot:GetPos():Distance(c4:GetPos())
    local hasDefuser = bot:HasWeapon("weapon_ttt_defuser")

    if (dist > Defuse.DEFUSE_RANGE) then return false end

    if hasDefuser then
        Defuse.DefuseC4(bot, c4, true)
        return true
    end

    local isSuccessful = math.random(1, Defuse.DEFUSE_WIN_CHANCE) == 1
    Defuse.DefuseC4(bot, c4, isSuccessful)

    return isSuccessful
end

function Defuse.DestroyC4(c4)
    util.EquipmentDestroyed(c4:GetPos())
    c4:Remove()
end

function Defuse.ShouldAbandon(c4)
    local timeUntilExplode = Defuse.GetTimeUntilExplode(c4)
    return timeUntilExplode <= Defuse.ABANDON_TIME
end

--- Called when the behavior's last state is running
function Defuse.OnRunning(bot)
    local bomb = bot.defuseTarget
    if not Defuse.IsC4Defusable(bomb) then
        return STATUS.FAILURE
    end

    if Defuse.ShouldAbandon(bomb) then
        return STATUS.FAILURE
    end

    local isSuccessful = Defuse.TryDefuse(bot, bomb)
    if isSuccessful then
        return STATUS.SUCCESS
    end

    local locomotor = lib.GetComp(bot, "locomotor") ---@type CLocomotor
    if not locomotor then return STATUS.FAILURE end

    local bombPos = bomb:GetPos()
    locomotor:SetGoal(bombPos)
    locomotor:LookAt(bombPos)

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function Defuse.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Defuse.OnFailure(bot)
end

--- Called when the behavior ends
function Defuse.OnEnd(bot)
    bot.defuseTarget = nil
end
