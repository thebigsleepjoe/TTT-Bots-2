local clientData = {}
local requestData = false --- Are we requesting data from the server?
local debugWindow = nil
local debugSheet = nil

net.Receive("TTTBots_ClientData", function()
    local bytes_amt = net.ReadUInt(32)
    local compressed_data = net.ReadData(bytes_amt)
    local uncompressed_data = util.Decompress(compressed_data)
    clientData = util.JSONToTable(uncompressed_data)
end)

timer.Create("TTTBots.Client.RequestData", 0.34, 0, function()
    if not requestData then return end
    net.Start("TTTBots_RequestData")
    net.SendToServer()
end)

local function CreateDebugUI(ply, cmd, args, argStr)
    -- we can ignore the args
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    requestData = true

    debugWindow = vgui.Create("DFrame")
    debugWindow:SetSize(ScrW() * 0.4, ScrH() * 0.4)
    debugWindow:Center()
    debugWindow:SetTitle("TTT Bots Debug UI")
    debugWindow:SetDraggable(true)
    debugWindow:ShowCloseButton(true)
    debugWindow:SetVisible(true)
    debugWindow:MakePopup()
    function debugWindow:OnClose()
        requestData = false
        debugWindow = nil
        debugSheet = nil
        self:Remove()
    end

    debugSheet = vgui.Create("DPropertySheet", debugWindow)
    debugSheet:Dock(FILL)
    debugSheet:SetFadeTime(0.0)
    -- function debugSheet:Paint(w, h)
    --     draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 255))
    -- end
end

local function GetTabNames()
    local names = {}
    for i, v in pairs(debugSheet:GetItems()) do
        names[v.Tab:GetText()] = true
    end
    return names
end

local function PopulateDebugSheet()
    if not (clientData) then return end
    if (table.Count(clientData) == 0 and requestData) then
        print "No bots found, or waiting for data"
        return
    end
    if not debugSheet or not debugWindow then return end

    local tabNames = GetTabNames()
    local activeTab = debugSheet:GetActiveTab() and debugSheet:GetActiveTab():GetText()

    -- Cull any tabs that are no longer needed; clientData is the source of truth
    for i, v in pairs(debugSheet:GetItems()) do
        local tabName = v.Tab:GetText()
        if not clientData[tabName] then
            debugSheet:CloseTab(v.Tab, true)
        end
    end

    -- Add any new tabs
    for botname, bot in pairs(clientData) do
        if not tabNames[botname] then
            local sheet = vgui.Create("DPanel", debugSheet)
            sheet:SetText(botname)
            debugSheet:AddSheet(botname, sheet, "icon16/gun.png")
        end
    end

    -- local item = 0
    -- for botname, bot in pairs(clientData) do
    --     item = item + 1
    --     local sheet = vgui.Create("DPanel", debugSheet)
    --     sheet:SetText(botname)
    --     debugSheet:AddSheet(botname, sheet, "icon16/gun.png")

    --     --Todo: populate the sheet with bot data
    -- end

    if activeTab then
        debugSheet:SwitchToName(activeBot)
    end
end

timer.Create("TTTBots.Client.PopulateDebugSheet", 0.34, 0, PopulateDebugSheet)

concommand.Add("ttt_bot_debug_showui", CreateDebugUI, nil, "Creates a debug UI for superadmins to see bot activity",
    FCVAR_LUA_CLIENT)
