local function sendSpectateMode(spectateMode)
    net.Start("TTTBots_SpectateModeChanged")
    print("[TTT Bots 2] Sending spectate mode to server:", spectateMode)
    net.WriteBool(spectateMode == "1" or spectateMode == true)
    net.SendToServer()
end

cvars.AddChangeCallback("ttt_spectator_mode", function(name, oldValue, newValue) -- I didn't look at the TTT2 convars this may need a separate listener for it if the convar is different.
    print("[TTT Bots 2] Spectate mode changed to", newValue)
    print(GetConVar("ttt_spectator_mode"):GetBool())
    sendSpectateMode(newValue) 
end)

net.Receive("TTTBots_QuerySpectateMode", function(len, ply)
    print("[TTT Bots 2] Received TTTBots_QuerySpectateMode net message from")
    print(GetConVar("ttt_spectator_mode"):GetBool())
    sendSpectateMode(GetConVar("ttt_spectator_mode"):GetBool())
end)
