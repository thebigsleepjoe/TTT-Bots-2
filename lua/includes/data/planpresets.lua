local PLANS = TTTBots.Plans
local ACTIONS = PLANS.ACTIONS
local TARGETS = PLANS.PLANTARGETS
local PRESETS = {
    LowPlayerCount_Standard = {
        Name = "LowPlayerCount_Standard",
        Description = "Standard plan for low player counts (1-4 players)",
        Conditions = {
            PlyMin = 1,
            PlyMax = 4,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- 10% chance to plant bomb
            {
                Chance = 10,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {}
            },
            -- everyone else will gather for 10-24 seconds
            {
                Chance = 80,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_POPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MinTraitors = 2,
                }
            },
            -- after gathering, attack any player
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    },
    MediumPlayerCount_Standard = {
        Name = "MediumPlayerCount_Standard",
        Description = "Standard plan for medium player counts (5-9 players)",
        Conditions = {
            PlyMin = 5,
            PlyMax = 9,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- if there are only 2 or fewer traitors, just have one plant
            {
                Chance = 20,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 2,
                }
            },
            -- gather for 5-20 seconds if no human traitors
            {
                Chance = 100,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_POPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MaxHumanTraitors = 0,
                }
            },
            -- kill everyone
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    },
    AveragePlayerCount_Standard = {
        Name = "AveragePlayerCount_Standard",
        Description = "Standard plan for average player counts (10-16 players)",
        Conditions = {
            PlyMin = 10,
            PlyMax = 16,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- have 2x plant if there are at least 3 traitors
            {
                Chance = 40,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 2,
                Conditions = {
                    MinTraitors = 3,
                }
            },
            -- if there are only 2 or fewer traitors, just have one plant
            {
                Chance = 20,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 2,
                }
            },
            -- have 1 traitor follow a police (defaults to inno if none)
            {
                Chance = 50,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_POLICE,
                MaxAssigned = 1,
                Conditions = {}
            },
            -- everyone idle should follow any human traitors for 20-40 seconds (fails if no human traitors)
            {
                Chance = 100,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_FRIENDLY_HUMAN,
                MaxAssigned = 99,
                MinDuration = 20,
                MaxDuration = 40,
                Conditions = {
                    MinHumanTraitors = 1,
                }
            },
            -- gather for 5-20 seconds if no human traitors
            {
                Chance = 100,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_POPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MaxHumanTraitors = 0,
                }
            },
            -- kill everyone
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    }
}

PRESETS.Default = PRESETS.AveragePlayerCount_Standard

TTTBots.Plans.PRESETS = PRESETS
