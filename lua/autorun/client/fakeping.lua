-- --- TTT2 Implementation of the FakePing module
-- local scoreboard = TTTScoreboard

-- local function _sbfunc()
--     local pnl = GAMEMODE:GetScoreboardPanel()

--     if IsValid(pnl) then
--         pnl:UpdateScoreboard()
--     end
-- end

-- local function GetAvgHumanPing()
--     local total = 0
--     local count = 0

--     for _, ply in pairs(player.GetAll()) do
--         if ply:IsBot() then continue end

--         total = total + ply:Ping()
--         count = count + 1
--     end
--     if count == 0 then return 0 end

--     return total / count
-- end

-- local function HijackScoreboard()
--     print("Attempting scoreboard hijack")
--     if not scoreboard then
--         timer.Simple(0.1, HijackScoreboard)
--         return
--     end

--     timer.Adjust("TTTScoreboardUpdateTimer", 0.3, 0, function()
--         _sbfunc()
--     end)

--     print("Succeeded in scoreboard hijack")
-- end

-- HijackScoreboard()
