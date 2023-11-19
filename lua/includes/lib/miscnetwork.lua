-- avatars are stored in "materials/avatars/" with the name "X.png", with a range of [1,5] for X.
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

    -- local avatarNumber = math.random(1, 281)
    -- avatars[bot] = avatarNumber
    local personality = TTTBots.Lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then
        timer.Simple(1, function()
            assignBotAvatar(bot)
        end)
        return
    end

    local pfps_humanlike = TTTBots.Lib.GetConVarBool("pfps_humanlike")
    local assignedImage

    if not pfps_humanlike then
        local difficulty = personality:GetTraitAdditive("difficulty")

        if difficulty <= -4 then
            assignedImage = 1
        elseif difficulty <= -2 then
            assignedImage = 2
        elseif difficulty <= 2 then
            assignedImage = 3
        elseif difficulty <= 4 then
            assignedImage = 4
        else
            assignedImage = 5
        end
    else
        assignedImage = math.random(0, 87)
    end

    -- print("Bot assigned image " .. assignedImage .. " for difficulty " .. difficulty)

    avatars[bot] = assignedImage
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
        avatars_nicks[k:Nick()] = v -- GLua doesn't appreciate sending tbls with keys that are userdata
    end

    net.Start("TTTBots_SyncAvatarNumbers")
    net.WriteTable(avatars_nicks)
    net.Send(ply)
end)
