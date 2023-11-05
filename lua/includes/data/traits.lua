--- This is a table used mostly for chatter and flavor text. It is not used for any gameplay purposes.
TTTBots.Archetypes = {
    Tryhard = "Tryhard/nerd", --- Says nerdy/tryhard things often
    Hothead = "Hothead",      --- Quick to anger in his communication
    Stoic = "Stoic",          --- Rarely complains/gloats
    Dumb = "Dumb",            --- huh?
    Nice = "Nice",            --- Says nice things often, loves to compliment.
    Bad = "Bad",              --- just bad
    Teamer = "Teamer",        --- loves to say "us" instead of "me"
    Sus = "Sus/Quirky",       --- "guys im the traitor" ... that kind of thing
    Casual = "Casual",        --- loves to make jokes, talks in lowercase most of the time
    Default = "default",      --- default archetype; used as a fallback
}
local A = TTTBots.Archetypes

TTTBots.Traits = {
    --- Quick to attack (innocent) and ignores evaluation of danger when picking a target (traitor)
    aggressive = {
        name = "aggressive",
        description =
        "[HE] often picks targets hastily, regardless of being right or wrong, and pays no mind to witnesses",
        conflicts = { "passive", "cautious" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            suspicion = 3,        -- high suspicion gain to encourage attacking
            investigateNoise = 2, -- more likely to seek out noise
            aggression = 2,       -- More aggressive as traitor
            rageRate = 1.5,       -- Rage faster
            ignoreOrders = true,  -- Ignore evil coordinator orders
            difficulty = 2,       -- how many points of difficulty this trait is worth
        }
    },
    --- Prefers to avoid fights and run away instead
    passive = {
        name = "passive",
        description = "When not a traitor, [HE] avoids fights and runs away instead",
        conflicts = { "aggressive", "rdmer" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            investigateNoise = 0, -- never seek out noise
            aggression = 0.8,     -- Less aggressive as traitor
            rageRate = 0.5,       -- Rage slower
            difficulty = -1,
            hider = true
        }
    },
    --- Places C4 a lot
    bomber = {
        name = "bomber",
        description = "Using C4 or a jihad bomb (if modded), [HE] enjoys blowing things up",
        conflicts = {},
        traitor_only = true,
        effects = {}
    },
    --- Sus actions give self +50% suspicion
    suspicious = {
        name = "suspicious",
        description = "Players tend to mistrust [HIM] and are quick to assume [HE] is a traitor",
        conflicts = { "gullible" },
        traitor_only = false,
        archetype = A.Sus,
        effects = {
            suspicion = 1.5,
            suspicionMe = 1.5, -- make others build suspicion on us faster
            investigateCorpse = 0,
        }
    },
    --- Aim tends to be terrible, especially when under pressure.
    badaim = {
        name = "badaim",
        description = "Under pressure, [HE] struggles with aiming accuracy",
        conflicts = { "goodaim" },
        traitor_only = false,
        archetype = A.Bad,
        effects = {
            pressureRate = 2.5,
            inaccuracy = 2,
            difficulty = -2,
        }
    },
    --- The simplest trait: has better aim than the average player, regardless of pressure
    goodaim = {
        name = "goodaim",
        description = "[HE] has better aim than the average player",
        conflicts = { "badaim" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            pressureRate = 0.1,
            difficulty = 3,
        }
    },
    --- Not paying full attention; bad hearing, memory, and target acquisition.
    oblivious = {
        name = "oblivious",
        description = "Occasionally, [HE] overlooks bodies and traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
        archetype = A.Dumb,
        effects = {
            hearing = 0.75,
            suspicion = 0.75,
            investigateNoise = 0.5, -- rarely seek out noise
            ignoreOrders = true,    -- Ignore evil coordinator orders
            boredomRate = 1.25,     -- Boredom builds up faster
            difficulty = -2,
            investigateCorpse = 0.5,
        }
    },
    --- Significantly brain damaged. Not good at hearing, memory, or target acquisition.
    veryoblivious = {
        name = "veryoblivious",
        description = "Unless a detective, [HE] seldom searches bodies or notices traitor weapons",
        conflicts = { "observant", "veryobservant" },
        traitor_only = false,
        archetype = A.Dumb,
        effects = {
            hearing = 0.5,
            suspicion = 0.5,
            investigateNoise = 0.2, -- very rarely seek out noise
            ignoreOrders = true,    -- Ignore evil coordinator orders
            boredomRate = 1.5,      -- Boredom builds up faster
            difficulty = -4,
            investigateCorpse = 0.2,
            hider = true
        }
    },
    -- Good hearing, memory, and target acquisition than the average player.
    observant = {
        name = "observant",
        description = "Spotting bodies and traitor weapons comes easily to [HIM]",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.25,
            investigateNoise = 1.5, -- more likely to seek out noise
            difficulty = 2,
            investigateCorpse = 1.5,
        }
    },
    --- Significantly better hearing, memory, and is more likely to attack the right person.
    veryobservant = {
        name = "veryobservant",
        description = "[HE] instantly detects bodies and traitor weapons in the vicinity",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.5,
            investigateNoise = 2, -- more likely to seek out noise
            difficulty = 3,
            investigateCorpse = 2,
            sniper = true,
        }
    },
    --- Tends to wander to the least popular nav areas, but can still wander elsewhere
    loner = {
        name = "loner",
        description = "[HE] prefers to steer clear of crowds",
        conflicts = { "lovescrowds", "teamplayer" },
        traitor_only = false,
        archetype = A.Sus,
        effects = {
            hearing = 1.15,
            suspicion = 1.25,
            aggression = 0.8,
            ignoreOrders = true, -- Ignore evil coordinator orders
            difficulty = 1,
        }
    },
    --- Tends to wander into popular nav areas, but can still wander elsewhere
    lovescrowds = {
        name = "lovescrowds",
        description = "Crowded spaces attract [HIM]",
        conflicts = { "loner" },
        traitor_only = false,
        archetype = A.Teamer,
        effects = {
            hearing = 0.8,
            difficulty = 1,
        }
    },
    --- As traitor, follows his traitors around to coordinate attacks with them better.
    teamplayer = {
        name = "teamplayer",
        description = "Helping teammates is a priority for [HIM]",
        conflicts = { "loner", "rdmer" },
        traitor_only = true,
        archetype = A.Teamer,
        effects = {
            aggression = 1.4, -- More likely to take on more targets as traitor
        }
    },
    --- Follows players around. Prefers detectives/trusted players.
    follower = {
        name = "follower",
        description = "[HE] follows players around",
        conflicts = { "loner", "rdmer" },
        traitor_only = false,
        archetype = A.Teamer,
        effects = {}
    },
    --- Attacks random person regardless of team. THIS SHOULD BE DISABLED BY DEFAULT!
    rdmer = {
        name = "rdmer",
        description = "[HE] kills people at random",
        conflicts = { "passive", "teamplayer" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            boredomRate = 2.0, -- Boredom builds up faster
        }
    },
    --- Makes traitors 3x as likely to attack him at random
    victim = {
        name = "victim",
        description = "Other bots are more likely to target [HIM]",
        conflicts = { "lucky" },
        traitor_only = false,
        effects = {
            victim = 3,
            rageRate = 1.25, -- Rage faster
            difficulty = -1,
            investigateCorpse = 0.8,
        }
    },
    --- Traitors are much less likely to target him randomly.
    lucky = {
        name = "lucky",
        description = "Other bots are less likely to target [HIM]",
        conflicts = { "victim" },
        traitor_only = false,
        effects = {
            victim = 0.3,
            difficulty = 1,
        }
    },
    --- Prefers to use long range single-shot guns, wanders between open nav spots
    sniper = {
        name = "sniper",
        description = "Adept with a sniper rifle",
        conflicts = { "meleer" },
        traitor_only = false,
        effects = {
            ignoreOrders = true,
            investigateCorpse = 0.4, -- less likely to investigate corpses, we're too busy sniping
            sniper = true,
        }
    },
    --- Pulls out crowbar and kills people the old fashioned way. Modifies attack behavior
    meleer = {
        name = "meleer",
        description = "Prefers crowbars at further ranges than normal.",
        conflicts = { "sniper" },
        traitor_only = false,
        archetype = A.Casual,
        effects = {
            meleeRange = 2,
        }
    },
    --- Uses the knife to kill when alone with someone
    assassin = {
        name = "assassin",
        description = "Prefers to use knives when traitor.",
        conflicts = {},
        traitor_only = false,
        effects = {
            ignoreOrders = true,
            useKnives = true,
        }
    },
    --- Uses the flare gun to burn corpses he leaves
    bodyburner = {
        name = "bodyburner",
        description = "Burning bodies is one of [HIS] tactics",
        conflicts = {},
        traitor_only = false,
        effects = {
            bodyBurner = true,
        }
    },
    --- Prefers wander around a randomly selected player, typically a detective.
    bodyguard = {
        name = "bodyguard",
        description = "[HE] selects a random player to protect",
        conflicts = { "loner" },
        traitor_only = false,
        effects = {
            hearing = 1.1,
        }
    },
    --- Instead of wandering randomly, hunkers in a random hidden spot (ONLY WHEN NOT EVIL)
    camper = {
        name = "camper",
        description = "As an innocent, [HE] chooses an area to hunker down in",
        conflicts = { "risktaker" },
        traitor_only = false,
        effects = {
            hider = true,
            difficulty = -1,
            sniper = true,
        }
    },
    --- Uses chat more frequently, especially when traitor
    talkative = {
        name = "talkative",
        description = "[HE] communicates more frequently",
        conflicts = { "silent" },
        traitor_only = false,
        effects = {
            textchat = 2.0,
            difficulty = 1,
        }
    },
    --- Does not use any chat whatsoever
    silent = {
        name = "silent",
        description = "[HE] keeps communication to a minimum",
        conflicts = { "talkative" },
        traitor_only = false,
        effects = {
            textchat = 0.0,
            difficulty = -2,
        }
    },
    --- Roams into high-stress areas and walks towards gunshots for fun.
    risktaker = {
        name = "risktaker",
        description = "[HE] ventures into dangerous areas for the thrill",
        conflicts = { "cautious", "camper" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            investigateNoise = 5, -- 5x more likely to investigate noises
            aggression = 1.5,
            ignoreOrders = true,  -- Ignore evil coordinator orders
            difficulty = 2,
            investigateCorpse = 0.65, -- too busy gaming to investigate corpses
        }
    },
    --- 1.5x suspicion gain, is more observant
    cautious = {
        name = "cautious",
        description = "[HE] is aware of [HIS] surroundings and is less trusting",
        conflicts = { "risktaker" },
        traitor_only = false,
        effects = {
            hearing = 1.2,
            suspicion = 1.5,
            aggression = 0.8,
            difficulty = 1,
            investigateCorpse = 2,
        }
    },
    --- Suspicion gain is halved
    gullible = {
        name = "gullible",
        description = "[HE] tends to believe others easily, doesn't care about suspicion that much",
        conflicts = { "suspicious" },
        traitor_only = false,
        archetype = A.Dumb,
        effects = {
            suspicion = 0.5,
            difficulty = -3,
            investigateCorpse = 0.5,
        }
    },
    --- Doesn't pay attention to many noises, doesn't react quickly, much worse memory of events and people
    --- More likely to make weird or otherwise suspicious actions (but doesn't gain bonus suspicion)
    doesntcare = {
        name = "doesntcare",
        description = "Apathetic, [HE] can be unresponsive at times",
        conflicts = { "talkative", "teamplayer", "cautious" },
        traitor_only = false,
        archetype = A.Dumb,
        effects = {
            hearing = 0.3,
            suspicion = 0.5,
            aggression = 2,
            ignoreOrders = true, -- Ignore evil coordinator orders
            boredomRate = 2.0,   -- Boredom builds up faster
            rageRate = 0.4,      -- Rage slower
            pressureRate = 0.2,  -- Pressure builds up slower
            difficulty = -6,
            investigateCorpse = 0,
        }
    },
    --- Can use the disguiser
    disguiser = {
        name = "disguiser",
        description = "As a traitor, [HE] loves [HIS] disguiser",
        conflicts = {},
        archetype = A.Tryhard,
        traitor_only = true,
        effects = {
            disguiser = true,
        }
    },
    --- Can play sounds on radio
    radiohead = {
        name = "radiohead",
        description = "As a traitor, [HE] loves [HIS] radio",
        conflicts = { "deaf" },
        traitor_only = true,
        effects = {
            radio = true,
        }
    },
    --- Cannot hear sounds
    deaf = {
        name = "deaf",
        description = "[HE] cannot hear",
        conflicts = { "radiohead", "lowvolume", "highvolume" },
        traitor_only = false,
        effects = {
            hearing = 0,
            pressureRate = 0.75,
            difficulty = -4
        }
    },
    --- Worse sound detection range
    lowvolume = {
        name = "lowvolume",
        description = "[HE] cannot hear too well or has [HIS] volume lowered",
        conflicts = { "deaf", "highvolume" },
        traitor_only = false,
        archetype = A.Casual,
        effects = {
            hearing = 0.8,
            difficulty = -2
        }
    },
    --- Better sound detection range
    highvolume = {
        name = "highvolume",
        description = "[HE] can hear very well or has [HIS] volume raised",
        conflicts = { "deaf", "lowvolume" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.25,
            difficulty = 2
        }
    },
    --- Double rage rate
    rager = {
        name = "rager",
        description = "[HE] gets angry easily",
        conflicts = { "pacifist" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            rageRate = 2.0,
        }
    },
    --- Half rage rate
    pacifist = {
        name = "pacifist",
        description = "[HE] is a pacifist",
        conflicts = { "rager" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            rageRate = 0.5,
            investigateCorpse = 0.8,
        }
    },
    --- Doesn't feel pressure when aiming
    steady = {
        name = "steady",
        description = "[HE] is steady when aiming",
        conflicts = { "shaky" },
        traitor_only = false,
        effects = {
            pressureRate = 0.1,
            difficulty = 3
        }
    },
    --- Feels 3x pressure when aiming
    shaky = {
        name = "shaky",
        description = "[HE] is shaky when aiming",
        conflicts = { "steady" },
        traitor_only = false,
        effects = {
            pressureRate = 3.0,
            difficulty = -3
        }
    },
    --- 2.5x higher boredom rate, 1.5x higher rage rate
    bemused = {
        name = "bemused",
        description = "[HE] is easily bored and angered",
        conflicts = { "easilyamused" },
        traitor_only = false,
        archetype = A.HotHead,
        effects = {
            boredomRate = 2.5,
            rageRate = 1.5,
        }
    },
    --- 0.3x boredom rate, 0.5x rage rate
    easilyamused = {
        name = "easilyamused",
        description = "[HE] is rarely bored or angered",
        conflicts = { "bemused" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            boredomRate = 0.3,
            rageRate = 0.5,
        }
    },
    --- Never gets angry, bored, or feels pressure. Stoic.
    verystoic = {
        name = "verystoic",
        description = "[HE] is very stoic",
        conflicts = { "bemused", "easilyamused", "rager", "pacifist" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            boredomRate = 0.0,
            rageRate = 0.0,
            pressureRate = 0.0,
            difficulty = 2
        }
    },
}
