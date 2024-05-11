---@class Match
TTTBots.Match = {}
---@type table<Bot>
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
Match.AliveTraitors = {} ---@deprecated
Match.AliveHumanTraitors = {} ---@deprecated
Match.AliveNonEvil = {} ---@deprecated
Match.AlivePolice = {} ---@deprecated
Match.DisguisedPlayers = {}
Match.SecondsPassed = 0 --- Time since match began. This is important for traitor bots.
Match.KOSCounter = {} ---@type table<Player, number>
--- List of active KOS calls. Indexed by person called out, with each value being a table of people who called them out.
Match.KOSList = {} ---@type table<Player, table<Player>>
Match.SpottedC4s = {} ---@type table<Entity, boolean> Armed C4 that has been spotted by the innocent bots at least once. key and value are the same entity
Match.AllArmedC4s = {} ---@type table<Entity, boolean>
Match.Smokes = {}

function Match.Tick()
    if not Match.RoundActive then return end
    Match.CleanupNullCorpses()
    Match.SecondsPassed = (Match.Time()) + (1 / TTTBots.Tickrate)
end

--- Returns true if enough time, as defined by plans_mindelay and _maxdelay, has passed since the round began. Used for automatic plan execution by bots.
---@realm server
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

--- Check if the match should trust this individual's KOS. This is used to limit KOS calls to 1 per user per round;
--- for bots it is used to prevent chat spam.
---@param ply Player
---@param dontIterate nil|boolean (OPTIONAL=false)
---@return boolean is_trustworthy - if we can trust this player's KOS
---@realm server
function Match.KOSIsApproved(ply, dontIterate)
    if not Match.IsRoundActive() then return false end
    local MAX_KOS_PER_PLY = TTTBots.Lib.GetConVarInt("kos_limit")
    local amt = Match.KOSCounter[ply] or 0

    if amt < MAX_KOS_PER_PLY then
        Match.KOSCounter[ply] = amt + (dontIterate and 0 or 1)
        return true
    end

    return false -- do not trust; if bot, then prevent chatting
end

--- Handles the heavy lifting for a KOS call. After verifying the caller hasn't hit the limit, this calls OnKOSCalled across each TTTBot in the match.
---@param caller Player
---@param target Player
---@return boolean success
---@realm server
function Match.CallKOS(caller, target)
    if not Match.IsRoundActive() then return false end
    if TTTBots.Roles.GetRoleFor(target):GetAppearsPolice() then return false end
    local isApproved = Match.KOSIsApproved(caller)
    if not isApproved then return false end

    Match.KOSList[target] = Match.KOSList[target] or {}
    Match.KOSList[target][caller] = caller

    for i, bot in pairs(TTTBots.Bots) do
        local morality = bot:BotMorality()
        if not morality then continue end
        morality:OnKOSCalled(caller, target)
    end

    return true
end

--- Returns the time in seconds since the match began.
---@return number seconds
---@realm shared
function Match.Time()
    return (Match.RoundActive and Match.SecondsPassed) or 0
end

---@realm shared
function Match.IsRoundActive()
    return Match.RoundActive
end

---@realm shared
function Match.CleanupNullCorpses()
    for i, v in pairs(Match.Corpses) do
        if not IsValid(v) or v == NULL then
            table.remove(Match.Corpses, i)
        end
    end
end

---@realm shared
function Match.ResetStats(roundActive)
    Match.RoundActive = roundActive or false
    Match.Corpses = {}
    Match.ConfirmedDead = {}
    Match.PlayersInRound = {}
    Match.DamageLogs = {}
    Match.AlivePlayers = {}
    Match.SecondsPassed = 0
    Match.DisguisedPlayers = {}
    Match.KOSCounter = {}
    Match.KOSList = {}
    Match.SpottedC4s = {}
    Match.AllArmedC4s = {}
    Match.RoundID = TTTBots.Lib.GenerateID()
    Match.Smokes = {}

    if SERVER then
        for i, v in pairs(TTTBots.Bots) do
            v:SetAttackTarget(nil)
        end
    end
end

---Gets the difficulty scoring of the given bot. Returns -1 if the bot is not a TTTBot.
---@param bot Bot
---@return number difficulty
---@realm server
function Match.GetBotDifficulty(bot)
    local personality = bot:BotPersonality()
    if not personality then return -1 end
    local diff = personality:GetDifficulty()
    return diff
end

--- Returns a table of all bots in the game, indexed by bot object, with each key as the estimated difficulty score.
---@return table<Bot, number> botDifficulty
---@realm server
function Match.GetBotsDifficulty()
    local tbl = {}
    for i, bot in pairs(TTTBots.Bots) do
        local diff = Match.GetBotDifficulty(bot)
        tbl[bot] = diff
    end
    return tbl
end

--- Comb thru the damage logs and find the player who shot the other first.
---@realm server
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

---@realm shared
function Match.UpdateAlivePlayers()
    Match.AlivePlayers = {}
    Match.DisguisedPlayers = {}
    for bot, isAlive in pairs(TTTBots.Lib.GetPlayerLifeStates()) do
        if not (bot and isAlive) or bot == NULL or not IsValid(bot) then continue end
        table.insert(Match.AlivePlayers, bot)
        -- Check if player is disguised, and if so, add them to the disguised tbl
        local isDisguised = bot:GetNWBool("disguised", false)
        if isDisguised then
            Match.DisguisedPlayers[bot] = true
        end
    end
end

---@realm shared
function Match.IsPlayerDisguised(ply)
    return Match.DisguisedPlayers[ply] or false
end

---Event called when an innocent bot spots a C4.
---@param bot Bot
---@param c4 Entity
---@realm server
function Match.OnBotSpotC4(bot, c4)
    local chatter = bot:BotChatter()
    local locomotor = bot:BotLocomotor()
    if not chatter then return end
    chatter:On("SpottedC4", {}, false)
    locomotor:LookAt(c4:GetPos())
end

---@realm server
function Match.BotsTrySpotC4()
    for i, bot in pairs(TTTBots.Bots) do
        if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        if not TTTBots.Roles.GetRoleFor(bot):GetDefusesC4() then continue end

        for c4, _ in pairs(Match.AllArmedC4s) do
            if not IsValid(c4) then continue end

            if not Match.SpottedC4s[c4] then
                local canSee = TTTBots.Lib.CanSeeArc(bot, c4:GetPos() + Vector(0, 0, 16), 120)
                if canSee and (bot:GetPos():Distance(c4:GetPos()) < 2000) then
                    Match.SpottedC4s[c4] = true
                    Match.OnBotSpotC4(bot, c4)
                end
            end
        end
    end
end

function Match.IsSmokeDataActive(data)
    local timeNow = CurTime()
    local startTime = data.startTime
    local endTime = data.endTime
    return not (timeNow > endTime or timeNow < startTime)
end

local SMOKE_DIST = 256
function Match.IsPlyNearSmoke(ply)
    local smokes = Match.Smokes
    local plyPos = ply:GetPos()
    for i, data in pairs(smokes) do
        if not Match.IsSmokeDataActive(data) then continue end

        local center = data.center
        local dist = plyPos:Distance(center)
        if dist < SMOKE_DIST then
            return true
        end
    end

    return false
end

timer.Create("TTTBots.Match.UpdateAlivePlayers", 0.34, 0, function()
    Match.UpdateAlivePlayers()
end)

hook.Add("TTTBeginRound", "TTTBots.Match.BeginRound", function()
    Match.ResetStats(true)
    for _, ply in pairs(player.GetAll()) do
        if TTTBots.Lib.IsPlayerAlive(ply) then
            Match.PlayersInRound[ply] = true
        end
    end
    Match.UpdateAlivePlayers()
end)

hook.Add("TTTEndRound", "TTTBots.Match.EndRound", function()
    Match.ResetStats(false)
end)

hook.Add("TTTPrepareRound", "TTTBots.Match.PrepareRound", function()
    Match.ResetStats(false)
end)

if SERVER then
    hook.Add("TTTOnCorpseCreated", "TTTBots.Match.OnCorpseCreated", function(corpse)
        if not Match.RoundActive then return end
        table.insert(Match.Corpses, corpse)
    end)

    hook.Add("TTTBodyFound", "TTTBots.Match.BodyFound", function(discoverer, deceased, ragdoll)
        if not Match.RoundActive then return end
        if not IsValid(deceased) then return end
        if not deceased:IsPlayer() then return end
        if not Match.PlayersInRound[deceased] then return end
        Match.ConfirmedDead[deceased] = true
    end)

    hook.Add("PlayerHurt", "TTTBots.Match.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
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

    hook.Add("TTTPlayerRadioCommand", "TTTBots.Match.TTTRadioMessage", function(ply, msgName, msgTarget)
        if msgName ~= "quick_traitor" then return end
        if not (ply and msgTarget) then return end
        if not (IsValid(ply) and IsValid(msgTarget)) then return end
        local callerAlive = TTTBots.Lib.IsPlayerAlive(ply)
        local targetAlive = TTTBots.Lib.IsPlayerAlive(msgTarget)
        if not (callerAlive and targetAlive) then return end
        Match.CallKOS(ply, msgTarget)
    end)

    timer.Create("TTTBots.Match.UpdateC4List", 1, 0, function()
        if not Match.RoundActive then return end
        local bombs = ents.FindByClass("ttt_c4")

        Match.AllArmedC4s = {}

        for i, c4 in pairs(bombs) do
            if not IsValid(c4) then continue end
            if not c4:GetArmed() then continue end
            Match.AllArmedC4s[c4] = true
        end

        Match.BotsTrySpotC4()
    end)

    hook.Add("EntityRemoved", "TTTBots.Match.UpdateSmokes", function(ent, fullUpdate)
        if not IsValid(ent) then return end
        local class = ent:GetClass()
        if string.find(class, "smoke") and ent.was_thrown and ent.GetDetTime then
            local data = {
                startTime = ent:GetDetTime(),
                endTime = ent:GetDetTime() + 30,
                center = ent:GetPos(),
                ent = ent
            }
            table.insert(Match.Smokes, data)
        end
    end)
end
