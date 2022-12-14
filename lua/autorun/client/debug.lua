
local drawdata = {}
--[[
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

net.Receive("TTTBots_DrawData", function()
    drawdata = net.ReadTable()

    for identifier, data in pairs(drawdata) do
        if data.type == "line" then
            debugoverlay.Line(data.start, data.ending, 0.1, data.color, true)
        elseif data.type == "box" then
            debugoverlay.Box(data.start, data.ending, 0.1, data.color, true)
        elseif data.type == "text" then
            debugoverlay.Text(data.pos, data.text, 0.1, true)
        end
        
    end
end)

-- hook.Add("PostDrawOpaqueRenderables", "TTTBotsDrawData", function()
--     for _, data in pairs(drawdata) do
--         if data.type == "line" then
--             debugoverlay.Line(data.start, data.)
--         end
--         -- todo: add more types (what else do we need?)
--     end
-- end)