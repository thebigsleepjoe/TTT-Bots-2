-- Initialize variables for storing client data, request status, and UI components
local clientData = {}
local requestData = false
local debugWindow = nil
local debugSheet = nil

-- Network event listener for "TTTBots_ClientData"
-- It receives data from the server, decompresses it and converts it to a table
net.Receive("TTTBots_ClientData", function()
    local bytes_amt = net.ReadUInt(32)
    local compressed_data = net.ReadData(bytes_amt)
    local uncompressed_data = util.Decompress(compressed_data)
    clientData = util.JSONToTable(uncompressed_data)
end)

-- Periodically request data from the server if requestData is true
timer.Create("TTTBots.Client.RequestData", 0.34, 0, function()
    if not requestData then return end
    net.Start("TTTBots_RequestData")
    net.SendToServer()
end)

-- Function to create the debug UI for superadmin players
local function CreateDebugUI(ply, cmd, args, argStr)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    requestData = true

    -- UI setup code
    debugWindow = vgui.Create("DFrame")
    debugWindow:SetSize(ScrW() * 0.4, ScrH() * 0.4)
    debugWindow:Center()
    debugWindow:SetTitle("TTT Bots Debug UI")
    debugWindow:SetDraggable(true)
    debugWindow:ShowCloseButton(true)
    debugWindow:SetVisible(true)
    debugWindow:MakePopup()

    -- On window close, stop data request and cleanup
    function debugWindow:OnClose()
        requestData = false
        debugWindow = nil
        debugSheet = nil
        self:Remove()
    end

    -- Create debugSheet UI component inside the debugWindow
    debugSheet = vgui.Create("DPropertySheet", debugWindow)
    debugSheet:Dock(FILL)
end

-- Function to get the names of all tabs in the debug sheet
local function GetTabNames()
    local names = {}
    for i, v in pairs(debugSheet:GetItems()) do
        names[v.Tab:GetText()] = true
    end
    return names
end

-- Function to populate the debug sheet with data from the clientData table
local function PopulateDebugSheet()
    if not clientData or not debugSheet or not debugWindow then return end
    if (table.Count(clientData) == 0 and requestData) then
        print "No bots found, or waiting for data"
        return
    end

    local tabNames = GetTabNames()
    local activeTab = debugSheet:GetActiveTab() and debugSheet:GetActiveTab():GetText()

    -- Optimization: iterate over smaller collection, assuming clientData is generally smaller
    for tabName, _ in pairs(tabNames) do
        if not clientData[tabName] then
            local tab = debugSheet:Find(tabName) -- Assume there's a Find method or similar
            if tab then debugSheet:CloseTab(tab, true) end
        end
    end


    -- Iterate over bot data, updating existing tabs and creating new ones as necessary
    for botname, bot in pairs(clientData) do
        if not tabNames[botname] then
            local sheet = vgui.Create("DPanel", debugSheet)
            sheet:SetText(botname)
            sheet.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 255))
            end

            local listView = vgui.Create("DListView", sheet)
            listView:Dock(FILL)
            listView:SetMultiSelect(false)
            listView:AddColumn("Name")
            listView:AddColumn("Value")

            -- Alphabetically sort bot (table)
            local sorted = {}
            for k, v in pairs(bot) do table.insert(sorted, k) end
            table.sort(sorted)


            for n, key in pairs(sorted) do
                local value = bot[key]
                local line = listView:AddLine(key, value)
                --- Hijack the paint function to update the value column dynamically.
                --- This is hacky AF but it works. It's a debug menu so I don't care. ;)
                local lp = line.Paint
                function line.Paint(self, w, h)
                    local data = clientData and clientData[botname] and clientData[botname][key]
                    if not data then return lp(self, w, h) end

                    line:SetColumnText(2, data)
                    return lp(self, w, h)
                end
            end

            debugSheet:AddSheet(botname, sheet, "icon16/gun.png")
        end
    end

    if not activeTab then return end
    debugSheet:SwitchToName(activeTab)
end


-- Periodically populate the debug sheet with the client data
timer.Create("TTTBots.Client.PopulateDebugSheet", 0.34, 0, PopulateDebugSheet)

concommand.Add("ttt_bot_debug_showui", CreateDebugUI, nil, "Creates a debug UI for superadmins to see bot activity",
    FCVAR_LUA_CLIENT)
