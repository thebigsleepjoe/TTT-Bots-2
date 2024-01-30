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
    aggressive = {
        name = "aggressive",
        description =
        "Very quick to pick targets, build sus, and get upset. Will actively seek out noises, and will follow people around.",
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
            follower = true,      -- likes to follow players
        }
    },
    passive = {
        name = "passive",
        description =
        "Likes to hide in cramped spaces when possible. Does not seek out danger as often, and is less upset by the game.",
        conflicts = { "aggressive", "rdmer" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            investigateNoise = 0, -- never seek out noise
            aggression = 0.8,     -- Less aggressive as traitor
            rageRate = 0.5,       -- Rage slower
            difficulty = -1,
            hider = true,
            focus = 0.9, -- the gain/loss rate of focus when attacking
        }
    },
    bomber = {
        name = "bomber",
        description = "Much more likely to plant or defuse C4.",
        conflicts = {},
        traitor_only = false,
        effects = {
            planter = true,
            defuser = true,
        }
    },
    suspicious = {
        name = "suspicious",
        description = "Bots will build suspicion on this bot far quicker, due to its traitor-like behaviors.",
        conflicts = { "gullible" },
        traitor_only = false,
        archetype = A.Sus,
        effects = {
            suspicion = 1.5,
            suspicionMe = 1.5, -- make others build suspicion on us faster
            investigateCorpse = 0,
            follower = true,   -- likes to follow players
        }
    },
    badaim = {
        name = "badaim",
        description = "Is hugely affected by pressure, often missing shots when they are most needed",
        conflicts = { "goodaim" },
        traitor_only = false,
        archetype = A.Bad,
        effects = {
            pressureRate = 2.5,
            inaccuracy = 2,
            difficulty = -4,
            focus = 0.5, -- the gain/loss rate of focus when attacking
        }
    },
    goodaim = {
        name = "goodaim",
        description = "Is largely unaffected by pressure, making for more accurate shots",
        conflicts = { "badaim" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            pressureRate = 0.1,
            difficulty = 3,
            focus = 1.5, -- the gain/loss rate of focus when attacking
        }
    },
    oblivious = {
        name = "oblivious",
        description = "Seems distracted a lot of the time; poorer hearing, less likely to investigate noises, etc.",
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
            focus = 0.8, -- the gain/loss rate of focus when attacking
            hider = true,
        }
    },
    veryoblivious = {
        name = "veryoblivious",
        description =
        "Barely paying attention to the game: poor hearing, often ignores bodies, doesn't investigate noises, etc.",
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
            hider = true,
            follower = true, -- likes to follow players
            focus = 0.5,     -- the gain/loss rate of focus when attacking
        }
    },
    -- Good hearing, memory, and target acquisition than the average player.
    observant = {
        name = "observant",
        description = "Possesses much better hearing and is more likely to seek out suspicious noises.",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.25,
            investigateNoise = 1.5, -- more likely to seek out noise
            difficulty = 2,
            investigateCorpse = 1.5,
            focus = 1.2,
        }
    },
    veryobservant = {
        name = "veryobservant",
        description = "Possesses extremely keen senses and is quick to notice corpses.",
        conflicts = { "oblivious", "veryoblivious" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.5,
            suspicion = 1.5,
            investigateNoise = 2, -- more likely to seek out noise
            difficulty = 4,
            investigateCorpse = 2,
            sniper = true,
            focus = 1.5,
        }
    },
    loner = {
        name = "loner",
        description =
        "Will actively seek out areas that players typically avoid. Avoids targeting large groups of people and is quicker to build sus.",
        conflicts = { "lovescrowds", "teamplayer" },
        traitor_only = false,
        archetype = A.Sus,
        effects = {
            suspicion = 1.25,
            aggression = 0.8,
            ignoreOrders = true, -- Ignore evil coordinator orders
            difficulty = 1,
            loner = true,        -- prefer unpopular nav areas
        }
    },
    lovescrowds = {
        name = "lovescrowds",
        description = "More likely to wander into areas frequented by players.",
        conflicts = { "loner" },
        traitor_only = false,
        archetype = A.Teamer,
        effects = {
            difficulty = 2,
            lovesCrowds = true, -- prefer popular nav areas
        }
    },
    bold = {
        name = "bold",
        description = "More likely to take on more enemies when traitor",
        conflicts = { "loner", "rdmer" },
        traitor_only = true,
        archetype = A.Teamer,
        effects = {
            aggression = 1.4, -- More likely to take on more targets as traitor
        }
    },
    follower = {
        name = "follower",
        description = "Likes to follow players around instead of wandering.",
        conflicts = { "loner", "rdmer" },
        traitor_only = false,
        archetype = A.Teamer,
        effects = {
            follower = true,
        }
    },
    rdmer = {
        name = "rdmer",
        description = "If RDM is enabled, this bot will more often kill randomly as non-traitor.",
        conflicts = { "passive", "teamplayer" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            boredomRate = 2.0, -- Boredom builds up faster
            rdmer = true,
            follower = true,   -- likes to follow players
        }
    },
    victim = {
        name = "victim",
        description = "More likely to be randomly targeted by traitor bots",
        conflicts = { "lucky" },
        traitor_only = false,
        effects = {
            victim = 3,
            rageRate = 1.25, -- Rage faster
            difficulty = -1,
            investigateCorpse = 0.8,
        }
    },
    lucky = {
        name = "lucky",
        description = "Less likely to be randomly targeted by traitor bots.",
        conflicts = { "victim" },
        traitor_only = false,
        effects = {
            victim = 0.3,
            difficulty = 1,
        }
    },
    sniper = {
        name = "sniper",
        description = "Likes to sit around in wide-open areas.",
        conflicts = { "meleer" },
        traitor_only = false,
        effects = {
            ignoreOrders = true,
            investigateCorpse = 0.4, -- less likely to investigate corpses, we're too busy sniping
            sniper = true,
            focus = 2.0,             -- the gain/loss rate of focus when attacking
        }
    },
    assassin = { -- TODO: Implement this featuer.
        name = "assassin",
        description = "Likes to use knives when traitor. Unimplemented",
        conflicts = {},
        traitor_only = false,
        effects = {
            ignoreOrders = true,
            useKnives = true,
        }
    },
    bodyburner = { -- TODO: Implement this feature.
        name = "bodyburner",
        description = "Utilizes the flare gun to burn bodies as a traitor. Unimplemented",
        conflicts = {},
        traitor_only = false,
        effects = {
            bodyBurner = true,
        }
    },
    bodyguard = {
        name = "bodyguard",
        description = "Instead of wandering, this bot will almost always follow a random player around.",
        conflicts = { "loner" },
        traitor_only = false,
        effects = {
            hearing = 1.1,
            followerAlways = true, -- always wants to follow someone
            follower = true,       -- likes to follow players
        }
    },
    camper = {
        name = "camper",
        description = "Often will hunker down in a hiding spot or secure corner for a while.",
        conflicts = { "risktaker" },
        traitor_only = false,
        effects = {
            hider = true,
            planter = true,
            difficulty = -2,
            sniper = true,
        }
    },
    talkative = {
        name = "talkative",
        description = "Twice as likely to put a message in chat versus a baseline bot.",
        conflicts = { "silent" },
        traitor_only = false,
        effects = {
            textchat = 2.0,
            difficulty = 1,
        }
    },
    silent = {
        name = "silent",
        description = "Does not communicate under almost any circumstance.",
        conflicts = { "talkative" },
        traitor_only = false,
        effects = {
            textchat = 0.0,
            difficulty = -3,
        }
    },
    risktaker = {
        name = "risktaker",
        description = "Almost always investigates noises. Typically too busy to investigate corpses.",
        conflicts = { "cautious", "camper" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            investigateNoise = 5,     -- 5x more likely to investigate noises
            difficulty = 1,
            investigateCorpse = 0.65, -- too busy gaming to investigate corpses
        }
    },
    cautious = {
        name = "cautious",
        description =
        "Builds suspicion far quicker on players, can hear noises within a larger radius, and will almost always investigate bodies.",
        conflicts = { "risktaker" },
        traitor_only = false,
        effects = {
            hearing = 1.2,
            suspicion = 1.5,
            difficulty = 3,
            investigateCorpse = 2,
        }
    },
    gullible = {
        name = "gullible",
        description =
        "Builds less suspicion on players for doing obviously suspicious things. Not as quick to investigate bodies.",
        conflicts = { "suspicious" },
        traitor_only = false,
        archetype = A.Dumb,
        effects = {
            suspicion = 0.5,
            difficulty = -4,
            investigateCorpse = 0.5,
        }
    },
    doesntcare = {
        name = "doesntcare",
        description =
        "Doesn't give a damn about anything. Generally oblivious, doesn't coordinate, and doesn't investigate. Among other things.",
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
            difficulty = -8,
            investigateCorpse = 0,
            follower = true, -- likes to follow players
        }
    },
    disguiser = { -- TODO: Implement this feature.
        name = "disguiser",
        description = "Purchases a disguiser on T-rounds. Unimplemented",
        conflicts = {},
        archetype = A.Tryhard,
        traitor_only = true,
        effects = {
            disguiser = true,
        }
    },
    radiohead = { -- TODO: Implement this feature.
        name = "radiohead",
        description = "As traitor, will utilize radios to distract innocent players. Unimplemented",
        conflicts = { "deaf" },
        traitor_only = true,
        effects = {
            radio = true,
        }
    },
    deaf = {
        name = "deaf",
        description = "Audio is disabled; cannot hear anything.",
        conflicts = { "radiohead", "lowvolume", "highvolume" },
        traitor_only = false,
        effects = {
            hearing = 0,
            pressureRate = 0.75,
            difficulty = -5
        }
    },
    lowvolume = {
        name = "lowvolume",
        description = "Cannot pinpoint noises as well as other bots can.",
        conflicts = { "deaf", "highvolume" },
        traitor_only = false,
        archetype = A.Casual,
        effects = {
            hearing = 0.8,
            difficulty = -2
        }
    },
    highvolume = {
        name = "highvolume",
        description = "Can pinpoint noises within a larger radius.",
        conflicts = { "deaf", "lowvolume" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            hearing = 1.25,
            difficulty = 2
        }
    },
    rager = {
        name = "rager",
        description = "Doubles rage buildup.",
        conflicts = { "pacifist" },
        traitor_only = false,
        archetype = A.Hothead,
        effects = {
            rageRate = 2.0,
            difficulty = -1,
            focus = 0.8, -- the gain/loss rate of focus when attacking
        }
    },
    pacifist = {
        name = "pacifist",
        description = "Experiences little rage, and is slightly less likely to investigate corpses.",
        conflicts = { "rager" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            rageRate = 0.5,
            investigateCorpse = 0.8,
            difficulty = 1,
        }
    },
    steady = {
        name = "steady",
        description = "Almost unaffected by pressure.",
        conflicts = { "shaky" },
        traitor_only = false,
        effects = {
            pressureRate = 0.1,
            difficulty = 3,
            focus = 1.5, -- the gain/loss rate of focus when attacking
        }
    },
    shaky = {
        name = "shaky",
        description = "Much quicker to gain pressure (and thus aim worse).",
        conflicts = { "steady" },
        traitor_only = false,
        effects = {
            pressureRate = 3.0,
            difficulty = -3,
            focus = 0.5, -- the gain/loss rate of focus when attacking
        }
    },
    bemused = {
        name = "bemused",
        description = "Quick to rage and quick to boredom.",
        conflicts = { "easilyamused" },
        traitor_only = false,
        archetype = A.HotHead,
        effects = {
            boredomRate = 2.5,
            rageRate = 1.5,
            difficulty = -1,
        }
    },
    easilyamused = {
        name = "easilyamused",
        description = "Difficult to make bored and less likely to rage.",
        conflicts = { "bemused" },
        traitor_only = false,
        archetype = A.Stoic,
        effects = {
            boredomRate = 0.3,
            rageRate = 0.5,
            difficulty = 1,
        }
    },
    verystoic = {
        name = "verystoic",
        description = "Does not get upset, bored, nor feel pressured.",
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
    defuser = {
        name = "defuser",
        description = "Will always defuse a bomb if non-traitor.",
        conflicts = {},
        traitor_only = false,
        archetype = A.Teamer,
        effects = {
            defuser = true,
        }
    },
    minge = {
        name = "minge",
        description = "Loves to minge with props/corpses and crowbar-shove people",
        conflicts = { "nominge" },
        traitor_only = false,
        archetype = A.Casual,
        effects = {
            mingeRate = 3.0,
        }
    },
    nominge = {
        name = "nominge",
        description = "Will never toy around with props or corpses unless necessary.",
        conflicts = { "minge" },
        traitor_only = false,
        archetype = A.Tryhard,
        effects = {
            mingeRate = 0.0,
        }
    }
}
