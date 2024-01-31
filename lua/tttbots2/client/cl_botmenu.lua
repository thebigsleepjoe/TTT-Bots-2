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

local function InitDashboard(dashP)
    local cat = "TTT Bots 2"
    local properties = vgui.Create("DProperties", dashP)
    properties:Dock(FILL)

    local lang = properties:CreateRow(cat, tr("mod.language"))
    lang:Setup("Generic")
    lang:SetValue(GetConVar("ttt_bot_language"):GetString())
    onDataChangedSetCvar(lang, "ttt_bot_language")

    local quotaN = properties:CreateRow(cat, tr("quota.num"))
    quotaN:Setup("Int", { min = 0, max = game.MaxPlayers() or 0 })
    quotaN:SetValue(GetConVar("ttt_bot_quota"):GetInt())
    onDataChangedSetCvar(quotaN, "ttt_bot_quota")
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

    local dashP = vgui.Create("DPanel", sheet)
    dashP:Dock(FILL)
    -- dashP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("dashboard"), dashP, "icon16/application.png")
    InitDashboard(dashP)

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
