local PLANS = TTTBots.Plans
local ACTIONS = PLANS.ACTIONS
local TARGETS = PLANS.PLANTARGETS
local PRESETS = {
    LowPlayerCount_Standard = {
        Conditions = {
            PlyMin = 1,
            PlyMax = 4,
            MinTraitors = 1,
            MaxTraitors = 3,
            Chance = 1,
        },
        Plans = {
            {
                --- Chance to perform this part of the plan
                Chance = 0.1,
                --- The action to perform
                Action = ACTIONS.PLANT,
                --- Target of action, if any (not used for all actions)
                Target = TARGETS.CALC_BOMBSPOT,
                --- Maximum number of bots to be assigned to this action
                NumAssigned = 1,
                --- Conditions for this action to be performed
                Conditions = {}
            },
            {
                --- Chance to perform this part of the plan
                Chance = 1.0,
                --- The action to perform
                Action = ACTIONS.GATHER,
                --- Target of action, if any (not used for all actions)
                Target = TARGETS.CALC_POPULAR_AREA,
                --- Maximum number of bots to be assigned to this action
                NumAssigned = 99,
                --- Minimum duration of this action (if applicable)
                MinDuration = 10,
                --- Maximum duration of this action (if applicable)
                MaxDuration = 20,
                --- Conditions for this action to be performed
                Conditions = {
                    MinTraitors = 2,
                }
            },
            {
                --- Chance to perform this part of the plan
                Chance = 0.5,
                --- The action to perform
                Action = ACTIONS.ATTACKANY,
                --- Target of action, if any (not used for all actions)
                Target = TARGETS.RAND_ENEMY,
                --- Maximum number of bots to be assigned to this action
                NumAssigned = 99,
                --- Minimum duration of this action (if applicable)
                MinDuration = 10,
                --- Maximum duration of this action (if applicable)
                MaxDuration = 20,
                --- Conditions for this action to be performed
                Conditions = {
                    MinTraitors = 2,
                }
            },
        }
    }
}

TTTBots.Plans.PRESETS = PRESETS
