util.AddNetworkString("TTTBots_DrawData")

TTTBots.DebugServer = {
    data = {}
}
--[[
    Data table example:
    {
        identifier_line = {
            type = "line",
            start = Vector(0, 0, 0),
            ending = Vector(0, 0, 0),
            color = Color(255, 255, 255, 255),
            width = 1
        },
        identifier_box = {
            type = "box",
            start = Vector(0, 0, 0),
            ending = Vector(0, 0, 0),
            color = Color(255, 255, 255, 255),
            width = 1
        },
        identifier_text = {
            type = "text",
            pos = Vector(0, 0, 0),
            text = "Hello world!",
            color = Color(255, 255, 255, 255),
            font = "Default",
            xalign = TEXT_ALIGN_CENTER,
            yalign = TEXT_ALIGN_CENTER
        }
    }
]]


local DebugServer = TTTBots.DebugServer

function DebugServer.ChangeDrawData(identifier, newdata)
    DebugServer.data[identifier] = newdata
end

function DebugServer.SendDrawData()
    net.Start("TTTBots_DrawData")
    net.WriteTable(DebugServer.data)
    net.Broadcast()

    DebugServer.data = {}
end

function TTTBots.DebugServer.DrawBotLook(bot)
    if bot:Health() <= 0 then return end
    if bot:IsSpec() then return end

    local start = bot:GetShootPos()
    local endpos = bot:GetShootPos() + bot:GetAimVector() * 150

    DebugServer.ChangeDrawData("botlook_" .. bot:Nick(),
    {
        type = "line",
        start = start,
        ending = endpos,
        color = Color(0, 255, 0, 255),
        width = 5
        })
end

-- Send latest draw data to clients every 0.1 seconds
timer.Create("TTTBots_SendDrawData", 0.1, 0, function()
    DebugServer.SendDrawData()
end)