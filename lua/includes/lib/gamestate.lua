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
Match.SecondsPassed = 0 --- Time since match began. This is important for traitor bots.

function Match.Tick()
    if not Match.RoundActive then return end
    Match.CleanupNullCorpses()
    Match.SecondsPassed = (Match.SecondsPassed or 0) + (1 / TTTBots.Tickrate)
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

    -- Just gonna put this here since it's related to resetting stats.
    for i, v in pairs(TTTBots.Bots) do
        v.attackTarget = nil
    end
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
    for i, v in pairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(v) then
            table.insert(Match.AlivePlayers, v)
            if TTTBots.Lib.IsEvil(v, true) then
                if not v:IsBot() then
                    table.insert(Match.AliveHumanTraitors, v)
                else
                    table.insert(Match.AliveTraitors, v)
                end
            elseif TTTBots.Lib.IsPolice(v) then
                table.insert(Match.AliveNonEvil, v)
                table.insert(Match.AlivePolice, v)
            else
                table.insert(Match.AliveNonEvil, v)
            end
        end
    end
end

timer.Create("TTTBots.Match.UpdateAlivePlayers", 1, 0, function()
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
