local DATA = {}

local tr = TTTBots.Locale.GetLocalizedString

local function requestServerUpdateCvar(cvar, value)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local msgName = "TTTBots_RequestCvarUpdate"

    net.Start(msgName)
    net.WriteString(cvar)
    net.WriteString(value)
    net.SendToServer()
end

local function onDataChangedSetCvar(row, cvar)
    row.DataChanged = function(_, value)
        -- Create a timer
        timer.Create("TTTBots.Client.CvarTimer." .. cvar, 0.5, 1, function()
            requestServerUpdateCvar(cvar, value)
        end)
    end
end

local function getParsedNames()
    local str = GetConVar("ttt_bot_names_custom"):GetString()

    -- This is basically a csv
    local names = string.Split(str, ",")
    return names
end

local function addNameToNames(str)
    local content = GetConVar("ttt_bot_names_custom"):GetString()

    local parsed = getParsedNames()
    table.insert(parsed, str)

    local filtered = {}
    for i, v in pairs(parsed) do
        parsed[i] = string.Trim(v)
        if parsed[i] == "" then continue end
        table.insert(filtered, parsed[i])
    end

    local content = table.concat(filtered, ",")

    requestServerUpdateCvar("ttt_bot_names_custom", content)
end

local function InitNamesPanel(namesP)
    local halfWide = 500 - 8

    local rightPanel = vgui.Create("DPanel", namesP)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(halfWide)

    local rightNameList = vgui.Create("DListView", rightPanel)
    rightNameList:Dock(FILL)
    rightNameList:AddColumn(tr("name"))
    rightNameList:SetMultiSelect(false)
    rightNameList.ResetContent = function()
        local lines = rightNameList:GetLines()
        for i, line in ipairs(lines) do
            rightNameList:RemoveLine(i)
        end

        local names = getParsedNames()
        for i, str in pairs(names) do
            rightNameList:AddLine(str)
        end
    end
    rightNameList:ResetContent()

    local leftPanel = vgui.Create("DPanel", namesP)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(halfWide)

    local leftAddInput = vgui.Create("DTextEntry", leftPanel)
    leftAddInput:Dock(TOP)
    leftAddInput:DockMargin(0, 0, 0, 5)
    leftAddInput:SetPlaceholderText(tr("add.name"))

    local leftAddBtn = vgui.Create("DButton", leftPanel)
    leftAddBtn:SetText(tr("add"))
    leftAddBtn:Dock(TOP)
    leftAddBtn:DockMargin(0, 0, 0, 5)
    leftAddBtn.DoClick = function()
        local str = leftAddInput:GetValue()
        if str == "" then return end

        addNameToNames(str)
        leftAddInput:SetText("")

        timer.Simple(0.5, rightNameList.ResetContent)
    end

    local leftRemoveBtn = vgui.Create("DButton", leftPanel)
    leftRemoveBtn:SetText(tr("remove.selected"))
    leftRemoveBtn:Dock(TOP)
    leftRemoveBtn:DockMargin(0, 0, 0, 5)
    leftRemoveBtn.DoClick = function()
        local selected = rightNameList:GetSelectedLine()
        if not selected then return end

        local line = rightNameList:GetLine(selected)
        local str = line:GetValue(1)

        local names = getParsedNames()
        local newNames = {}

        for i, v in pairs(names) do
            if v == str then continue end
            table.insert(newNames, v)
        end

        local content = table.concat(newNames, ",")
        requestServerUpdateCvar("ttt_bot_names_custom", content)

        timer.Simple(0.5, rightNameList.ResetContent)
    end
end

local function CreateBotMenu(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local wid, hei = 1000, 700
    local sW, sH = ScrW(), ScrH()
    local half_sW, half_sH = sW / 2, sH / 2
    local padding = 15

    local window = vgui.Create("DFrame")
    window:SetPos(half_sW - wid / 2, half_sH - hei / 2)
    window:SetSize(wid, hei)
    window:SetTitle("TTT Bots 2 - Bot Menu")
    window:SetDraggable(true)
    window:ShowCloseButton(true)
    window:SetVisible(true)
    window:MakePopup()

    local sheet = vgui.Create("DPropertySheet", window)
    sheet:Dock(FILL)

    local botsP = vgui.Create("DPanel", sheet)
    botsP:Dock(FILL)
    -- botsP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("current.bots"), botsP, "icon16/user.png")

    local botsAddP = vgui.Create("DPanel", sheet)
    botsAddP:Dock(FILL)
    -- botsAddP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("build.a.bot"), botsAddP, "icon16/user_add.png")

    local namesP = vgui.Create("DPanel", sheet)
    namesP:Dock(FILL)
    -- namesP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("bot.names"), namesP, "icon16/text_underline.png")
    InitNamesPanel(namesP)

    local traitsP = vgui.Create("DPanel", sheet)
    traitsP:Dock(FILL)
    -- traitsP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("traits"), traitsP, "icon16/tag_red.png")

    local buyablesP = vgui.Create("DPanel", sheet)
    buyablesP:Dock(FILL)
    -- buyablesP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("buyables"), buyablesP, "icon16/gun.png")
end

-- timer.Create("TTTBots.Client.PopulateDebugSheet", 0.34, 0, PopulateDebugSheet)

concommand.Add("ttt_bot_menu", CreateBotMenu, nil, "Open a menu panel to manage bots", FCVAR_LUA_CLIENT)
