-- avatars are stored in "materials/avatars/" with the name "BotAvatar (1).jpg", going up to 281 avatars.
-- so each ply object is assigned to an avatar number
local avatars = {}

local function validateAvatarCache()
    for k, v in pairs(avatars) do
        if not IsValid(k) then
            avatars[k] = nil
        end
    end
end

local function assignBotAvatar(bot)
    validateAvatarCache()

    local avatarNumber = math.random(1, 281)
    avatars[bot] = avatarNumber
end

hook.Add("PlayerInitialSpawn", "TTTBots_PlayerInitialSpawn", function(ply)
    if ply:IsBot() then
        assignBotAvatar(ply)
    end
end)

-- Client is requesting we sync the bot avatar numbers, we will send the table of bot avatar numbers to the client
net.Receive("TTTBots_SyncAvatarNumbers", function(len, ply)
    validateAvatarCache()
    local avatars_nicks = {}

    for k, v in pairs(avatars) do
        avatars_nicks[k:Nick()] = v
    end

    net.Start("TTTBots_SyncAvatarNumbers")
    net.WriteTable(avatars_nicks) -- GLua doesn't appreciate sending tbls with keys that are userdata
    net.Send(ply)
end)
