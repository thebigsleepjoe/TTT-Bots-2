TTTBots.LocalizedStrings = {}

--- Add a line into the localized strings table, according to its language. Depending on the type of event, the line may contain parameters.
--- An example is "Hi, my name is {{botname}}" -> "Hi, my name is Bob"
---@param event_name string The name of the event
---@param line string The line to add
---@param lang string The language to add the line to, e.g. "en"
---@param archetype string A string corresponding to a TTTBots.Archetypes enum
function TTTBots.LocalizedStrings.AddLine(event_name, line, lang, archetype)
    local lang = lang or "en"
    local langtable = TTTBots.LocalizedStrings[lang]
    if not langtable then
        TTTBots.LocalizedStrings[lang] = {}
        langtable = TTTBots.LocalizedStrings[lang]
    end
    langtable[event_name] = langtable[event_name] or {}

    table.insert(langtable[event_name], {
        line = line,
        archetype = archetype or "default"
    })

    -- print(string.format("Added line '%s' to event '%s' in language '%s'", line, event_name, lang))
end

--- Format a line with parameters
---@param line string The line to format
---@param params table<string, string> A table of parameters to replace in the line
---@return string line The formatted line
function TTTBots.LocalizedStrings.FormatLine(line, params)
    for key, value in pairs(params) do
        line = line:gsub("{{" .. tostring(key) .. "}}", tostring(value))
    end
    return line
end

local function getArchetypalLines(bot, localizedTbl, forceDefault)
    local archetypeLocalized = {}
    local personality = bot.components.personality ---@type CPersonality
    for i, entry in pairs(localizedTbl) do
        if entry.archetype == (forceDefault and TTTBots.Archetypes.Default) or personality.archetype then
            table.insert(archetypeLocalized, entry)
        end
    end
    if #archetypeLocalized == 0 and not forceDefault then -- add forceDefault check to prevent infinite recursion
        return getArchetypalLines(bot, localizedTbl, true)
    end

    return archetypeLocalized
end

--- Gets a random valid line from the given event name and language. After 20 attempts, it will return nil.
---@param event_name string
---@param lang string
---@param bot Player
---@param attemptN number|nil
---@return string|nil
function TTTBots.LocalizedStrings.GetLine(event_name, lang, bot, attemptN)
    if attemptN and attemptN > 20 then return nil end
    local localizedTbl = TTTBots.LocalizedStrings[lang] and TTTBots.LocalizedStrings[lang][event_name]
    if not localizedTbl then
        TTTBots.LocalizedStrings[lang] = TTTBots.LocalizedStrings[lang] or {}
        TTTBots.LocalizedStrings[lang][event_name] = TTTBots.LocalizedStrings[lang][event_name] or {}
        print("No localized strings for event " ..
            event_name .. " in language " .. lang .. "... try setting lang cvar to 'en'.")
        return
    end

    local archetypeLocalizedLines = getArchetypalLines(bot, localizedTbl)
    local randArchetypal = table.Random(archetypeLocalizedLines)

    return randArchetypal.line
end

function TTTBots.LocalizedStrings.GetLocalizedLine(event_name, bot, params)
    local lang = TTTBots.Lib.GetConVarString("language")
    return TTTBots.LocalizedStrings.FormatLine(TTTBots.LocalizedStrings.GetLine(event_name, lang, bot), params)
end

--- Return true if the event has any lines associated in this language.
---@param event_name string
---@return boolean
function TTTBots.LocalizedStrings.TestEventExists(event_name)
    local lang = TTTBots.Lib.GetConVarString("language")
    return TTTBots.LocalizedStrings[lang] and TTTBots.LocalizedStrings[lang][event_name] and true or false
end

function TTTBots.LocalizedStrings.GetLocalizedPlanLine(event_name, bot, params)
    local lang = TTTBots.Lib.GetConVarString("language")
    local modifiedEvent = "Plan." .. event_name
    local exists = TTTBots.LocalizedStrings.TestEventExists(modifiedEvent)

    if not exists then return false end

    return TTTBots.LocalizedStrings.FormatLine(TTTBots.LocalizedStrings.GetLine(modifiedEvent, lang, bot), params)
end

include("includes/data/chat_en.lua")
