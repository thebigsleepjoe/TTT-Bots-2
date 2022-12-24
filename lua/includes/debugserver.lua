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
    print("New draw data: " .. identifier)
    DebugServer.data[identifier] = newdata
end

function DebugServer.SendDrawData()
    net.Start("TTTBots_DrawData")
    net.WriteTable(DebugServer.data)
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
    if all or has(settings, "path") then
        local paths = TTTBots.PathManager.GetBotPaths(bot)
        for i, path in pairs(paths) do
            TTTBots.DebugServer.DrawPath(path)
        end
    end
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

-- TODO: Rewrite this function to use the new pathmanager
function TTTBots.DebugServer.DrawPath(pathparent)
    if not GetConVar("ttt_bot_debug_pathfinding"):GetBool() then return end
    if type(pathparent.path) ~= "table" and not pathparent.path then return end
    
    -- pathparent.path is a table of CNavAreas, so just draw lines between each center
    for i=1,table.Count(pathparent.path)-1 do
        local start = pathparent.path[i]:GetCenter()
        local ending = pathparent.path[i + 1]:GetCenter()

        local ageSecs = CurTime() - pathparent.generated_time
        
        DebugServer.ChangeDrawData("path_" .. pathparent.bot:Nick() .. i,
        {
            type = "line",
            start = start,
            ending = ending,
            color = Color(255, 0, ageSecs * 255, 255),
            width = 15
            })
    end
end

-- Send latest draw data to clients every 0.1 seconds
timer.Create("TTTBots_SendDrawData", 0.1, 0, function()
    DebugServer.SendDrawData()
end)