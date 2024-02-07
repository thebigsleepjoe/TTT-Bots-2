--- This file differs from chatter, as the strings are returned with formattable symbols. (like %s, %d, etc.)

local function loc(id, content)
    local lang = "fr"
    TTTBots.Locale.AddLocalizedString(id, content, lang)
end

loc("not.implemented",
    "[ERREUR] Pas encore implémenté. Veuillez utiliser les commandes de la console à la place. Consultez la page du workshop ou le github pour un tutoriel sur l'utilisation de ce mod.")
loc("bot.not.found", "[ERREUR] Bot nommé '%s' introuvable.")
loc("specify.bot.name", "[ERREUR] Veuillez spécifier un nom de bot.")
loc("invalid.bot.number", "[ERREUR] Veuillez spécifier un nombre valide de bots à ajouter.")
loc("no.navmesh",
    "[ERREUR] Cette carte n'a pas de maillage de navigation ! Vous ne pouvez pas utiliser de bots sans cela !")
loc("not.server",
    "[ERREUR] Vous devez jouer sur un serveur pour utiliser les Bots TTT. Désolé ! Cela peut être un serveur p2p ou dédié.")
loc("not.server.guide",
    "[ERREUR] Ne vous inquiétez pas ! Consultez la page du workshop des Bots TTT pour un guide sur l'hébergement d'un serveur.")
loc("not.superadmin", "[ERREUR] Vous ne pouvez pas exécuter cette commande à moins d'être un superadmin sur ce serveur.")
loc("gamemode.not.compatible",
    "[ERREUR] Ce mode de jeu n'est pas compatible avec les Bots TTT ! Silence pour éviter le spam de la console.")
loc("too.many.regions",
    "[AVERTISSEMENT] Il y a %d régions présentes sur cette carte. Il est recommandé de garder ce nombre aussi bas que possible. Cela peut causer des problèmes si non résolu.")
loc("not.enough.slots", "[AVERTISSEMENT] Il n'y a pas assez d'emplacements de joueurs pour ajouter un autre bot.")
loc("not.enough.slots.n", "[AVERTISSEMENT] Il n'y a pas assez d'emplacements de joueurs pour ajouter %s bots.")
loc("consider.kicking",
    "[AVERTISSEMENT] Veuillez envisager d'expulser des bots, ou de créer un serveur avec plus d'emplacements.")
loc("bot.added", "[AVIS] '%s' a ajouté un bot.")
loc("bot.kicked", "[AVIS] '%s' a expulsé un bot (%s).")
loc("bot.kicked.reason", "Expulsé par l'administrateur du serveur '%s'")
loc("bot.kicked.all", "[AVIS] '%s' a expulsé tous les bots.")
loc("bot.rr", "[AVIS] '%s' a redémarré la manche et ajouté %s bots.")
loc("bot.quota.changed", "[AVIS] %s a ajusté le quota de bots à %d bots.")
loc("bot.notice", "[AVIS] Vous jouez un match avec %d bots TTT sur le serveur.")
loc("fail.create.bot",
    "Un bot n'a pas pu être créé. Veuillez vérifier que vous êtes sur un serveur (P2P ou SRCDS) disposant de suffisamment d'emplacements pour les joueurs.")

loc("difficulty.1", "Très Facile")
loc("difficulty.2", "Facile")
loc("difficulty.3", "Normal")
loc("difficulty.4", "Difficile")
loc("difficulty.5", "Très Difficile")
loc("difficulty.?", "(Non Implémenté)")
loc("difficulty.invalid", "La difficulté que vous avez saisie est invalide. Elle doit être un nombre de 1 à 5.")
loc("difficulty.changed", "La difficulté des Bots TTT a été modifiée à %s (depuis %s)")
loc("difficulty.current", "La difficulté actuelle est réglée sur '%s'")
loc("difficulty.changed.kickgood",
    "Puisque la difficulté a été abaissée, le serveur peut commencer à retirer les bots surperformants si nécessaire.")
loc("difficulty.changed.kickbad",
    "Puisque la difficulté a été augmentée, le serveur peut commencer à retirer les bots sous-performants si nécessaire.")
loc("following.traits", " a les traits de personnalité suivants : ")

loc("help.botadd",
    "Ajoute un bot au serveur. Utilisation : !addbot X, où X est le nombre de bots à ajouter. X est facultatif et peut être laissé vide.")
loc("help.botkickall", "Expulse tous les bots du serveur.")
loc("help.botrr", "Redémarre la manche et ajoute le même nombre de bots qu'avant.")
loc("help.botdescribe", "Décrit la personnalité d'un bot. Utilisation : !describe X, où X est le nom du bot.")
loc("help.botmenu", "Ouvre le menu bot. (Non implémenté encore)")
loc("help.botdifficulty",
    "Change la difficulté des bots. Utilisation : !difficulty X, où X est l'entier de difficulté (de 1 à 5).")
loc("help.bothelp", "Affiche ce menu.")
loc("no.kickname", "Vous devez fournir un nom de bot à expulser.")
loc("bot.not.found", "Aucun bot ne correspond au nom '%s'")
