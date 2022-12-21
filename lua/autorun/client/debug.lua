
local drawdata = {}
--[[
    {
        {
            type = "line",
            start = Vector(0, 0, 0),
            end = Vector(0, 0, 0),
            color = Color(255, 255, 255, 255),
            width = 1
        }
    }
]]

net.Receive("TTTBots_DrawData", function()
    drawdata = net.ReadTable()
end)

hook.Add("PostDrawOpaqueRenderables", "TTTBotsDrawData", function()
    for _, data in pairs(drawdata) do
        if data.type == "line" then
            render.DrawLine(data.start, data["end"], data.color, data.width)
        end
        -- todo: add more types (what else do we need?)
    end
end)