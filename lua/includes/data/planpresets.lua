local PLANS = TTTBots.Plans
local ACTIONS = PLANS.ACTIONS
local TARGETS = PLANS.PLANTARGETS
local PRESETS = {
    LowPlayerCount_Standard = {
        Conditions = {
            PlyMin = 1,
            PlyMax = 4,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Plans = {
            -- 10% chance to plant bomb
            {
                Chance = 10,
                Action = ACTIONS.PLANT,
                Target = TARGETS.CALC_BOMBSPOT,
                NumAssigned = 1,
                Conditions = {}
            },
            -- everyone else will gather for 10-24 seconds
            {
                Chance = 80,
                Action = ACTIONS.GATHER,
                Target = TARGETS.CALC_POPULAR_AREA,
                NumAssigned = 99,
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
                Target = TARGETS.RAND_ENEMY,
                NumAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    },
    AveragePlayerCount_Standard = {
        Conditions = {
            PlyMin = 5,
            PlyMax = 16,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Plans = {
            -- have 2x plant if there are at least 3 traitors
            {
                Chance = 40,
                Action = ACTIONS.PLANT,
                Target = TARGETS.CALC_BOMBSPOT,
                NumAssigned = 2,
                Conditions = {
                    MinTraitors = 3,
                }
            },
            -- if there are only 2 or fewer traitors, just have one plant
            {
                Chance = 20,
                Action = ACTIONS.PLANT,
                Target = TARGETS.CALC_BOMBSPOT,
                NumAssigned = 1,
                Conditions = {
                    MaxTraitors = 2,
                }
            },
            -- have 1 traitor follow a police (defaults to inno if none)
            {
                Chance = 50,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_POLICE,
                NumAssigned = 1,
                Conditions = {}
            },
            -- everyone idle should follow any human traitors for 20-40 seconds (fails if no human traitors)
            {
                Chance = 100,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_FRIENDLY_HUMAN,
                NumAssigned = 99,
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
                Target = TARGETS.CALC_POPULAR_AREA,
                NumAssigned = 99,
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
                Target = TARGETS.RAND_ENEMY,
                NumAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    }
}

PRESETS.Default = PRESETS.AveragePlayerCount_Standard

TTTBots.Plans.PRESETS = PRESETS
