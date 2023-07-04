TTTBots.Match = {}

local Match = TTTBots.Match

Match.RoundActive = Match.RoundActive or false
--- This is not a table of ragdolls but a table of corpse data.
Match.Corpses = Match.Corpses or {}
--- List of players in the round. Does not tell you if they are alive or not.
Match.PlayersInRound = Match.PlayersInRound or {}
Match.ConfirmedDead = Match.ConfirmedDead or {}
Match.DamageLogs = Match.DamageLogs or {}
Match.AlivePlayers = {}

function Match.ResetStats(roundActive)
    Match.RoundActive = roundActive or false
    Match.Corpses = {}
    Match.ConfirmedDead = {}
    Match.PlayersInRound = {}
    Match.DamageLogs = {}
    Match.AlivePlayers = {}
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
    for i, v in pairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(v) then
            table.insert(Match.AlivePlayers, v)
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
            Match.PlayersInRound[ply:Nick()] = true
            table.insert(Match.AlivePlayers, ply)
        end
    end
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
    if not Match.PlayersInRound[deceased:Nick()] then return end
    Match.ConfirmedDead[deceased:Nick()] = true
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
