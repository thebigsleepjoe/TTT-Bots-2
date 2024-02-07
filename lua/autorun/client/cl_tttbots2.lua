print("Loading TTT Bots 2 client...")
include("tttbots2/sh_tttbots2.lua")


CreateConVar("ttt_bot_debug_hidehud", "0", FCVAR_ARCHIVE, "Hide the TTT2 hud? This is for debug use")

-- Little snippet per @EntranceJew: not quite what he intended, but it's what I'm going with.
hook.Add("HUDShouldDraw", "TTTBotDebugHideHUD", function()
    if not TTT2 then return end
    if GetConVar("ttt_bot_debug_hidehud"):GetBool() then return false end
end)
