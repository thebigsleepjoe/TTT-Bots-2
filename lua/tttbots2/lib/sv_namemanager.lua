include("tttbots2/data/sh_usernames.lua")

local function splitstr(str, delimiter)
    if delimiter == nil then
        delimiter = "%s"
    end
    local t = {}
    for str in string.gmatch(str, "([^" .. delimiter .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function TTTBots.Lib.GetCustomNames()
    local customNamesCSV = TTTBots.Lib.GetConVarString("names_custom")
    local vals = {
        [""] = true,
        [" "] = true,
    }
    if vals[customNamesCSV] then return end
    local customNames = splitstr(customNamesCSV, ",")

    return customNames or {}
end

local Lib = TTTBots.Lib

function Lib.LeetSpeak(txt)
    -- commented out some letters to make less insane for long names especially
    local leet = {
        -- ["a"] = "4",
        -- ["b"] = "8",
        ["e"] = "3",
        ["g"] = "6",
        ["i"] = "1",
        -- ["l"] = "1",
        ["o"] = "0",
        -- ["s"] = "5",
        -- ["t"] = "7",
        ["z"] = "2"
    }

    local newtxt = ""

    for i = 1, #txt do
        local char = txt:sub(i, i)
        if leet[char] then
            newtxt = newtxt .. leet[char]
        else
            newtxt = newtxt .. char
        end
    end

    return newtxt
end

local function checkChars(str)
    -- check if less than 15 characters, return true if so
    return string.len(str) < 15
end

--- Percent chance of a community name being selected if enabled.
local COMMUNITY_NAME_CHANCE = 40
--- Percent chance of a generic name being selected if enabled. Assuming that a community name is not selected.
local GENERIC_NAME_CHANCE = 50

function Lib.CheckNameInUse(name)
    for i, v in pairs(player.GetAll()) do
        if string.lower(v:Nick()) == string.lower(name) then return true end
    end
    return false
end

---Returns the first unused name from a table of names.
---@param names table<string>
---@param makeLower boolean
---@return string|boolean String if a name is found, false if not.
function Lib.GetFirstUnusedName(names, makeLower)
    if not (names and type(names) == "table") then return false end
    local playerNames = {}
    for i, v in pairs(player.GetAll()) do
        if not IsValid(v) then continue end
        local nameAdjusted = (makeLower and v:Nick()) or string.lower(v:Nick())
        playerNames[nameAdjusted] = true
    end

    -- Now we've indexed all the player names, we can check if the desired name is in use
    for i, name in pairs(names) do
        local nameAdjusted = (makeLower and name) or string.lower(name)
        if not playerNames[nameAdjusted] then
            return name
        end
    end
    return false
end

-- regex to select all text:
function Lib.GenerateName()
    local GetCVB = Lib.GetConVarBool

    local customName = Lib.GetFirstUnusedName(Lib.GetCustomNames(), false)
    if customName then return customName end -- Just return it now, don't mess with it, the user wants it like this.


    local prefix = GetCVB("names_prefixes") and "[BOT] " or ""
    local human_name = TTTBots.Lib.humanNames[math.random(1, #TTTBots.Lib.humanNames)]
    local animal_name = TTTBots.Lib.animalNames[math.random(1, #TTTBots.Lib.animalNames)]
    local adjective = TTTBots.Lib.adjectives[math.random(1, #TTTBots.Lib.adjectives)]
    local name_override = TTTBots.Lib.communityNames[math.random(1, #TTTBots.Lib.communityNames)]
    local generic_name_override = TTTBots.Lib.genericNames[math.random(1, #TTTBots.Lib.genericNames)]

    local number = math.random(1, 9999)
    local leetify = GetCVB("names_canleetify") and math.random(1, 100) > 92
    local use_number = GetCVB("names_canusenumbers") and math.random(1, 100) > 80
    local use_adjective = math.random(1, 100) > 60
    local use_animal = math.random(1, 100) > 50 -- else use human name

    local community_enabled = GetCVB("names_allowcommunity") and
        (GetCVB("names_communityonly") or math.random(1, 100) <= COMMUNITY_NAME_CHANCE)
    local generic_enabled = GetCVB("names_allowgeneric") and math.random(1, 100) <= GENERIC_NAME_CHANCE

    local noSpaces = not GetCVB("names_canusespaces")

    -- 1 = all caps, 2-5 = normal, 6-8 = no caps (fr fr)
    local capitalization = math.random(1, 8)

    local name = ""

    if not community_enabled then
        if generic_enabled then
            name = generic_name_override
        else
            if use_adjective then
                name = adjective
            end

            if use_animal then
                name = name .. animal_name
            else
                name = name .. human_name
            end

            if use_number then
                name = name .. number
            end
        end
    else
        name = name_override
    end

    if leetify then
        name = Lib.LeetSpeak(name)
    end

    if capitalization == 1 then
        name = name:upper()
    elseif capitalization >= 6 then
        name = name:lower()
    end

    if noSpaces then
        name = name:gsub(" ", "")
    end

    -- Check if name exists already before returning
    for _, ply in pairs(player.GetAll()) do
        if ply:GetName():lower() == name:lower() then
            return Lib.GenerateName()
        end
    end

    local result = prefix .. name

    if Lib.CheckNameInUse(result) then
        return Lib.GenerateName()
    end

    return result
end
