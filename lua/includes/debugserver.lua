TTTBots.DebugServer = {
    data = {}
}

local DebugServer = TTTBots.DebugServer

function DebugServer.SendDrawData(data)
    net.Start("TTTBots_DrawData")
    net.WriteTable(data)
    net.Broadcast()
end