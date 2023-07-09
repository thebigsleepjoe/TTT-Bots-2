local function CheckCompatibleGamemode() -- ripped from CommonLib
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

if not CheckCompatibleGamemode() then return end

local primeNumbers = {
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109,
    113, 127
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
    local isPrime = table.HasValue(primeNumbers, botnumber)
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

                local ping = GetPingForPlayer(player:Nick(), botnumber)

                pingLabel:SetText(ping)
                row:LayoutColumns()
            end
        end
    end
end

local function _sbfunc()
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

    local success = timer.Adjust("TTTScoreboardUpdater", 0.3, 0, function()
        _sbfunc()
    end)
end

--HijackScoreboard()
-- Put the above function into GM:PostGamemodeLoaded()
hook.Add("PostGamemodeLoaded", "TTTBots.Client.HijackScoreboard", HijackScoreboard)

-- we hijack the scoreboard AND do this manually because it likes to update
-- the ping of the bots to 0 when it is closed
timer.Create("TTTBots.Client.FakePing2", 0.01, 0, function()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not (IsValid(pnl) and pnl:IsVisible()) then return end
    UpdatePings()
end)

local function syncBotAvatars()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not IsValid(pnl) then return end

    net.Start("TTTBots_SyncAvatarNumbers")
    net.SendToServer()
end

net.Receive("TTTBots_SyncAvatarNumbers", function(len, ply)
    local avatars_nicks = net.ReadTable()
    local pnl = GAMEMODE:GetScoreboardPanel()
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
                local avatarNumber = avatars_nicks[player:Nick()]
                if not avatarNumber then continue end
                if avatar.IsFakeAvatar or row.hasFakeAvatar then continue end
                print("Created avatar for bot " .. player:Nick() .. " (" .. avatarNumber .. ")")

                avatar = vgui.Create("DImage", row)
                avatar:SetSize(24, 24)
                avatar:SetMouseInputEnabled(false)

                avatar.SetPlayer = function() return end -- dumb empty function to prevent TTT errors
                avatar.IsFakeAvatar = true
                row.hasFakeAvatar = true


                avatar:SetImage(string.format("materials/avatars/BotAvatar (%d).jpg", avatarNumber))
                --avatar:SetAvatar("BotAvatar (" .. avatarNumber .. ").jpg")
            end
        end
    end
end)

timer.Create("TTTBots.Client.SyncBotAvatars", 5, 0, syncBotAvatars)
