local clientData = {}
local requestData = false --- Are we requesting data from the server?

net.Receive("TTTBots_ClientData", function()
    local bytes_amt = net.ReadUInt(32)
    local compressed_data = net.ReadData(bytes_amt)
    local uncompressed_data = util.Decompress(compressed_data)
    clientData = util.JSONToTable(uncompressed_data)
end)

timer.Create("TTTBots_RequestData", 0.34, 0, function()
    if not requestData then return end
    net.Start("TTTBots_RequestData")
    net.SendToServer()
end)

local function CreateDebugUI(ply, cmd, args, argStr)
    -- we can ignore the args
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    requestData = true

    local window = vgui.Create("DFrame")
    window:SetSize(ScrW() * 0.4, ScrH() * 0.4)
    window:Center()
    window:SetTitle("TTT Bots Debug UI")
    window:SetDraggable(true)
    window:ShowCloseButton(true)
    window:SetVisible(true)
    window:MakePopup()
    function window:OnClose()
        requestData = false
        self:Remove()
    end

    local sheet = vgui.Create("DPropertySheet", window)
    sheet:Dock(FILL)

    local panel1 = vgui.Create("DPanel", sheet)
    panel1.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(0, 128, 255, self:GetAlpha())) end
    sheet:AddSheet("test", panel1, "icon16/cross.png")

    local panel2 = vgui.Create("DPanel", sheet)
    panel2.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(255, 128, 0, self:GetAlpha())) end
    sheet:AddSheet("test 2", panel2, "icon16/tick.png")
end

concommand.Add("ttt_bot_debug_showui", CreateDebugUI, nil, "Creates a debug UI for superadmins to see bot activity",
    FCVAR_LUA_CLIENT)
