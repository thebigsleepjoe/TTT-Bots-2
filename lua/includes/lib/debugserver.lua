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
    -- net.WriteTable()
    local uncompressed_data = util.TableToJSON(DebugServer.data)
    local compressed_data = util.Compress(uncompressed_data)
    local bytes_amt = string.len(compressed_data)

    
    net.Start("TTTBots_DrawData")
        net.WriteUInt(bytes_amt, 32)
        net.WriteData(compressed_data, bytes_amt)
    net.Broadcast()

    DebugServer.data = {}
end

-- Settings:
-- {"look", "target", "path", "all"}
function TTTBots.DebugServer.RenderDebugFor(bot, settings)
    -- Check if "developer" convar is set to 1, spare resources if not
    if not GetConVar("developer"):GetBool() then return end

    local has = table.HasValue
    local all = has(settings, "all")

    if all or has(settings, "look") then TTTBots.DebugServer.DrawBotLook(bot) end
    if all or has(settings, "path") then TTTBots.DebugServer.DrawCurrentPathFor(bot) end
end

function TTTBots.DebugServer.DrawBotLook(bot)
    if not GetConVar("ttt_bot_debug_look"):GetBool() then return end

    local start = bot:GetShootPos()
    local endpos = bot:GetShootPos() + bot:GetAimVector() * 150

    local tr = util.TraceLine({
        start = start,
        endpos = endpos,
        filter = bot
    })

    if tr.Hit then
        endpos = tr.HitPos
    else
        endpos = endpos
    end

    DebugServer.ChangeDrawData("botlook_" .. bot:Nick(),
    {
        type = "line",
        start = start,
        ending = endpos,
        color = Color(0, 255, 0, 255),
        width = 5
        })
end

function TTTBots.DebugServer.DrawCurrentPathFor(bot)
    local pathinfo = bot.components.locomotor.pathinfo
    if not pathinfo or not pathinfo.path then return end

    local path = pathinfo.path
    local age = pathinfo:TimeSince()

    if type(path) ~= "table" then return end

    for i=1,table.Count(path)-1 do
        local start = path[i]:GetCenter()
        local ending = path[i + 1]:GetCenter()

        local colorOffset = (age / TTTBots.PathManager.cullSeconds) * 255

        DebugServer.ChangeDrawData("path_" .. bot:Nick() .. i,
        {
            type = "line",
            start = start,
            ending = ending,
            color = Color(255 - colorOffset, 0, colorOffset, 255),
            width = 15
            })
    end

end

function TTTBots.DebugServer.DrawLineBetween(start, finish, color)
    if not (start and finish and color) then return end

    DebugServer.ChangeDrawData("line_" .. tostring(start) .. tostring(finish),
    {
        type = "line",
        start = start,
        ending = finish,
        color = color,
        width = 5
        })
end

-- Send latest draw data to clients every 0.1 seconds
timer.Create("TTTBots_SendDrawData", 0.1, 0, function()
    DebugServer.SendDrawData()
end)