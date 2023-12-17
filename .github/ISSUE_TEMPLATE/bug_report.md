---
name: Bug report
about: Create a report to help us improve
title: "[BUG] New bug report (please rename)"
labels: bug
assignees: thebigsleepjoe

---
## Game version/server type
* SERVER TYPE (PICK ONE): P2P or SRCDS or ALL
* WHICH TTT (PICK ONE): TTT or TTT2 or TTT/2
* WHAT VERSION OF BOTS: Run the ttt_bot_version command to see the current version.

## Describe the bug
A clear and concise description of what the bug is.

## Stack trace/error
The error, if any. Example:

```
[ttt bots 2] addons/ttt bots 2 electric boogaloo/lua/tttbots2/lib/botlib.lua:893: attempt to index a nil value
  1. GetConVarBool - addons/ttt bots 2 electric boogaloo/lua/tttbots2/lib/botlib.lua:893
   2. fn - addons/ttt bots 2 electric boogaloo/lua/autorun/server/tttbots-main.lua:112
    3. Run - lua/ulib/shared/hook.lua:109
     4. unknown - gamemodes/terrortown/gamemode/server/sv_main.lua:1211

Timer Failed! [prep2begin][@gamemodes/terrortown/gamemode/server/sv_main.lua (line 1013)]
```
⚠️ If there is no error, please ensure you remove the triple backticks, or else your formatting will break.

## Reproducing the bug
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected behavior
A clear and concise description of what you expected to happen.

E.g., "There should not be any errors thrown," or "The bots shouldn't die after sending a chat message."

## Screenshots
Screenshots are always appreciated but not required (depending on the bug)

## Additional context
Providing extra context, including a mod collection or simple mod list, can greatly assist in bug reporting.

