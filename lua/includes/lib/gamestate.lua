---@class Match
TTTBots.Match = {}
TTTBots.Bots = {} --- Bots in the game right now. We have to do this because of a silly bug with TTTBots.Bots

timer.Create("TTTBots.Match.UpdateBotsTable", 1, 0, function()
    TTTBots.Bots = {}
    for i, v in pairs(player.GetAll()) do
        if v:IsBot() then
            table.insert(TTTBots.Bots, v)
        end
    end
end)

---@class Match
local Match = TTTBots.Match

Match.RoundActive = Match.RoundActive or false
--- This is not a table of ragdolls but a table of corpse data.
Match.Corpses = Match.Corpses or {}
--- List of players in the round. Does not tell you if they are alive or not.
Match.PlayersInRound = Match.PlayersInRound or {}
Match.ConfirmedDead = Match.ConfirmedDead or {}
Match.DamageLogs = Match.DamageLogs or {}
Match.AlivePlayers = {}
Match.AliveTraitors = {}
Match.AliveHumanTraitors = {}
Match.AliveNonEvil = {}
Match.AlivePolice = {}
Match.DisguisedPlayers = {}
Match.SecondsPassed = 0 --- Time since match began. This is important for traitor bots.
Match.KOSCounter = {} ---@type table<Player, number>

function Match.Tick()
    if not Match.RoundActive then return end
    Match.CleanupNullCorpses()
    Match.SecondsPassed = (Match.Time()) + (1 / TTTBots.Tickrate)
end

--- Returns true if enough time, as defined by plans_mindelay and _maxdelay, has passed since the round began. Used for automatic plan execution by bots.
function Match.PlansCanStart()
    if not Match.RoundActive then return false end
    local minTime = TTTBots.Lib.GetConVarFloat("plans_mindelay")
    local time = Match.Time()
    if time < minTime then return false end
    local maxTime = TTTBots.Lib.GetConVarFloat("plans_maxdelay")
    if time > maxTime then return true end
    local randi = math.random(minTime, maxTime)
    return time > randi
end

local MAX_KOS_PER_PLY = 1
--- Check if the match should trust this individual's KOS. This is used to limit KOS calls to 1 per user per round;
--- for bots it is used to prevent chat spam.
---@param ply Player
---@param dontIterate nil|boolean (OPTIONAL=false)
---@return boolean is_trustworthy - if we can trust this player's KOS
function Match.KOSIsApproved(ply, dontIterate)
    local amt = Match.KOSCounter[ply] or 0

    if amt < MAX_KOS_PER_PLY then
        Match.KOSCounter[ply] = amt + (dontIterate and 0 or 1)
        return true
    end

    return false -- do not trust; if bot, then prevent chatting
end

--- Returns the time in seconds since the match began.
---@return number seconds
function Match.Time()
    return (Match.RoundActive and Match.SecondsPassed) or 0
end

function Match.IsRoundActive()
    return Match.RoundActive
end

function Match.CleanupNullCorpses()
    for i, v in pairs(Match.Corpses) do
        if not IsValid(v) or v == NULL then
            table.remove(Match.Corpses, i)
            print("Cleaned up null corpse")
        end
    end
end

function Match.ResetStats(roundActive)
    Match.RoundActive = roundActive or false
    Match.Corpses = {}
    Match.ConfirmedDead = {}
    Match.PlayersInRound = {}
    Match.DamageLogs = {}
    Match.AlivePlayers = {}
    Match.AliveTraitors = {}
    Match.AliveHumanTraitors = {}
    Match.AliveNonEvil = {}
    Match.AlivePolice = {}
    Match.SecondsPassed = 0
    Match.DisguisedPlayers = {}
    Match.KOSCounter = {} ---@type table<Player, number>

    -- Just gonna put this here since it's related to resetting stats.
    for i, v in pairs(TTTBots.Bots) do
        v:SetAttackTarget(nil)
    end
end

---Gets the difficulty scoring of the given bot. Returns -1 if the bot is not a TTTBot.
---@param bot Player
---@return number difficulty
function Match.GetBotDifficulty(bot)
    local personality = TTTBots.Lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return -1 end
    local diff = personality:GetTraitAdditive("difficulty")
    return diff
end

--- Returns a table of all bots in the game, indexed by bot object, with each key as the estimated difficulty score.
---@return table<bot, number> botDifficulty
function Match.GetBotsDifficulty()
    local tbl = {}
    for i, bot in pairs(TTTBots.Bots) do
        local diff = Match.GetBotDifficulty(bot)
        tbl[bot] = diff
    end
    return tbl
end

--- Comb thru the damage logs and find the player who shot the other first.
function Match.WhoShotFirst(ply1, ply2)
    local hansolo = nil
    local oldestTime = math.huge
    for i, log in pairs(Match.DamageLogs) do
        if (log.victim == ply1 or log.attacker == ply1) and (log.victim == ply2 or log.attacker == ply2) then
            if log.time < oldestTime then
                oldestTime = log.time
                hansolo = log.attacker
            end
        end
    end
    return hansolo -- hehehehe get it?
end

function Match.UpdateAlivePlayers()
    Match.AlivePlayers = {}
    Match.AliveHumanTraitors = {}
    Match.AliveNonEvil = {}
    Match.AliveTraitors = {}
    Match.DisguisedPlayers = {}
    for bot, isAlive in pairs(TTTBots.Lib.GetPlayerLifeStates()) do
        if not (bot and isAlive) then continue end
        table.insert(Match.AlivePlayers, bot)
        if TTTBots.Lib.IsEvil(bot, true) then
            if not bot:IsBot() then
                table.insert(Match.AliveHumanTraitors, bot)
            else
                table.insert(Match.AliveTraitors, bot)
            end
        elseif TTTBots.Lib.IsPolice(bot) then
            table.insert(Match.AliveNonEvil, bot)
            table.insert(Match.AlivePolice, bot)
        else
            table.insert(Match.AliveNonEvil, bot)
        end

        -- Check if player is disguised, and if so, add them to the disguised tbl
        local isDisguised = bot:GetNWBool("disguised", false)
        if isDisguised then
            Match.DisguisedPlayers[bot] = true
        end
    end
end

function Match.IsPlayerDisguised(ply)
    return Match.DisguisedPlayers[ply] or false
end

timer.Create("TTTBots.Match.UpdateAlivePlayers", 0.34, 0, function()
    Match.UpdateAlivePlayers()
end)

hook.Add("TTTBeginRound", "Match.BeginRound", function()
    Match.ResetStats(true)
    for _, ply in pairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            Match.PlayersInRound[ply] = true
        end
    end
    Match.UpdateAlivePlayers()
end)

hook.Add("TTTEndRound", "Match.EndRound", function()
    Match.ResetStats(false)
end)

hook.Add("TTTPrepareRound", "Match.PrepareRound", function()
    Match.ResetStats(false)
end)

hook.Add("TTTOnCorpseCreated", "Match.OnCorpseCreated", function(corpse)
    if not Match.RoundActive then return end
    table.insert(Match.Corpses, corpse)
end)

hook.Add("TTTBodyFound", "Match.BodyFound", function(discoverer, deceased, ragdoll)
    if not Match.RoundActive then return end
    if not IsValid(deceased) then return end
    if not deceased:IsPlayer() then return end
    if not Match.PlayersInRound[deceased] then return end
    Match.ConfirmedDead[deceased] = true
end)

hook.Add("PlayerHurt", "Match.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not Match.RoundActive then return end
    if not (IsValid(victim) and IsValid(attacker) and victim:IsPlayer() and attacker:IsPlayer()) then return end
    table.insert(Match.DamageLogs, {
        victim = victim,
        attacker = attacker,
        healthRemaining = healthRemaining,
        damageTaken = damageTaken,
        time = CurTime()
    })
end)
