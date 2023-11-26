TTTBots.DebugServer = {
    data = {}
}
--[[
    Data table example:
    {
        identifier_line = {
            type = "line",
            start = Vector(0, 0, 0),
            ending = Vector(0, 0, 0),
            color = Color(255, 255, 255, 255),
            width = 1
        },
        identifier_box = {
            type = "box",
            start = Vector(0, 0, 0),
            ending = Vector(0, 0, 0),
            color = Color(255, 255, 255, 255),
            width = 1
        },
        identifier_text = {
            type = "text",
            pos = Vector(0, 0, 0),
            text = "Hello world!",
        }
    }
]]
local DebugServer = TTTBots.DebugServer

function DebugServer.ChangeDrawData(identifier, newdata)
    DebugServer.data[identifier] = newdata
end

function DebugServer.GetCompressedTable(tbl)
    local uncompressed_data = util.TableToJSON(tbl)
    local compressed_data = util.Compress(uncompressed_data)
    local bytes_amt = string.len(compressed_data)

    return compressed_data, bytes_amt
end

function DebugServer.SendDrawData()
    -- net.WriteTable()
    local compressed_data, bytes_amt = DebugServer.GetCompressedTable(DebugServer.data)


    net.Start("TTTBots_DrawData")
    net.WriteUInt(bytes_amt, 32)
    net.WriteData(compressed_data, bytes_amt)
    net.Broadcast()

    DebugServer.data = {}
end

-- Recieve net request "TTTBots_RequestData"
net.Receive("TTTBots_RequestData", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    local botData = {} -- todo

    for i, bot in pairs(TTTBots.Bots) do
        if not (bot and bot.components and bot.components.locomotor) then continue end
        ---@type CLocomotor
        local locomotor = bot.components.locomotor
        ---@type CMemory
        local memory = bot.components.memory
        ---@type CPersonality
        local personality = bot.components.personality
        ---@type CInventory
        local inventory = bot.components.inventorymgr

        local heldWeaponInfo = inventory:GetHeldWeaponInfo()
        local primaryWepInfo = inventory:GetPrimary()
        local secondaryWepInfo = inventory:GetSecondary()
        local heldWepTxt = inventory:GetWepInfoText(heldWeaponInfo)
        local primaryWepTxt = inventory:GetWepInfoText(primaryWepInfo)
        local secondaryWepTxt = inventory:GetWepInfoText(secondaryWepInfo)

        local numKnownPos = #memory:GetKnownPlayersPos()
        local numKnownAlive = #memory:GetKnownAlivePlayers()
        local actualNumAlive = #memory:GetActualAlivePlayers()
        -- local knownAlivePct = numKnownAlive / actualNumAlive

        local behaviorName = bot.currentBehavior and bot.currentBehavior.Name or "None"
        local behaviorDesc = bot.currentBehavior and bot.currentBehavior.Description or "None"

        local traits = personality:GetTraits()
        local traitsCommaSep = table.concat(traits, ", ")

        local abm = bot.attackBehaviorMode
        local attackModeEnums = {
            [1] = "Hunting",
            [2] = "Seeking",
            [3] = "Engaging"
        }
        local abmTxt = attackModeEnums[abm] or "n/a"

        botData[bot:Nick()] = {
            strafeDir = locomotor:GetStrafe() or "None",
            isPathing = locomotor:HasPath() or false,
            isDoored = locomotor.targetDoor ~= nil,
            tick = bot.tick,
            timeInGame = bot.timeInGame,
            isAlive = TTTBots.Lib.IsPlayerAlive(bot),
            numCanSee = #memory:GetRecentlySeenPlayers(),
            numKnownPos = numKnownPos,
            numKnownAlive = numKnownAlive,
            attackTargetName = (
                bot.attackTarget
                and (
                    bot.attackTarget:IsPlayer() and bot.attackTarget:Nick()
                    or bot.attackTarget:GetClass())
                or "No target"
            ),
            attackBehaviorMode = abm and (abm .. " (" .. abmTxt .. ")") or "None",
            behaviorName = behaviorName,
            behaviorDesc = behaviorDesc,
            isEvil = TTTBots.Lib.IsEvil(bot),
            traits = traitsCommaSep,
            hearingMult = memory:GetHearingMultiplier(),
            hearingMult_GunshotDist = TTTBots.Sound.DetectionInfo.Gunshot.Distance * memory:GetHearingMultiplier(),
            stopLookingAround = locomotor.stopLookingAround or "false",
            pathGoalPos = locomotor:GetGoalPos() or "None",
            pathStatus = locomotor.status or "None",
            pauseAutoSwitch = inventory.pauseAutoSwitch or "false",
            weaponHeld = heldWepTxt,
            weaponPrimary = primaryWepTxt,
            weaponSecondary = secondaryWepTxt,
        }
    end

    local compressed, byte_amt = DebugServer.GetCompressedTable(botData)

    net.Start("TTTBots_ClientData")
    net.WriteUInt(byte_amt, 32)
    net.WriteData(compressed, byte_amt)
    net.Send(ply)
end)

-- Settings:
-- {"look", "target", "path", "all"}
---@deprecated
function TTTBots.DebugServer.RenderDebugFor(bot, settings)
    ErrorNoHaltWithStack("Unsupported draw call; drawing anyway.")
    -- Check if "developer" convar is set to 1, spare resources if not
    if not GetConVar("developer"):GetBool() then return end

    local has = table.HasValue
    local all = has(settings, "all")

    if all or has(settings, "look") then TTTBots.DebugServer.DrawBotLook(bot) end
    if all or has(settings, "path") then TTTBots.DebugServer.DrawCurrentPathFor(bot) end
end

---@deprecated
function TTTBots.DebugServer.DrawBotLook(bot)
    ErrorNoHaltWithStack("Unsupported draw call; drawing anyway.")
    if not GetConVar("ttt_bot_debug_look"):GetBool() then return end

    local start = bot:GetShootPos()
    local endpos = bot:GetShootPos() + bot:GetAimVector() * 150

    local tr = util.TraceLine({
        start = start,
        endpos = endpos,
        filter = bot
    })

    if tr.Hit then
        endpos = tr.HitPos
    else
        endpos = endpos
    end

    DebugServer.ChangeDrawData("botlook_" .. bot:Nick(),
        {
            type = "line",
            start = start,
            ending = endpos,
            color = Color(0, 255, 0, 255),
            width = 5
        })
end

---@deprecated
function TTTBots.DebugServer.DrawCurrentPathFor(bot)
    ErrorNoHaltWithStack("Unsupported draw call; drawing anyway.")
    local pathinfo = bot.components.locomotor.pathinfo
    if not pathinfo or not pathinfo.path then return end

    local path = pathinfo.path
    local age = pathinfo:TimeSince()

    if type(path) ~= "table" then return end

    for i = 1, table.Count(path) - 1 do
        local start = path[i]:GetCenter()
        local ending = path[i + 1]:GetCenter()

        local colorOffset = (age / TTTBots.PathManager.cullSeconds) * 255

        DebugServer.ChangeDrawData("path_" .. bot:Nick() .. i,
            {
                type = "line",
                start = start,
                ending = ending,
                color = Color(255 - colorOffset, 0, colorOffset, 255),
                width = 15
            })
    end
end

function TTTBots.DebugServer.DrawLineBetween(start, finish, color, lifetime, forceID)
    if not (start and finish and color) then return end

    local start_rounded = Vector(math.Round(start.x), math.Round(start.y), math.Round(start.z))
    local finish_rounded = Vector(math.Round(finish.x), math.Round(finish.y), math.Round(finish.z))

    DebugServer.ChangeDrawData(forceID or ("line_" .. tostring(start) .. tostring(finish)),
        {
            type = "line",
            start = start_rounded,
            ending = finish_rounded,
            forceID = forceID,
            lifetime = lifetime,
            color = color,
            width = 5
        })
end

function TTTBots.DebugServer.DrawSphere(pos, radius, color, lifetime, forceID)
    if not (pos and radius and color) then return end

    local pos_rounded = Vector(math.Round(pos.x), math.Round(pos.y), math.Round(pos.z))

    DebugServer.ChangeDrawData("sphere_" .. tostring(pos) .. tostring(radius),
        {
            type = "sphere",
            pos = pos_rounded,
            radius = radius,
            color = color,
            forceID = forceID,
            lifetime = lifetime,
            width = 5
        })
end

--- note: cannot pass color, it will always be white with black outline
function TTTBots.DebugServer.DrawText(pos, text, lifetime, forceID)
    if not (pos and text) then return end

    local pos_rounded = Vector(math.Round(pos.x), math.Round(pos.y), math.Round(pos.z))

    DebugServer.ChangeDrawData(forceID or ("text_" .. tostring(pos) .. tostring(text)),
        {
            type = "text",
            pos = pos_rounded,
            forceID = forceID,
            lifetime = lifetime,
            text = text
        })
end

function TTTBots.DebugServer.DrawCross(pos, size, color, lifetime, forceID)
    if not (pos and size and color) then return end

    local pos_rounded = Vector(math.Round(pos.x), math.Round(pos.y), math.Round(pos.z))

    DebugServer.ChangeDrawData(forceID or ("cross_" .. tostring(pos) .. tostring(size)),
        {
            type = "cross",
            pos = pos_rounded,
            size = size,
            color = color,
            forceID = forceID,
            lifetime = lifetime,
        })
end

function TTTBots.DebugServer.DrawBox(origin, mins, maxs, color, lifetime, forceID)
    if not (origin and mins and maxs and color) then return end

    local origin_rounded = Vector(math.Round(origin.x), math.Round(origin.y), math.Round(origin.z))
    local mins_rounded = Vector(math.Round(mins.x), math.Round(mins.y), math.Round(mins.z))
    local maxs_rounded = Vector(math.Round(maxs.x), math.Round(maxs.y), math.Round(maxs.z))

    DebugServer.ChangeDrawData(forceID or ("box_" .. tostring(origin_rounded)),
        {
            type = "box",
            origin = origin_rounded,
            maxs = maxs_rounded,
            mins = mins_rounded,
            color = color,
            width = 5,
            forceID = forceID,
            lifetime = lifetime,
        })
end

-- Send latest draw data to clients every 0.1 seconds
timer.Create("TTTBots_SendDrawData", 0.1, 0, function()
    DebugServer.SendDrawData()
end)
