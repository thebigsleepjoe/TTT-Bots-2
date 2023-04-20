TTTBots.RoundActive = TTTBots.RoundActive or false
--- This is not a table of ragdolls but a table of corpse data.
TTTBots.Corpses = TTTBots.Corpses or {}
TTTBots.PlayersInRound = TTTBots.PlayersInRound or {}
TTTBots.ConfirmedDead = TTTBots.ConfirmedDead or {}

--[[
TTTPrepareRound means roundactive = false
TTTBeginRound means roundactive = true
TTTEndRound means roundactive = false
]]
local function resetStats(roundActive)
    TTTBots.RoundActive = roundActive
    TTTBots.Corpses = {}
    TTTBots.ConfirmedDead = {}
    TTTBots.PlayersInRound = {}
end

hook.Add("TTTBeginRound", "TTTBots.BeginRound", function()
    resetStats(true)
    for _, ply in pairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            TTTBots.PlayersInRound[ply:Nick()] = true
        end
    end
end)

hook.Add("TTTEndRound", "TTTBots.EndRound", function()
    resetStats(false)
end)

hook.Add("TTTPrepareRound", "TTTBots.PrepareRound", function()
    resetStats(false)
end)

hook.Add("TTTOnCorpseCreated", "TTTBots.OnCorpseCreated", function(corpse)
    if not TTTBots.RoundActive then return end
    table.insert(TTTBots.Corpses, corpse)
end)

hook.Add("TTTBodyFound", "TTTBots.BodyFound", function(discoverer, deceased, ragdoll)
    if not TTTBots.RoundActive then return end
    if not IsValid(deceased) then return end
    if not deceased:IsPlayer() then return end
    if not TTTBots.PlayersInRound[deceased:Nick()] then return end
    TTTBots.ConfirmedDead[deceased:Nick()] = true
end)
