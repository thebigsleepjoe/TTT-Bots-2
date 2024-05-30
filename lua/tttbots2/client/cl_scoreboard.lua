local function CheckCompatibleGamemode() -- ripped from botlib
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

if not CheckCompatibleGamemode() then return end

--- A table of prime numbers, used to "randomize" pings
local primeNumbers = {
    [2] = true,
    [3] = true,
    [5] = true,
    [7] = true,
    [11] = true,
    [13] = true,
    [17] = true,
    [19] = true,
    [23] = true,
    [29] = true,
    [31] = true,
    [37] = true,
    [41] = true,
    [43] = true,
    [47] = true,
    [53] = true,
    [59] = true,
    [61] = true,
    [67] = true,
    [71] = true,
    [73] = true,
    [79] = true,
    [83] = true,
    [89] = true,
    [97] = true,
    [101] = true,
    [103] = true,
    [107] = true,
    [109] = true,
    [113] = true,
    [127] = true
}


local function getChildByName(panel, name)
    for i, v in pairs(panel:GetChildren()) do
        if v:GetName() == name then
            return v
        end
    end
end

local function GetAvgHumanPing(min)
    local total = 0
    local count = 0

    for _, ply in pairs(player.GetAll()) do
        if ply:IsBot() then continue end

        total = total + ply:Ping()
        count = count + 1
    end
    if count == 0 then return 0 end

    local amt = math.Round(total / count)
    if min then
        return math.max(min, amt)
    end

    return amt
end

local playerPings = {
    -- [nick] = { ping = 0, lastUpdate = 0 } (update very 2 - 3 seconds)
}

local function GetPingForPlayer(nick, botnumber)
    local shouldEmulatePing = GetConVar("ttt_bot_emulate_ping"):GetBool()
    if not shouldEmulatePing then
        return "BOT"
    end


    local isPrime = primeNumbers[botnumber] or false
    local baseline = GetAvgHumanPing(50) * (isPrime and 1.5 or 1)
    local ping = playerPings[nick]
    if not ping then
        ping = { ping = baseline, lastUpdate = CurTime() }
        playerPings[nick] = ping
    end

    if CurTime() - ping.lastUpdate > 2 + (math.random(1, 10) / 10) then
        local fakeSpike = math.random(0, 100) < 20
        local randomness = math.random(-17, 17) * (fakeSpike and 2 or 1)
        if fakeSpike then randomness = math.abs(randomness) end

        ping.ping = math.max(5, baseline + randomness)
        ping.lastUpdate = CurTime()
    end

    return ping.ping
end

local function UpdatePings()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not IsValid(pnl) then return end
    local botnumber = 0

    for _, group in pairs(pnl.ply_groups) do
        if IsValid(group) then
            for _, row in pairs(group.rows) do
                local pingLabel = row.cols[1]
                local player = row.Player
                if not pingLabel or not player or not IsValid(player) then continue end
                if not player:IsBot() then continue end
                botnumber = botnumber + 1

                if not pingLabel.overrideTTTBots then
                    pingLabel.overrideTTTBots = true
                    local st = pingLabel.SetText
                    pingLabel.SetText = function(self, str, override)
                        if override then
                            st(self, str)
                        end
                    end
                end

                local ping = GetPingForPlayer(player:Nick(), botnumber)

                pingLabel:SetText(ping, true)
                -- pingLabel:SetText("TEST", true)
                row:LayoutColumns()
            end
        end
    end
end

local function TTTBots_sbfunc()
    local pnl = GAMEMODE:GetScoreboardPanel()

    if not IsValid(pnl) then return end
    pnl:UpdateScoreboard()

    UpdatePings()
end

local function HijackScoreboard(tries)
    tries = tries or 0
    if not GAMEMODE or (not GAMEMODE:GetScoreboardPanel() and tries < 30) then
        timer.Simple(0.1, function()
            HijackScoreboard((tries or 0) + 1)
        end)
        return
    end

    print("Hijacking scoreboard...")

    if not timer.Exists("TTTScoreboardUpdater") then
        return
    end

    timer.Adjust("TTTScoreboardUpdater", 0.3, 0, function()
        TTTBots_sbfunc()
    end)
end

--HijackScoreboard()
-- Put the above function into GM:PostGamemodeLoaded()
hook.Add("PostGamemodeLoaded", "TTTBots.Client.HijackScoreboard", HijackScoreboard)
hook.Add("TTTScoreboardColumns", "TTTBots.Client.ScoreboardOpened", UpdatePings)

-- we hijack the scoreboard AND do this manually because it likes to update
-- the ping of the bots to 0 when it is closed
timer.Create("TTTBots.Client.FakePing2", 0.2, 0, function()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not (IsValid(pnl) and pnl:IsVisible()) then return end
    UpdatePings()
end)

local avatarCache = {} -- A cache of avatars <string nick, number avatarNumber>


---Find the proper picture path for the given avatar number, depending on the current game settings.
---@param number integer
---@return string path
local function resolveAvatarPath(number)
    local pfps_humanlike = GetConVar("ttt_bot_pfps_humanlike"):GetBool()
    local path = string.format("materials/avatars/%d.png", number)
    if pfps_humanlike then
        path = string.format("materials/avatars/humanlike/%d.jpg", number)
    end
    return path
end

--- Iterates through our avatar cache to update the scoreboard pfps
local function updateScoreboardPfps()
    local pnl = GAMEMODE:GetScoreboardPanel()
    local pfps_humanlike = GetConVar("ttt_bot_pfps_humanlike"):GetBool()
    if not IsValid(pnl) then return end

    for _, group in pairs(pnl.ply_groups) do
        if IsValid(group) then
            for _, row in pairs(group.rows) do
                local player = row.Player
                if not player or not IsValid(player) then continue end
                if not player:IsBot() then continue end

                --local avatar = getChildByName(row, "Avatar")
                local avatar = row.avatar
                if not avatar then continue end
                local avatarNumber = avatarCache[player:Nick()]
                if not avatarNumber then continue end
                if avatar.IsFakeAvatar or row.hasFakeAvatar then continue end
                -- print("Created avatar for bot " .. player:Nick() .. " (" .. avatarNumber .. ")")

                avatar = vgui.Create("DImage", row)
                avatar:SetSize(24, 24)
                avatar:SetMouseInputEnabled(false)

                avatar.SetPlayer = function() return end -- dumb empty function to prevent TTT errors
                avatar.IsFakeAvatar = true
                row.hasFakeAvatar = true

                local path = resolveAvatarPath(avatarNumber)
                avatar:SetImage(path)
                --avatar:SetAvatar("BotAvatar (" .. avatarNumber .. ").jpg")
            end
        end
    end
end

local function sendSyncRequest()
    net.Start("TTTBots_SyncAvatarNumbers")
    net.SendToServer()
end

--- Iterates through the bot-player list and sends the sync message to the server if we are missing anyone.
local function auditAvatarCache()
    local bots = player.GetBots()

    for i, bot in pairs(bots) do
        if not IsValid(bot) then continue end
        local nick = bot:Nick()
        if not avatarCache[nick] then
            -- print("[TTT Bots 2] Missing avatar for bot " .. nick .. ", requesting...")
            sendSyncRequest()
            return
        end
    end
end

net.Receive("TTTBots_SyncAvatarNumbers", function(len, ply)
    avatarCache = net.ReadTable()
    updateScoreboardPfps()
end)

timer.Create("TTTBots.Client.UpdateScoreboard", 0.25, 0, updateScoreboardPfps)
timer.Create("TTTBots.Client.AuditAvatarCache", 3, 0, auditAvatarCache)

if not TTT2 then return end -- Prevent any hypothetical errors created from the below code.

-- Fetching bot avatars

hook.Add("TTT2FetchAvatar", "TTTBots.Client.FetchAvatar", function(id64, size)
    local bot = nil
    for i,v in pairs(player.GetBots()) do
        if v:SteamID64() == id64 then
            bot = v
            break
        end
    end

    if not bot then return end -- Couldn't find the player, so skip.

    local number = avatarCache[bot:Nick()]

    if not number then
        timer.Simple(5, function()
            if not (bot and bot:IsValid()) then return end -- This bot was probably removed...
            draw.DropCacheAvatar(id64, size)
        end)
        return nil
    end

    print("[TTT Bots 2] Fetching avatar for bot " .. bot:Nick() .. " (" .. number .. ")")
    return file.Read(resolveAvatarPath(number), "GAME")
end)


--- This is different to avatarCache, as it is purely for TTT2's avatar cache.
local cachedAvatarData = {} ---@type table<Bot?, boolean>

--- Iterates over every bot unfetched by this script and forcefully refreshes their avatar data.
local function refreshAvatarData()
    for i, bot in pairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if cachedAvatarData[bot] then continue end

        local id64 = bot:SteamID64()
        local sizes = {"small", "medium", "large"}
        -- local dropFn = draw.DropCacheAvatar -- Forcefully drops the cache of this player's avatars.
        local cacheFn = draw.CacheAvatar -- This implicitly calls TTTBots.Client.FetchAvatar (and every other related hook)

        for _, size in pairs(sizes) do
            -- dropFn(id64, size)
            cacheFn(id64, size)
        end
    end
end

--- Release nil or invalid bots from the cache to prevent memory leaks.
local function invalidateAvatarCache()
    for bot, _ in pairs(cachedAvatarData) do
        if not (bot and IsValid(bot)) then
            cachedAvatarData[bot] = nil
        end
    end
end

timer.Create("TTTBots.Client.FetchAvatars", 5, 0, refreshAvatarData)
timer.Create("TTTBots.Client.InvalidateAvatars", 60, 0, invalidateAvatarCache)