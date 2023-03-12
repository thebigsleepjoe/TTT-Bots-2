--- TTT2 Implementation of the FakePing module
local scoreboard = TTTScoreboard

local function getChildByName(panel, name)
    for i, v in pairs(panel:GetChildren()) do
        if v:GetName() == name then
            return v
        end
    end
end

local function printChildrenNames(panel)
    for i, v in pairs(panel:GetChildren()) do
        print(v:GetName())
    end
end


local function _sbfunc()
    local pnl = GAMEMODE:GetScoreboardPanel()

    if not IsValid(pnl) then return end
    pnl:UpdateScoreboard()

    for _, group in pairs(pnl.ply_groups) do
        if IsValid(group) then
            for _, row in pairs(group.rows) do
                local pingLabel = row.cols[1]
                local player = row.Player
                if not pingLabel or not player or not IsValid(player) then continue end
                if not player:IsBot() then continue end

                pingLabel:SetText(39)
                row:LayoutColumns()
            end
        end
    end

    -- Fake pings --
    -- local TTTPlayerFrame = getChildByName(pnl, "TTTPlayerFrame")
    -- local Panel = getChildByName(TTTPlayerFrame, "Panel")
    -- -- printChildrenNames(TTTPlayerFrame)
    -- printChildrenNames(Panel)
end

local function GetAvgHumanPing()
    local total = 0
    local count = 0

    for _, ply in pairs(player.GetAll()) do
        if ply:IsBot() then continue end

        total = total + ply:Ping()
        count = count + 1
    end
    if count == 0 then return 0 end

    return total / count
end

local function HijackScoreboard(tries)
    print("Attempting scoreboard hijack")
    if not scoreboard and tries < 30 then
        timer.Simple(0.1, function()
            HijackScoreboard((tries or 0) + 1)
        end)
        return
    end

    if not timer.Exists("TTTScoreboardUpdater") then
        print "no timer"
        return
    end

    local success = timer.Adjust("TTTScoreboardUpdater", 0.3, 0, function()
        _sbfunc()
    end)
end

HijackScoreboard()
