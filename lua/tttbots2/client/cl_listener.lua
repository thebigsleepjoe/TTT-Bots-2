local function sendSpectateMode(spectateMode)
    net.Start("TTTBots_SpectateModeChanged")
    net.WriteBool(spectateMode == "1" or spectateMode == true)
    net.SendToServer()
end

cvars.AddChangeCallback("ttt_spectator_mode", function(name, oldValue, newValue)
    sendSpectateMode(newValue) 
end)

net.Receive("TTTBots_QuerySpectateMode", function(len, ply)
    sendSpectateMode(GetConVar("ttt_spectator_mode"):GetBool())
end)
