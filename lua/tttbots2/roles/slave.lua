--- Slave role support for TTT Bots 2.
--- A converted player who follows and assists the Brainwasher master.
--- Behaves like a Sidekick: follows master, helps in fights, defends master.
--- When the Brainwasher dies, Slaves revert to Innocent behavior but retain
--- memory of who the traitors are (via suspicion injection).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SLAVE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- Behavior tree: Follow and protect the master, similar to Sidekick.
local bTree = {
    _prior.FightBack,           -- Always fight back when attacked
    _bh.Defib,                  -- Revive allies if possible
    _bh.UseTraitorTrap,         -- Activate map traitor traps when non-allies are nearby
    _prior.Restore,             -- Heal / pick up weapons
    _bh.FollowMaster,           -- Follow and assist the Brainwasher master
    _bh.InvestigateCorpse,      -- Investigate corpses
    _prior.Minge,               -- Occasional minging
    _prior.Investigate,         -- Investigate noises
    _prior.Patrol               -- Patrol / wander
}

local slave = TTTBots.RoleData.New("slave", TEAM_TRAITOR)
slave:SetDefusesC4(false)
slave:SetPlantsC4(false)
slave:SetCanHaveRadar(false)
slave:SetCanCoordinate(false)       -- Follows the master, doesn't lead plans
slave:SetStartsFights(false)        -- Defensive, protects master
slave:SetTeam(TEAM_TRAITOR)
slave:SetUsesSuspicion(false)       -- Knows teams (traitor side)
slave:SetKnowsLifeStates(true)
slave:SetBTree(bTree)
slave:SetLovesTeammates(true)
slave:SetAlliedTeams({ [TEAM_TRAITOR] = true, [TEAM_JESTER or 'jesters'] = true })
slave:SetCanSnipe(false)
slave:SetCanHide(false)
TTTBots.Roles.RegisterRole(slave)

--- Slave helps/defends the Brainwasher master
TTTBots.Lib.RegisterMasterMinionHooks("slave", "brainwasher", "TTTBots_Slave")

--- When the Brainwasher dies, all bot Slaves that revert to Innocent need
--- their suspicion system updated so they remember who the traitors were.
--- The Brainwasher addon handles the actual role change (slave -> innocent)
--- via its PostPlayerDeath hook. We hook slightly after to inject knowledge.
hook.Add("PostPlayerDeath", "TTTBots_SlaveRevertOnMasterDeath", function(deadPly)
    -- Only trigger when a brainwasher dies
    if not IsValid(deadPly) then return end
    if deadPly:GetSubRole() ~= ROLE_BRAINWASHER then return end

    -- Check the slave_mode cvar -- mode 1 means slaves revert to innocent
    local slaveMode = GetConVar("ttt2_slave_mode")
    if not slaveMode or slaveMode:GetInt() ~= 1 then return end

    -- Small delay to let the Brainwasher addon's role-change happen first
    timer.Simple(0.5, function()
        if not TTTBots.Match.IsRoundActive() then return end

        for _, bot in pairs(TTTBots.Bots) do
            if not (IsValid(bot) and bot ~= NULL and TTTBots.Lib.IsPlayerAlive(bot)) then continue end

            -- After reversion, the bot is now innocent (role change already happened)
            local roleStr = bot:GetRoleStringRaw()
            if roleStr ~= "innocent" then continue end

            -- Check if this bot was recently a slave (the addon clears binded_slave,
            -- so we check our own tracking flag)
            if not bot.tttbots_wasSlaveOf then continue end
            if bot.tttbots_wasSlaveOf ~= deadPly then continue end

            -- This bot was a slave of the dead brainwasher and is now innocent.
            -- Inject traitor knowledge into their suspicion system.
            local morality = bot.components and bot.components.morality
            if not morality then continue end

            -- The bot now uses suspicion again as an innocent
            -- Inject KOS-level suspicion on all known traitors
            for _, ply in pairs(player.GetAll()) do
                if not (IsValid(ply) and ply:IsPlayer() and TTTBots.Lib.IsPlayerAlive(ply)) then continue end
                if ply == bot then continue end

                local plyTeam = ply:GetTeam()
                if plyTeam == TEAM_TRAITOR then
                    -- Set suspicion high enough for KOS (threshold is 7)
                    morality.suspicions[ply] = math.max(morality:GetSuspicion(ply), 10)
                    morality:AnnounceIfThreshold(ply)
                    morality:SetAttackIfTargetSus(ply)
                end
            end

            -- Clear the tracking flag
            bot.tttbots_wasSlaveOf = nil
        end
    end)
end)

--- Track when a bot becomes a Slave so we know who their master was.
--- The Brainwasher addon uses SetNWEntity("binded_slave", master) and TTT2UpdateSubrole.
hook.Add("TTT2UpdateSubrole", "TTTBots_TrackSlaveConversion", function(ply, oldRole, newRole)
    if not IsValid(ply) then return end
    if not ply:IsBot() then return end

    -- Bot just became a slave -- record their master
    if newRole == ROLE_SLAVE then
        local master = ply:GetNWEntity("binded_slave", nil)
        if IsValid(master) then
            ply.tttbots_wasSlaveOf = master
        end
    end

    -- Bot is no longer a slave (but not because master died -- could be round end etc.)
    if oldRole == ROLE_SLAVE and newRole ~= ROLE_SLAVE then
        -- Don't clear tttbots_wasSlaveOf here; the death hook needs it
    end
end)

--- Clean up tracking flags at round start.
hook.Add("TTTBeginRound", "TTTBots_SlaveTrackingClear", function()
    timer.Simple(0.5, function()
        for _, bot in pairs(TTTBots.Bots) do
            if IsValid(bot) and bot ~= NULL then
                bot.tttbots_wasSlaveOf = nil
            end
        end
    end)
end)

return true
