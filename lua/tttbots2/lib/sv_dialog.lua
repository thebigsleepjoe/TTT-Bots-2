TTTBots.Locale.Dialog = {}
---@class TTTBots.DialogModule
local Dialog = TTTBots.Locale.Dialog

---@class Dialog
---@field name string
---@field participants table<Player> A list of current player participants
---@field targetNumber number The ideal number of participants (not the current number)
---@field lines table<number, DialogLine>
---@field currentLine number
---@field isFinished boolean
---@field onlyWhenDead boolean If the participants can only talk when all dead.
---@field waiting boolean If the dialog is waiting for a callback to continue.
---@alias DialogTemplate Dialog

---@class DialogLine
---@field line string The 'line' (actually the event name) of the dialog line.
---@field spoken boolean
---@field participantId number The ID of the participant who spoke/should speak this line.

Dialog.Templates = {} --- @type table<string, Dialog>

---Create a line for template creation.
---@param line string Basically just the ID of the chat_en entry.
---@param participantId number The ID of the participant who spoke/should speak this line.
---@return DialogLine
function Dialog.NewLine(line, participantId)
    return {
        line = line,
        spoken = false,
        participantId = participantId,
    }
end

function Dialog.NewTemplate(name, targetNumber, lines, onlyWhenDead)
    local newDialog = {
        name = name,
        targetNumber = targetNumber,
        lines = lines,
        currentLine = 1,
        isFinished = false,
        onlyWhenDead = onlyWhenDead,
        waiting = false,
    }
    Dialog.Templates[name] = newDialog
    return newDialog
end

---Selects some participants at random
---@param template DialogTemplate
---@return table<Player>|false participants
function Dialog.SelectParticipants(template)
    local num = template.targetNumber
    local possibleBots = TTTBots.Lib.FilterTable(TTTBots.Bots, function(bot)
        if not IsValid(bot) then return false end
        local botAlive = TTTBots.Lib.IsPlayerAlive(bot)
        return botAlive or template.onlyWhenDead
    end)

    local participants = {} ---@type table<Player>
    for i = 1, num do
        local rand = table.Random(possibleBots) ---@type Player|nil
        if not rand then return false end -- No more bots left, we can't do this one.
        table.insert(participants, rand)
        table.RemoveByValue(possibleBots, rand)
    end

    return participants
end

function Dialog.EndDialog(dialog)
    dialog.isFinished = true
    dialog.waiting = false
end

---Verify if a dialog can be continued.
---@param dialog Dialog
---@return boolean canContinue
function Dialog.VerifyLifeStates(dialog)
    local shouldBeAlive = not dialog.onlyWhenDead
    local participants = dialog.participants
    local IsAlive = TTTBots.Lib.IsPlayerAlive
    for i, participant in pairs(participants) do
        if not IsValid(participant) then return false end -- If one of them leaves the game then we can't continue
        if IsAlive(participant) ~= shouldBeAlive then
            return false
        end
    end

    return true
end

---Executes the next line of a dialog.
---@param dialog Dialog
---@return Dialog dialog
function Dialog.ExecuteDialog(dialog)
    if dialog.isFinished or dialog.waiting then return dialog end
    local dline = dialog.lines[dialog.currentLine]
    if not dline then
        Dialog.EndDialog(dialog)
        return dialog
    end
    local participant = dialog.participants[dline.participantId] ---@type Bot

    if not Dialog.VerifyLifeStates(dialog) then -- We cannot run a dialog if the participants are alive when they shouldn't be
        Dialog.EndDialog(dialog)
        return dialog
    end

    local lastdline = dialog.lines[dialog.currentLine - 1]
    local lastParticipant = lastdline and dialog.participants[lastdline.participantId] ---@type Player|nil
    local lastParticipantName = lastParticipant and lastParticipant:Nick() or ""

    local nextdline = dialog.lines[dialog.currentLine + 1]
    local nextParticipant = nextdline and dialog.participants[nextdline.participantId] ---@type Player|nil
    local nextParticipantName = nextParticipant and nextParticipant:Nick() or ""

    local translatedLine = TTTBots.Locale.GetLocalizedLine("Dialog" .. dline.line, participant,
        { lastBot = lastParticipantName, nextBot = nextParticipantName, bot = participant:Nick() })

    if not translatedLine then
        Dialog.EndDialog(dialog)
        return dialog
    end

    local chatter = participant:BotChatter()
    if not chatter then
        Dialog.EndDialog(dialog)
        print("no chatter on bot`")
        return dialog
    end
    dialog.waiting = true
    dline.spoken = true
    chatter:Say(translatedLine, false, dialog.onlyWhenDead, function()
        dialog.currentLine = dialog.currentLine + 1
        dialog.waiting = false
    end)

    return dialog
end

---Generate a dialog based on a template.
---@param templateName string
---@param participants? table<Player>
---@return Dialog|false dialog The dialog object, or false if it failed to generate.
function Dialog.New(templateName, participants)
    local template = Dialog.Templates[templateName]
    local dialog = table.Copy(template) ---@type Dialog
    dialog.participants = participants or Dialog.SelectParticipants(template) or {}

    if table.Count(dialog.participants) == 0 then return false end

    return dialog
end

--- Handles the execution of a dialog until it is finished.
---@param dialog Dialog
function Dialog.ExecuteUntilDone(dialog)
    if not (dialog and Dialog.VerifyLifeStates(dialog)) then return end
    dialog = Dialog.ExecuteDialog(dialog)
    if dialog.isFinished then return end
    timer.Simple(5, function()
        Dialog.ExecuteUntilDone(dialog)
    end)
end

function Dialog.NewFromRandom()
    local template = table.Random(Dialog.Templates)
    local participants = Dialog.SelectParticipants(template)
    if not participants then return false end
    return Dialog.New(template.name, participants)
end

include("tttbots2/data/sv_dialogtemplates.lua")

local currentDialog = nil ---@type Dialog|nil
timer.Create("TTTBots.Dialog.StartRandomDialogs", 60, 0, function()
    if math.random(1, 4) > 1 then return end
    if (currentDialog and not Dialog.VerifyLifeStates(currentDialog)) then currentDialog = nil end
    -- if (currentDialog) then PrintTable(currentDialog) end
    if (currentDialog and not currentDialog.isFinished) then return end
    local dialog = Dialog.NewFromRandom()
    if not dialog then return end
    -- print("--- NEW ---")
    -- PrintTable(dialog)
    currentDialog = dialog
    Dialog.ExecuteUntilDone(dialog)
end)
