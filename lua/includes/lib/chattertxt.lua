TTTBots.LocalizedStrings = {}

--- Add a line into the localized strings table, according to its language. Depending on the type of event, the line may contain parameters.
--- An example is "Hi, my name is {{botname}}" -> "Hi, my name is Bob"
---@param event_name string The name of the event
---@param line string The line to add
---@param lang string The language to add the line to, e.g. "en"
---@param conditions function A callback function, passed the bot, that returns a boolean indicating whether the line should be chosen at runtime.
function TTTBots.LocalizedStrings.AddLine(event_name, line, lang, conditions)
    local lang = lang or "en"
    local langtable = TTTBots.LocalizedStrings[lang]
    if not langtable then
        TTTBots.LocalizedStrings[lang] = {}
        langtable = TTTBots.LocalizedStrings[lang]
    end
    langtable[event_name] = langtable[event_name] or {}

    table.insert(langtable[event_name], {
        line = line,
        conditions = conditions or (function() return true end)
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

--- Gets a random valid line from the given event name and language. After 20 attempts, it will return nil.
---@param event_name string
---@param lang string
---@param bot Player
---@param attemptN number|nil
---@return string|nil
function TTTBots.LocalizedStrings.GetLine(event_name, lang, bot, attemptN)
    if attemptN and attemptN > 20 then return nil end
    local tbl = TTTBots.LocalizedStrings[lang] and TTTBots.LocalizedStrings[lang][event_name]
    if not tbl then
        TTTBots.LocalizedStrings[lang] = TTTBots.LocalizedStrings[lang] or {}
        TTTBots.LocalizedStrings[lang][event_name] = TTTBots.LocalizedStrings[lang][event_name] or {}
        print("No localized strings for event " .. event_name .. " in language " .. lang)
        return
    end

    local randLine = table.Random(tbl)
    local lineValid = randLine.conditions(bot)
    if not lineValid then
        return TTTBots.LocalizedStrings.GetLine(event_name, lang, bot, (attemptN and attemptN + 1) or 2)
    end

    return randLine.line
end

function TTTBots.LocalizedStrings.GetLocalizedLine(event_name, bot, params)
    local lang = TTTBots.Lib.GetConVarString("language")
    return TTTBots.LocalizedStrings.FormatLine(TTTBots.LocalizedStrings.GetLine(event_name, lang, bot), params)
end

include("includes/data/chat_en.lua")
