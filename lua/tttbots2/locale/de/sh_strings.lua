--- Diese Datei unterscheidet sich vom Chatter: die Strings enthalten Formatplatzhalter (%s, %d usw.).
--- Deutsche Übersetzung (de) — Stand 2026-10-04.

local function loc(id, content)
    local lang = "de"
    TTTBots.Locale.AddLocalizedString(id, content, lang)
end

loc("not.implemented",
    "[FEHLER] Noch nicht umgesetzt. Bitte nutze stattdessen die Konsolenbefehle. Eine Anleitung findest du auf der Workshop-Seite oder auf GitHub.")
loc("bot.not.found", "[FEHLER] Kein Bot mit dem Namen '%s' gefunden.")
loc("specify.bot.name", "[FEHLER] Bitte gib einen Bot-Namen an.")
loc("invalid.bot.number", "[FEHLER] Bitte gib eine gültige Anzahl an Bots an.")
loc("no.navmesh", "[FEHLER] Diese Map hat kein Navigationsmesh! Ohne Navmesh können keine Bots spielen!")
loc("not.server",
    "[FEHLER] TTT Bots funktionieren nur auf einem Server. Sorry! Ein P2P-Server oder ein Dedicated Server geht beides.")
loc("not.server.guide", "[FEHLER] Keine Sorge! Auf der Workshop-Seite von TTT Bots steht eine Anleitung, wie du einen Server aufsetzt.")
loc("not.superadmin", "[FEHLER] Diesen Befehl darfst du nur als Superadmin auf diesem Server ausführen.")
loc("gamemode.not.compatible",
    "[FEHLER] Dieser Gamemode ist nicht mit TTT Bots kompatibel! Ich halte jetzt die Klappe, um die Konsole nicht zuzuspammen.")
loc("too.many.regions",
    "[WARNUNG] Auf dieser Map gibt es %d Regionen. Diese Zahl sollte so klein wie möglich sein, sonst kann es zu Problemen kommen.")
loc("not.enough.slots", "[WARNUNG] Es sind nicht genug Spieler-Slots frei, um einen weiteren Bot hinzuzufügen.")
loc("not.enough.slots.n", "[WARNUNG] Es sind nicht genug Spieler-Slots frei, um %s Bots hinzuzufügen.")
loc("consider.kicking", "[WARNUNG] Kicke ein paar Bots oder erstelle einen Server mit mehr Slots.")

loc("bot.added", "[HINWEIS] '%s' hat einen Bot hinzugefügt.")
loc("bot.kicked", "[HINWEIS] '%s' hat einen Bot gekickt (%s).")
loc("bot.kicked.reason", "Vom Server-Administrator '%s' gekickt")
loc("bot.kicked.all", "[HINWEIS] '%s' hat alle Bots gekickt.")
loc("bot.rr", "[HINWEIS] '%s' hat die Runde neu gestartet und %s Bots hinzugefügt.")
loc("bot.quota.changed", "[HINWEIS] %s hat die Bot-Quota auf %d Bots gesetzt.")
loc("bot.notice", "[HINWEIS] Du spielst eine Runde mit %d TTT-Bots auf dem Server.")
loc("fail.create.bot",
    "Es konnte kein Bot erstellt werden. Prüfe, ob du auf einem Server (P2P oder SRCDS) mit genügend Spieler-Slots bist.")

loc("difficulty.1", "Sehr leicht")
loc("difficulty.2", "Leicht")
loc("difficulty.3", "Normal")
loc("difficulty.4", "Schwer")
loc("difficulty.5", "Sehr schwer")
loc("difficulty.?", "(Nicht umgesetzt)")
loc("difficulty.invalid", "Die eingegebene Schwierigkeit ist ungültig. Es muss eine Zahl von 1 bis 5 sein.")
loc("difficulty.changed", "Die Schwierigkeit der TTT-Bots wurde auf %s geändert (vorher %s)")
loc("difficulty.current", "Die aktuelle Schwierigkeit ist '%s'")
loc("difficulty.changed.kickgood",
    "Da die Schwierigkeit gesenkt wurde, entfernt der Server bei Bedarf Bots, die zu stark sind.")
loc("difficulty.changed.kickbad",
    "Da die Schwierigkeit erhöht wurde, entfernt der Server bei Bedarf Bots, die zu schwach sind.")
loc("following.traits", " hat folgende Persönlichkeitsmerkmale: ")

loc("help.botadd",
    "Fügt dem Server einen Bot hinzu. Nutzung: !addbot X, wobei X die Anzahl der Bots ist. X ist optional und kann weggelassen werden.")
loc("help.botkickall", "Kickt alle Bots vom Server.")
loc("help.botrr", "Startet die Runde neu und fügt genauso viele Bots hinzu wie vorher.")
loc("help.botdescribe", "Beschreibt die Persönlichkeit eines Bots. Nutzung: !describe X, wobei X der Name des Bots ist.")
loc("help.botmenu", "Öffnet das Bot-Menü. (Noch nicht umgesetzt)")
loc("help.botdifficulty",
    "Ändert die Schwierigkeit der Bots. Nutzung: !difficulty X, wobei X die Schwierigkeit als Zahl (1 bis 5) ist.")
loc("help.bothelp", "Zeigt dieses Menü.")
loc("no.kickname", "Du musst einen Bot-Namen angeben, um ihn zu kicken.")
loc("bot.not.found", "Kein Bot passt zum Namen '%s'")

-- Botmenu
loc('dashboard', 'Übersicht')
loc('current.bots', 'Aktuelle Bots')
loc('build.a.bot', 'Bot-Baukasten')
loc('bot.names', 'Bot-Namen')
loc('traits', 'Merkmale')
loc('buyables', 'Kaufbares')
loc('add', 'Hinzufügen')
loc('add.name', 'Name')
loc('remove.selected', 'Auswahl entfernen')
loc('name', "Name")
