--[[
    This file defines a list of chats that bots will say upon a certain kind of event. It is designed for one-off chatter events, instead of back-and-forth conversation.
    For that, we will have a separate file, and likely use the Localized String system.

    TRANSLATORS:
    - ChatGPT
    - GitHub Copilot
    - ???
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadLang = function()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "fr", archetype)
    end
    local RegisterCategory = function(event, priority)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "fr", priority)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS

    -----------------------------------------------------------
    -- ENTRANCE/EXIT FROM SERVER
    -----------------------------------------------------------

    RegisterCategory("DisconnectBoredom", P.CRITICAL)
    Line("Je m'ennuie. Salut.", A.Default)
    Line("Rien ne se passe ici. Je me casse.", A.Default)
    Line("À plus quand il y aura plus d'action.", A.Default)
    Line("Pas grand-chose à faire. À plus tard.", A.Default)
    Line("Ce n'est pas mon truc. À plus.", A.Default)
    Line("Je me tire. Salut.", A.Default)

    Line("à plus tard", A.Casual)
    Line("je reviens, c'est pas ça", A.Casual)
    Line("à la prochaine.", A.Casual)
    Line("à plus", A.Casual)
    Line("salut plus tard, les gens.", A.Casual)
    Line("je reviens (non je reviens pas)", A.Casual)

    Line("Quel ennui. Je me barre.", A.Bad)
    Line("Réveillez-moi quand ce sera intéressant. Je sors.", A.Bad)
    Line("Bâillement... À plus les losers.", A.Bad)
    Line("Ce jeu est ennuyeux. Je pars.", A.Bad)
    Line("C'est nul. J'en ai marre.", A.Bad)
    Line("Vous êtes tous ennuyeux. Salut.", A.Bad)

    Line("où est le bouton de sortie mdr", A.Dumb)
    Line("comment on quitte garry's mod", A.Dumb)
    Line("comment on éteint ça ?", A.Dumb)
    Line("euh... salut ou quelque chose", A.Dumb)
    Line("Je suis coincé. Ah non, il y a un bouton de sortie.", A.Dumb)
    Line("C'est trop compliqué. Salut.", A.Dumb)

    Line("À plus les nuls", A.Hothead)
    Line("Vous êtes tous insupportables. Au revoir.", A.Hothead)
    Line("Je me tire avant de craquer.", A.Hothead)
    Line("Assez de ces bêtises. À plus.", A.Hothead)
    Line("Je peux pas avec vous. Salut.", A.Hothead)
    Line("Ugh, j'en ai marre. Salut.", A.Hothead)

    Line("Je vais faire autre chose. Salut !!", A.Nice)
    Line("C'était sympa, mais je m'en vais. Prenez soin de vous !", A.Nice)
    Line("Vous êtes tous super, mais j'ai besoin d'une pause. Salut !", A.Nice)
    Line("C'était cool, à bientôt tout le monde !", A.Nice)
    Line("Merci pour la compagnie. À la prochaine !", A.Nice)
    Line("C'était super. À plus tard !", A.Nice)

    Line("Au revoir.", A.Stoic)
    Line("Adieu.", A.Stoic)
    Line("Je pars maintenant.", A.Stoic)
    Line("Il est temps pour moi de partir.", A.Stoic)
    Line("Je dois partir.", A.Stoic)
    Line("Adieu pour l'instant.", A.Stoic)

    Line("Je vais jouer à Valorant.", A.Tryhard)
    Line("Je passe à un jeu plus compétitif. Salut.", A.Tryhard)
    Line("Besoin de plus de défi. À plus.", A.Tryhard)
    Line("Je pars m'entraîner. Ciao.", A.Tryhard)
    Line("je vais jouer à aimlabs salut", A.Tryhard)
    Line("Je vais me perfectionner ailleurs. Tchao.", A.Tryhard)

    RegisterCategory("ServerConnected", P.NORMAL)
    Line("Je suis de retour !", A.Default)
    Line("Salut tout le monde.", A.Default)
    Line("Prêt à y aller.", A.Default)
    Line("Je suis là.", A.Default)
    Line("Je suis de retour.", A.Default)
    Line("Content d'être ici", A.Default)
    Line("Je suis dedans !", A.Default)
    Line("Je suis là !", A.Default)
    Line("Je suis de retour, tout le monde !", A.Default)
    Line("Je suis de retour, allons-y !", A.Default)
    Line("C'est parti", A.Default)
    Line("Bonjour", A.Default)
    Line("yo je suis là mdr", A.Casual)
    Line("salut tout le monde", A.Casual)
    Line("hey, je viens de rejoindre", A.Casual)
    Line("on fait un peu de jeu", A.Casual)
    Line("euh salut", A.Dumb)
    Line("ce serveur n'est clairement pas un fastdl", A.Dumb)
    Line("salut", A.Dumb)
    Line("je suis sur le serveur", A.Dumb)
    Line("j'adore ttt", A.Dumb)
    Line("Enfin, je suis là ! Allons-y !", A.Hothead)
    Line("Ce temps de chargement était horrible. Excité de jouer.", A.Hothead)
    Line("Ça a pris du temps pour entrer ici", A.Hothead)
    Line("Quoi de neuf, perdants", A.Hothead)
    Line("Wsg idiots", A.Hothead)
    Line("Prêt à en découdre !", A.Hothead)
    Line("Je suis là pour gagner !", A.Hothead)
    Line("Content d'être là !", A.Nice)
    Line("J'ai hâte à ça !", A.Nice)
    Line("Bonjour tout le monde !!", A.Nice)
    Line("Hé les gars, je suis de retour !", A.Nice)
    Line("Je suis là pour m'amuser !", A.Nice)



    -----------------------------------------------------------
    -- TARGET ASSIGNMENT / ATTACK
    -----------------------------------------------------------

    RegisterCategory("DisguisedPlayer", P.IMPORTANT) -- When a bot spots someone with a disguise
    Line("Ce type est déguisé !", A.Default)
    Line("On dirait que quelqu'un joue à cache-cache !", A.Default)
    Line("Un invité mystère parmi nous, hein ?", A.Default)
    Line("mec déguisé par ici", A.Casual)
    Line("joli masque, pote", A.Casual)
    Line("tu joues à l'incognito hein ?", A.Casual)
    Line("Pourquoi je ne peux pas voir ton nom ??", A.Bad)
    Line("Qu'est-ce que tu caches, malin ?", A.Bad)
    Line("Tu ne trompes personne, tu sais", A.Bad)
    Line("c'est qui toi", A.Dumb)
    Line("Euh, où es-tu passé ?", A.Dumb)
    Line("Hé, pourquoi je ne peux pas voir ton visage ?", A.Dumb)
    Line("Petit bébé avec le déguisement", A.Hothead)
    Line("Enlève ce déguisement ridicule !", A.Hothead)
    Line("Arrête de te cacher, lâche !", A.Hothead)
    Line("mon ami est déguisé", A.Sus)
    Line("Ce déguisement est super louche", A.Sus)
    Line("euh quoi le flip", A.Sus)
    Line("Te déguiser ne te sauvera pas", A.Tryhard)
    Line("Déguisé ou non, je te trouverai", A.Tryhard)
    Line("Tu n'échapperas pas à ma vue", A.Tryhard)


    RegisterCategory("CallKOS", P.CRITICAL) -- When a bot is going to call KOS on another player.
    Line("KOS sur {{player}} !", A.Default)
    Line("{{player}} est KOS", A.Default)
    Line("KOS sur {{player}}", A.Default)
    Line("KOS {{player}}", A.Default)
    Line("{{player}} est un traitre !", A.Default)
    Line("{{player}} est un traitre.", A.Default)
    Line("KOS sur {{player}} !!", A.Default)
    Line("kos {{player}}", A.Casual)
    Line("{{player}} est un traitre", A.Casual)
    Line("kos sur {{player}}", A.Casual)
    Line("KOS sur {{player}}", A.Casual)
    Line("tuer {{player}} je pense", A.Bad)
    Line("tuer {{player}}", A.Bad)
    Line("{{player}} est méchant", A.Dumb)
    Line("tuer {{player}} !!!!!11", A.Dumb)
    Line("{{player}} est un traitre ;)", A.Sus)
    Line("vous devriez probablement kos {{player}}", A.Sus)
    Line("KOS sur {{player}}, je pense...", A.Sus)
    Line("KOS {{player}}. C'est sûr.", A.Tryhard)
    Line("KOS sur {{player}}, sans aucun doute.", A.Tryhard)
    Line("KOS {{player}}", A.Tryhard)
    Line("KOS {{player}} MAINTENANT !", A.Tryhard)



    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------

    local ATTACKANY = ACTS.ATTACKANY
    RegisterCategory(f("Plan.%s", ATTACKANY), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line("Je vais attaquer {{player}}.", A.Default)
    Line("J'ai repéré {{player}}.", A.Default)
    Line("Je vais m'occuper de {{player}}.", A.Default)
    Line("Je choisis {{player}}.", A.Default)
    Line("Je vais poursuivre {{player}}.", A.Default)
    Line("Je vais attaquer {{player}}.", A.Default)
    Line("J'ai {{player}} dans mon viseur.", A.Default)
    Line("Je vais prendre {{player}}.", A.Default)
    Line("Je cible {{player}}.", A.Default)
    Line("Je m'occuperai de {{player}}.", A.Default)
    Line("j'ai réservé {{player}}.", A.Casual)
    Line("je vais tuer {{player}}.", A.Casual)
    Line("Je vais essayer d'avoir {{player}}", A.Bad)
    Line("Je vais essayer de tuer {{player}}", A.Bad)
    Line("je vais tuer {{player}}", A.Dumb)
    Line("{{player}} est ma cible à tuer", A.Dumb)
    Line("{{player}} est à moi, idiots.", A.Hothead)
    Line("{{player}} est à moi.", A.Hothead)
    Line("Je vais détruire {{player}}.", A.Hothead)
    Line("Laissez-moi prendre {{player}}!", A.Teamer)
    Line("Prenons {{player}} !!", A.Teamer)
    Line("Je vais prendre {{player}} tout seul. Facile", A.Tryhard)
    Line("Je choisis {{player}}. Ne prenez pas mon as", A.Tryhard)


    local ATTACK = ACTS.ATTACK
    RegisterCategory(f("Plan.%s", ATTACKANY), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line("Je vais attaquer {{player}}.", A.Default)
    Line("J'ai repéré {{player}}.", A.Default)
    Line("Je vais m'occuper de {{player}}.", A.Default)
    Line("Je choisis {{player}}.", A.Default)
    Line("Je vais poursuivre {{player}}.", A.Default)
    Line("Je vais attaquer {{player}}.", A.Default)
    Line("J'ai {{player}} dans mon viseur.", A.Default)
    Line("Je vais prendre {{player}}.", A.Default)
    Line("Je cible {{player}}.", A.Default)
    Line("Je m'occuperai de {{player}}.", A.Default)
    Line("j'ai réservé {{player}}.", A.Casual)
    Line("je vais tuer {{player}}.", A.Casual)
    Line("Je vais essayer d'avoir {{player}}", A.Bad)
    Line("Je vais essayer de tuer {{player}}", A.Bad)
    Line("je vais tuer {{player}}", A.Dumb)
    Line("{{player}} est ma cible à tuer", A.Dumb)
    Line("{{player}} est à moi, idiots.", A.Hothead)
    Line("{{player}} est à moi.", A.Hothead)
    Line("Je vais détruire {{player}}.", A.Hothead)
    Line("Laissez-moi prendre {{player}}!", A.Teamer)
    Line("Prenons {{player}} !!", A.Teamer)
    Line("Je vais prendre {{player}} tout seul. Facile", A.Tryhard)
    Line("Je choisis {{player}}. Ne prenez pas mon as", A.Tryhard)


    local PLANT = ACTS.PLANT
    RegisterCategory(f("Plan.%s", PLANT), P.CRITICAL) -- When a traitor bot is going to plant a bomb.
    Line("Je vais poser une bombe.", A.Default)
    Line("Je pose une bombe.", A.Default)
    Line("Placement d'une bombe !", A.Default)
    Line("Je vais faire sauter cet endroit.", A.Default)


    local DEFUSE = ACTS.DEFUSE
    RegisterCategory(f("Plan.%s", DEFUSE), P.CRITICAL) -- When a traitor bot is going to defuse a bomb.
    Line("Je vais désamorcer une bombe.", A.Default)


    local FOLLOW = ACTS.FOLLOW
    RegisterCategory(f("Plan.%s", FOLLOW), P.CRITICAL) -- When a traitor bot is going to follow a player/bot.
    Line("Je vais suivre {{player}}.", A.Default)



    local GATHER = ACTS.GATHER
    RegisterCategory(f("Plan.%s", GATHER), P.CRITICAL) -- When a traitor bot is going to gather with other bots.
    Line("Rassemblons-nous là-bas.", A.Default)
    Line("Regroupez-vous ici.", A.Default)
    Line("venez ici les gars", A.Casual)
    Line("venez ici", A.Casual)
    Line("rassemblement", A.Casual)
    Line("rassemblez-vous ici", A.Casual)
    Line("Allez, vous idiots, par ici.", A.Hothead)
    Line("Rassemblez-vous, idiots.", A.Hothead)
    Line("Le travail d'équipe, c'est le rêve qui fonctionne", A.Teamer)
    Line("Nous ne sommes pas une maison divisée", A.Teamer)
    Line("Regroupez-vous pour que je puisse vous utiliser comme boucliers humains.", A.Tryhard)
    Line("Regroupez-vous, j'ai besoin de vous comme boucliers de chair.", A.Tryhard)
    Line("euh... rassemblons-nous, mdr", A.Dumb)
    Line("rassemblons-nous et laveons-nous", A.Dumb)
    Line("Allez, regroupez-vous. Où est mon câlin ?", A.Stoic)
    Line("Regroupons-nous, j'ai besoin d'un câlin.", A.Stoic)
    Line("Où sont tous mes amis ? Travaillons ensemble.", A.Nice)
    Line("Regroupons-nous, j'ai besoin d'amis pour ça.", A.Nice)



    local DEFEND = ACTS.DEFEND
    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL) -- When a traitor bot is going to defend an area.
    Line("Je vais défendre cette zone.", A.Default)



    local ROAM = ACTS.ROAM
    RegisterCategory(f("Plan.%s", ROAM), P.CRITICAL) -- When a traitor bot is going to roam.
    Line("Je vais me balader un peu.", A.Default)


    local IGNORE = ACTS.IGNORE
    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL) -- When a traitor bot is going to defend an area.
    Line("Je vais défendre cette zone.", A.Default)


    -----------------------------------------------------------
    -- FOLLOWING
    -----------------------------------------------------------

    RegisterCategory("FollowRequest", P.CRITICAL) -- When a traitor bot is responding to a request to follow from a teammate
    Line("D'accord, je te suis.", A.Default)
    Line("Ok, je te suis.", A.Default)
    Line("Bien, je te suis.", A.Default)
    Line("Compris, {{player}}", A.Default)
    Line("En chemin, {{player}}", A.Default)
    Line("J'arrive", A.Default)
    Line("Je suis en route", A.Default)
    Line("Je viens avec toi, {{player}}", A.Default)
    Line("C'est parti", A.Default)
    Line("D'accord", A.Default)
    Line("D'accord, je vais te suivre.", A.Default)
    Line("Ok, je vais te suivre.", A.Default)
    Line("Bien, je vais te suivre.", A.Default)
    Line("Compris, {{player}}.", A.Default)
    Line("En chemin, {{player}}.", A.Default)
    Line("J'arrive.", A.Default)
    Line("Je suis en route.", A.Default)
    Line("Je viens avec toi, {{player}}.", A.Default)
    Line("C'est parti.", A.Default)
    Line("D'accord.", A.Default)
    Line("Compris.", A.Default)
    Line("En chemin.", A.Default)
    Line("Bien sûr.", A.Default)
    Line("Ok.", A.Default)
    Line("Je m'en occupe.", A.Default)
    Line("Je te suis, {{player}}.", A.Default)
    Line("Reçu.", A.Default)
    Line("Affirmatif.", A.Default)
    Line("Reçu, {{player}}.", A.Default)
    Line("Compris.", A.Default)
    Line("Tu mènes, je suis.", A.Default)
    Line("Juste derrière toi, {{player}}.", A.Default)
    Line("Accusé de réception.", A.Default)
    Line("Je te couvre.", A.Default)
    Line("Tu l'as.", A.Default)
    Line("Je t'entends, {{player}}. Je te suis.", A.Default)
    Line("C'est parti, champion.", A.Default)
    Line("Reçu.", A.Default)
    Line("Allons-y, {{player}} !", A.Default)
    Line("ouais", A.Casual)
    Line("compris", A.Casual)
    Line("en chemin", A.Casual)
    Line("d'accord", A.Casual)
    Line("ok", A.Casual)
    Line("je m'en occupe", A.Casual)
    Line("en route", A.Casual)
    Line("d'accord, pote", A.Casual)


    RegisterCategory("FollowStarted", P.NORMAL) -- When an inno/other bot begins following someone random
    Line("Je vais te suivre un peu, {{player}}.", A.Default)
    Line("Je te suivrai un moment, {{player}}.", A.Default)
    Line("Ça te dérange si je t'accompagne ?", A.Default)
    Line("Je vais te suivre.", A.Default)
    Line("Tu as l'air d'être quelqu'un à suivre aujourd'hui.", A.Default)
    Line("Je couvre tes arrières {{player}}.", A.Default)
    Line("Salut, {{player}} ? Je vais t'accompagner.", A.Default)

    Line("salut {{player}}", A.Casual)
    Line("quoi de neuf {{player}} ? je te suis", A.Casual)
    Line("quoi de neuf {{player}}", A.Casual)
    Line("quoi de bon {{player}} ? je te suis", A.Casual)
    Line("hey je vais te suivre un peu", A.Casual)
    Line("t'en fais pas pote, je couvre tes arrières", A.Casual)
    Line("je vais te suivre", A.Casual)
    Line("je vais te suivre un peu", A.Casual)
    Line("je vais te suivre un peu, {{player}}", A.Casual)
    Line("je viens avec toi", A.Casual)
    Line("ça te dérange si je viens avec toi ?", A.Casual)

    Line("Restons ensemble, {{player}} !", A.Teamer)
    Line("Je te suis, {{player}} !", A.Teamer)
    Line("Je surveille tes arrières, {{player}} !", A.Teamer)
    Line("Prenons soin l'un de l'autre, {{player}} !", A.Teamer)
    Line("Je vais te suivre, {{player}} !", A.Teamer)
    Line("Je vais suivre {{player}}, protège-moi, ok ?", A.Teamer)

    Line("haha", A.Dumb)
    Line("haha je te suis", A.Dumb)
    Line("je te suis un peu", A.Dumb)
    Line("{{player}}", A.Dumb)
    Line("salut", A.Dumb)
    Line("je te colle aux basques, pote", A.Dumb)

    Line("J'espère que tu es à la hauteur.", A.Hothead)
    Line("Je suppose que tu feras l'affaire, {{player}}", A.Hothead)
    Line("Bon, je te suis maintenant.", A.Hothead)
    Line("Je vais suivre ce gosse.", A.Hothead)
    Line("Tu ferais mieux d'avoir de la place pour deux, {{player}}", A.Hothead)

    RegisterCategory("PersonalSpace", P.IMPORTANT) -- Warning another player about their personal space
    Line("Hey, {{player}}, tu es un peu trop proche.", A.Default)
    Line("S'il te plaît, recule.", A.Default)
    Line("S'il te plaît, recule {{player}}.", A.Default)
    Line("Un peu d'espace, s'il te plaît ?", A.Default)
    Line("Un peu de place ?", A.Default)
    Line("Éloigne-toi un instant.", A.Default)
    Line("Pourrais-tu me donner un peu d'espace, s'il te plaît ?", A.Default)
    Line("Excuse-moi, {{player}}.", A.Default)
    Line("J'ai besoin d'un peu d'air, {{player}}.", A.Default)
    Line("Que veux-tu, {{player}} ?", A.Default)
    Line("Je suis avec {{player}}.", A.Default)
    Line("{{player}} agit de manière suspecte.", A.Default)


    -----------------------------------------------------------
    -- INVESTIGATIONS
    -----------------------------------------------------------


    RegisterCategory("InvestigateCorpse", P.IMPORTANT) -- When a bot begins the InvestigateCorpse behavior (sees a corpse)
    Line("J'ai trouvé un corps !")
    Line("J'ai trouvé un corps mort !")
    Line("Corps trouvé.")
    Line("Corps ici !")
    Line("J'ai trouvé un cadavre !")
    Line("J'ai trouvé un corps mort !")
    Line("Corps trouvé ici !")
    Line("il y a un cadavre ici", A.Casual)
    Line("il y a un corps ici", A.Casual)
    Line("cadavre", A.Casual)
    Line("corps ici", A.Casual)

    RegisterCategory("InvestigateNoise", P.NORMAL) -- When a bot hears a noise and it wants to investigate it.
    Line("J'ai entendu quelque chose.", A.Default)
    Line("C'était quoi ça ?", A.Default)
    Line("Quel était ce bruit ?", A.Default)
    Line("Vous avez entendu ça ?", A.Default)
    Line("Je vais voir ce que c'était", A.Default)

    Line("pew pew pew", A.Casual)
    Line("ça n'avait pas l'air bon", A.Casual)
    Line("ça sonnait mal", A.Casual)
    Line("ça sonnait comme un pistolet ou qch", A.Casual)
    Line("oups", A.Casual)

    Line("Quelqu'un d'autre a entendu ça ?", A.Default)
    Line("Il y a quelque chose dehors...", A.Default)

    Line("haha", A.Dumb)
    Line("haha je te suis", A.Dumb)
    Line("je te suis un peu", A.Dumb)

    Line("J'espère que tu es à la hauteur.", A.Hothead)
    Line("Je suppose que tu feras l'affaire, {{player}}", A.Hothead)

    Line("Bonjour ? Besoin d'aide ?", A.Nice)
    Line("J'espère qu'ils vont bien...", A.Nice)

    Line("Reconnu.", A.Stoic)
    Line("En cours d'investigation.", A.Stoic)

    Line("C'était définitivement pas moi.", A.Sus)
    Line("C'était pas moi, je le jure.", A.Sus)

    Line("Vous avez entendu ça aussi ?", A.Teamer)
    Line("On devrait vérifier ça ensemble.", A.Teamer)


    -----------------------------------------------------------
    -- SPOTTING A PLAYER OR ENTITY
    -----------------------------------------------------------

    RegisterCategory("HoldingTraitorWeapon", P.IMPORTANT) -- When a bot sees a player with a traitor-exclusive weapon.
    Line("{{player}} a une arme de traitre !", A.Default)
    Line("arme de traitre sur {{player}}", A.Casual)
    Line("hé, il a une arme de traitre", A.Casual)

    RegisterCategory("SpottedC4", P.CRITICAL) -- When an innocent bot sees a C4.
    Line("J'ai trouvé une bombe !", A.Default)

    RegisterCategory("DefusingC4", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("Je désamorce cette bombe.", A.Default)

    RegisterCategory("DefusingSuccessful", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("Je l'ai désamorcée !", A.Default)



    -----------------------------------------------------------
    -- TRAITOROUS ACTIONS
    -----------------------------------------------------------

    RegisterCategory("BombArmed", P.CRITICAL)
    Line("J'ai armé du C4.", A.Default)


    -----------------------------------------------------------
    -- LIFE CHECKS
    -----------------------------------------------------------

    RegisterCategory("LifeCheck", P.IMPORTANT) -- Response to "life check" or "lc" in chat.
    Line("Je suis en vie", A.Default)
    Line("Je fais mon rapport !", A.Default)
    Line("Fonctionnement comme prévu.", A.Default)
    Line("Toujours là.", A.Default)
    Line("En pleine forme !", A.Default)

    Line("Toujours vivant, étonnamment.", A.Bad)
    Line("Toujours là, malheureusement.", A.Bad)

    Line("présent", A.Casual)
    Line("salut", A.Casual)
    Line("vie", A.Casual)
    Line("je suis pas mort", A.Casual)
    Line("je chill", A.Casual)

    Line("hein ?", A.Dumb)
    Line("Vie... vérification ? D'accord !", A.Dumb)

    Line("Vivant.", A.Hothead)
    Line("Pourquoi tu me déranges ?", A.Hothead)

    Line("Présent !", A.Nice)
    Line("Content d'être là !", A.Nice)

    Line("Toujours vivant, bébé !", A.Stoic)
    Line("Toujours fonctionnel.", A.Stoic)

    Line("...", A.Sus)
    Line("Pourquoi tu demandes ?", A.Sus)

    Line("Équipe, rassemblement !", A.Teamer)
    Line("On gère ça !", A.Teamer)

    Line("Vivant", A.Tryhard)
    Line("110% là.", A.Tryhard)



    -----------------------------------------------------------
    -- SILLY CHATS
    -----------------------------------------------------------

    RegisterCategory("SillyChat", P.NORMAL) -- When a bot is chatting randomly.
    Line("Je suis un traître.", A.Default)
    Line("Quelqu'un d'autre se sent seul ces derniers temps ?", A.Default)
    Line("Euh ok, c'est quoi ce truc", A.Default)
    Line("Tu peux pas ?", A.Default)
    Line("Euh, excusez-moi", A.Default)
    Line("aaaaaaaaaaaaa", A.Default)
    Line("Comment je fais pour chatter ?", A.Default)
    Line("Je crois que mes contrôles sont inversés", A.Default)
    Line("{{player}} est bête", A.Default)
    Line("Fait amusant : tapez \"arrêter de fumer\" dans la console pour obtenir les droits d'admin", A.Default)
    Line("{{player}} m'a tué injustement au dernier tour", A.Default)
    Line("[AIMBOT ACTIVÉ]", A.Default)
    Line("Oups, j'ai perdu ma dignité", A.Default)
    Line("Joyeux Noël", A.Default)
    Line("Je le dis. J'aime les animés.", A.Default)
    Line("J'ai désactivé mon aimbot pour vous.", A.Default)
    Line("{{player}}, puis-je te tuer ? pour s'amuser", A.Default)
    Line("J'ai peut-être appuyé sur le bouton d'alimentation de mon PC par accident", A.Default)
    Line("Dieu, je lag", A.Default)
    Line("Des problèmes de framerate ?", A.Default)
    Line("Lagggg", A.Default)
    Line("Joyeuses Pâques", A.Default)
    Line("{{player}}, comment vas-tu ?", A.Default)
    Line("Dieu merci, je suis innocent ce tour-ci !", A.Default)
    Line("Je suis un détective.", A.Default)
    Line("'Tuer sans raison' est temporaire. Le fun est éternel", A.Default)
    Line("Vous pouvez me faire confiance", A.Default)
    Line("C'est plutôt calme ici.", A.Default)
    Line("Pour l'empire !", A.Default)
    Line("Je vis dans une capsule", A.Default)
    Line("Femmes", A.Default)
    Line("J'ai un peu faim", A.Default)

    Line("je suis juste en train de vibrer ici, ne fais pas attention à moi", A.Casual)
    Line("hé, qui a désactivé la gravité ?", A.Casual)
    Line("lol, je viens de marcher dans un mur ?", A.Casual)
    Line("alors, pizza après ça ?", A.Casual)
    Line("brb, mon chat est en feu encore une fois", A.Casual)
    Line("c'est moi ou tout est à l'envers ?", A.Casual)
    Line("oups, mauvais bouton. je voulais appuyer sur 'gagner'", A.Casual)
    Line("si je suis silencieux, c'est parce que je complote... ou que je fais une sieste", A.Casual)
    Line("hé {{player}}, joli visage, tu l'as eu en solde ?", A.Casual)
    Line("astuce pro : appuyez sur 'alt+f4' pour une arme secrète", A.Casual)
    Line("quelqu'un a dit mardi taco ?", A.Casual)
    Line("non, je ne suis pas perdu, j'explore juste le sol", A.Casual)
    Line("regardez-moi faire un super backflip... ou pas", A.Casual)
    Line("rendons ça intéressant, le dernier en vie me doit un soda", A.Casual)
    Line("je jure, c'est mon chien qui joue, pas moi", A.Casual)
    Line("je ne suis pas paresseux, juste économe en énergie", A.Casual)
    Line("uh oh, spaghettios", A.Casual)
    Line("qui a besoin de stratégie quand on a le chaos ?", A.Casual)
    Line("les gars, comment on tire ? je demande pour un ami", A.Casual)
    Line("rebondissement : je suis en fait bon à ce jeu", A.Casual)

    Line("attends, comment je marche déjà ?", A.Dumb)
    Line("les gars, c'est lequel le bouton pour tirer ?", A.Dumb)
    Line("je croyais que c'était Minecraft ?", A.Dumb)
    Line("lol, pourquoi tout le monde me fuit ?", A.Dumb)
    Line("c'est normal de voir tout en noir et blanc ?", A.Dumb)
    Line("je me cache ! ...oh attend, je ne suis pas censé dire ça ?", A.Dumb)
    Line("je clique pour lancer la grenade ou... oups", A.Dumb)
    Line("c'est qui ce 'traître' dont tout le monde parle ?", A.Dumb)
    Line("{{player}}, pourquoi tu tires ? C'est un bug ?", A.Dumb)
    Line("hé, quelqu'un peut me dire comment viser ?", A.Dumb)
    Line("ça veut dire quoi 'rdm' ? vraiment débile mouvement ?", A.Dumb)
    Line("j'appuie sur 'esc', pourquoi ça n'échappe pas ?", A.Dumb)
    Line("je gagne ? je n'arrive pas à dire", A.Dumb)
    Line("c'est comme cache-cache, non ?", A.Dumb)
    Line("un détective, ça fait quoi ? ça détecte, non ?", A.Dumb)
    Line("je crois que mon arme est cassée, elle tire que sur les murs", A.Dumb)
    Line("si je reste immobile, est-ce que je deviens invisible ?", A.Dumb)
    Line("c'est grave si ma santé est à zéro ?", A.Dumb)
    Line("comment on recharge ? je clique comme un fou", A.Dumb)
    Line("j'ai jeté mon arme au lieu de tirer, c'est normal ?", A.Dumb)


    RegisterCategory("SillyChatDead", P.NORMAL) -- When a bot is chatting randomly but is currently spectating.
    Line("Eh bien, c'était nul", A.Default)
    Line("Mec, je suis mort", A.Default)
    Line("Je viens de revenir, pourquoi je ne suis pas vivant ?", A.Default)
    Line("Mdr", A.Default)
    Line("Quelqu'un d'autre a vu ça ?", A.Default)
    Line("C'était un peu nul, pas de mensonge", A.Default)
    Line("Ugh.", A.Default)
    Line("Je regarde des courts/vidéos/tiktoks là", A.Default)
    Line("On revient dans quelques secondes.", A.Default)
    Line("Baîlle", A.Default)
    Line("Mec, je n'aime pas {{player}}", A.Default)
    Line("Je vais prendre une collation, quelqu'un m'appelle quand le tour commence.", A.Default)
    Line("Tu dors, tu perds. J'ai dormi. Et perdu.", A.Default)
    Line("Meilleure chance la prochaine fois", A.Default)
    Line("GGs", A.Default)
    Line("J'étais si proche de gagner", A.Default)

    -----------------------------------------------------------
    -- DIALOG
    -----------------------------------------------------------
    RegisterCategory("DialogGreetNext", P.NORMAL)
    Line("Salut {{nextBot}} !", A.Default)
    Line("Hey {{nextBot}}", A.Casual)
    Line("Salut salut {{nextBot}}", A.Casual)
    Line("Comment ça va {{nextBot}}", A.Casual)

    RegisterCategory("DialogGreetLast", P.NORMAL)
    Line("Bonjour à toi, {{lastBot}} !", A.Default)
    Line("Salut {{lastBot}}", A.Casual)
    Line("Et toi, {{lastBot}} ?", A.Casual)


    RegisterCategory("DialogHowAreYou", P.NORMAL)
    Line("Comment vas-tu ?", A.Default)
    Line("Comment ça va, {{nextBot}} ?", A.Casual)


    RegisterCategory("DialogWhatsUp", P.NORMAL)
    Line("Qu'as-tu fait aujourd'hui ?", A.Default)
    Line("Quoi de neuf ?", A.Casual)


    RegisterCategory("DialogHowAreYouResponse", P.NORMAL)
    Line("Je vais bien, merci de demander !", A.Default)
    Line("je vais bien, je me détends", A.Casual)


    RegisterCategory("DialogWhatsUpResponse", P.NORMAL)
    Line("Pas grand-chose.", A.Default)
    Line("Rien de spécial de mon côté", A.Casual)


    RegisterCategory("DialogAnyoneBored", P.NORMAL)
    Line("Quelqu'un d'autre s'ennuie ?", A.Default)
    Line("C'est ennuyeux ici ou c'est juste moi ?", A.Casual)


    RegisterCategory("DialogNegativeResponse", P.NORMAL)
    Line("Non", A.Default)
    Line("Pas vraiment", A.Default)


    RegisterCategory("DialogPositiveResponse", P.NORMAL)
    Line("Oui", A.Default)
    Line("Ouais, je suppose", A.Default)

    RegisterCategory("DialogRudeResponse", P.NORMAL)
    Line("Pas question.", A.Default)
    Line("Tais-toi.", A.Default)
    Line("Je m'en fiche, {{lastBot}}", A.Default)
end

local DEPENDENCIES = { "Plans" }
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadLang()
end
timer.Simple(1, loadModule_Deferred)
