--[[
    This component defines the morality of the agent. It is primarily responsible for determining who to shoot.
]]
---@class CMorality
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality
local BotMorality = TTTBots.Components.Morality

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    Kill = 9,                -- This player killed someone in front of us
    KillDetective = 10,      -- This player killed a detective in front of us
    KillTraitor = -9,        -- This player killed a traitor in front of us
    Hurt = 5,                -- This player hurt someone in front of us
    HurtMe = 10,             -- This player hurt us
    HurtDetective = 10,      -- This player hurt a detective in front of us
    KOSTrusted = 10,         -- KOS called on this player by trusted innocent
    KOS = 5,                 -- KOS called on this player
    KOSDetective = 10,       -- KOS called on this player by detective
    KOSTraitor = -5,         -- KOS called on this player by known traitor
    TraitorWeapon = 3,       -- This player has a traitor weapon
    NearUnidentified = 2,    -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -2,  -- This player has identified a traitor's corpse
    IdentifiedInnocent = 1,  -- This player has identified an innocent's corpse
    IdentifiedDetective = 1, -- This player has identified a detective's corpse
    DefuseC4 = -7,           -- This player is defusing C4
    PlantC4 = 10,            -- This player is throwing down C4
    FollowingMe = 3,         -- This player has been following me for more than 10 seconds
    ShootingAtMe = 5,        -- This player has been shooting at me
    ShootingAtSomeone = 2,   -- This player has been shooting at someone
    ShootingAtDetective = 5, -- This player has been shooting at a detective
}

function BotMorality:New(bot)
    local newMorality = {}
    setmetatable(newMorality, {
        __index = function(t, k) return BotMorality[k] end,
    })
    newMorality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Morality for bot " .. bot:Nick())
    end

    return newMorality
end

function BotMorality:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Morality = self

    self.componentID = string.format("Morality (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                       -- Tick counter
    self.bot = bot
end

function BotMorality:Think()
    local roundStarted = TTTBots.RoundActive
    if not roundStarted then return false end -- we do not care about morality
    self.tick = self.tick + 1

    lib.CallEveryNTicks(self.bot,
        function()
            self.bot.components.chatter:QuickRadio("quick_traitor", self.bot)
        end,
        15)
end

hook.Add("TTTPlayerRadioCommand", "TTTBots.Components.Morality.TTTRadioMessage", function(ply, msgName, msgTarget)
    print(ply, msgName, msgTarget)
end)

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    PrintTable(data)
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    print(victim, attacker, healthRemaining, damageTaken)
end)
