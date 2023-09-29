local addLine = TTTBots.LocalizedStrings.AddLine
local AL = function(event, line)
    return addLine(event, line, "en", function(sender) return true end)
end
--- Add line with required traits: for lines only for specific personality traits
local ALRT = function(event, line, traits)
    return addLine(event, line, "en", function(sender)
        ---@type CPersonality
        local personality = sender and sender.components and sender.components.personality
        if not personality then return false end
        for i, trait in pairs(traits) do
            if personality:HasPTrait(trait) then
                return true
            end
        end
    end)
end

local chillTraits = {
    "doesntcare",
    "oblivious",
    "veryoblivious",
    "loner",
    "rmder",
    "talkative",
    "pacifist"
}

AL("FollowRequest", "Sure, I'll follow you.")
AL("FollowRequest", "Okay, I'll follow you.")
AL("FollowRequest", "Alright, I'll follow you.")
AL("FollowRequest", "Gotcha, {{player}}")
AL("FollowRequest", "On my way, {{player}}")
AL("FollowRequest", "I'm coming")
AL("FollowRequest", "I'm on my way")
AL("FollowRequest", "I'm coming with you, {{player}}")
AL("FollowRequest", "Sure thing")
AL("FollowRequest", "Okay")
AL("FollowRequest", "Sure, I'll follow you.")
AL("FollowRequest", "Okay, I'll follow you.")
AL("FollowRequest", "Alright, I'll follow you.")
AL("FollowRequest", "Gotcha, {{player}}.")
AL("FollowRequest", "On my way, {{player}}.")
AL("FollowRequest", "I'm coming.")
AL("FollowRequest", "I'm on my way.")
AL("FollowRequest", "I'm coming with you, {{player}}.")
AL("FollowRequest", "Sure thing.")
AL("FollowRequest", "Okay.")
AL("FollowRequest", "Gotcha.")
AL("FollowRequest", "On my way.")
AL("FollowRequest", "Sure.")
AL("FollowRequest", "Okay.")
AL("FollowRequest", "On it.")
AL("FollowRequest", "Following your lead, {{player}}.")
AL("FollowRequest", "Roger that.")
AL("FollowRequest", "Affirmative.")
AL("FollowRequest", "Copy that, {{player}}.")
AL("FollowRequest", "Understood.")
AL("FollowRequest", "You lead, I'll follow.")
AL("FollowRequest", "Right behind you, {{player}}.")
AL("FollowRequest", "Acknowledged.")
AL("FollowRequest", "I got your back.")
AL("FollowRequest", "You got it.")
AL("FollowRequest", "I hear you, {{player}}. Following.")
AL("FollowRequest", "You got it, champ.")
AL("FollowRequest", "Roger.")
AL("FollowRequest", "Let's roll, {{player}}!")
ALRT("FollowRequest", "Yep.", chillTraits)
ALRT("FollowRequest", "gotcha", chillTraits)
ALRT("FollowRequest", "on my way", chillTraits)
ALRT("FollowRequest", "sure", chillTraits)
ALRT("FollowRequest", "okay", chillTraits)
ALRT("FollowRequest", "on it", chillTraits)
ALRT("FollowRequest", "on my way", chillTraits)
ALRT("FollowRequest", "sure, bud", chillTraits)

AL("CorpseSpotted", "I found a body!")
AL("CorpseSpotted", "I found a dead body!")
AL("CorspeSpotted", "Found a body.")
AL("CorpseSpotted", "Body over here!")
AL("CorpseSpotted", "Found a corpse!")
AL("CorpseSpotted", "Found a dead body!")
AL("CorpseSpotted", "Found a body over here!")
ALRT("CorpseSpotted", "there's a corpse over here", chillTraits)
ALRT("CorpseSpotted", "there's a body over here", chillTraits)
ALRT("CorpseSpotted", "corpse", chillTraits)
ALRT("CorpseSpotted", "body here", chillTraits)

AL("InvestigateNoise", "I heard something.")
AL("InvestigateNoise", "What was that?")
AL("InvestigateNoise", "What was that noise?")
AL("InvestigateNoise", "Did you hear that?")
AL("InvestigateNoise", "Gonna go see what that was about")
AL("InvestigateNoise", "Uhhhh life check") -- TODO: Implement life checks?
ALRT("InvestigateNoise", "pew pew pew", chillTraits)
ALRT("InvestigateNoise", "that sounded not good", chillTraits)
ALRT("InvestigateNoise", "that sounded bad", chillTraits)
ALRT("InvestigateNoise", "that sounded like a gun or smn", chillTraits)
ALRT("InvestigateNoise", "uh-oh", chillTraits)
ALRT("InvestigateNoise", "uhhh", chillTraits)
ALRT("InvestigateNoise", "okay that's not good", chillTraits)
ALRT("InvestigateNoise", "life check", chillTraits)
