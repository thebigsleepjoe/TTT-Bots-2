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
        }
    }
]]
net.Receive("TTTBots_DrawData", function()
    local bytes_amt = net.ReadUInt(32)
    local compressed_data = net.ReadData(bytes_amt)
    local uncompressed_data = util.Decompress(compressed_data)
    drawdata = util.JSONToTable(uncompressed_data)

    for identifier, data in pairs(drawdata) do
        if data.type == "line" then
            debugoverlay.Line(data.start, data.ending, data.lifetime or 0.15, data.color, true)
        elseif data.type == "box" then
            debugoverlay.Box(data.origin, data.mins, data.maxs, data.lifetime or 0.15, data.color, true)
        elseif data.type == "text" then
            debugoverlay.Text(data.pos, data.text, data.lifetime or 0.15, true)
        elseif data.type == "sphere" then
            debugoverlay.Sphere(data.pos, data.radius, data.lifetime or 0.15, data.color, true)
        elseif data.type == "cross" then
            debugoverlay.Cross(data.pos, data.size, data.lifetime or 0.15, data.color, true)
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
