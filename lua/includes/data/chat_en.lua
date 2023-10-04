local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadLang = function()
    local A = TTTBots.Archetypes
    local Line = function(event, line, archetype)
        return TTTBots.LocalizedStrings.AddLine(event, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority)
        return TTTBots.LocalizedStrings.RegisterCategory(event, "en", priority)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS


    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------

    RegisterCategory(f("Plan.%s", ACTS["ATTACKANY"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'm going to attack {{player}}.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["ATTACK"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["ATTACK"]), "I'm going to attack {{player}}.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["PLANT"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["PLANT"]), "I'm going to plant a bomb.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["DEFUSE"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["DEFUSE"]), "I'm going to defuse a bomb.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["FOLLOW"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["FOLLOW"]), "I'm going to follow {{player}}", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["GATHER"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["GATHER"]), "Let's all gather over there.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["DEFEND"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["DEFEND"]), "I'm going to defend this area.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["ROAM"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["ROAM"]), "I'm going to roam around for a bit.", A.Default)

    RegisterCategory(f("Plan.%s", ACTS["IGNORE"]), P.CRITICAL)
    Line(f("Plan.%s", ACTS["IGNORE"]), "I feel like doing my own thing this time around.", A.Default)

    -----------------------------------------------------------
    -- FOLLOW REQUESTS
    -----------------------------------------------------------

    RegisterCategory("FollowRequest", P.CRITICAL)
    Line("FollowRequest", "Sure, I'll follow you.", A.Default)
    Line("FollowRequest", "Okay, I'll follow you.", A.Default)
    Line("FollowRequest", "Alright, I'll follow you.", A.Default)
    Line("FollowRequest", "Gotcha, {{player}}", A.Default)
    Line("FollowRequest", "On my way, {{player}}", A.Default)
    Line("FollowRequest", "I'm coming", A.Default)
    Line("FollowRequest", "I'm on my way", A.Default)
    Line("FollowRequest", "I'm coming with you, {{player}}", A.Default)
    Line("FollowRequest", "Sure thing", A.Default)
    Line("FollowRequest", "Okay", A.Default)
    Line("FollowRequest", "Sure, I'll follow you.", A.Default)
    Line("FollowRequest", "Okay, I'll follow you.", A.Default)
    Line("FollowRequest", "Alright, I'll follow you.", A.Default)
    Line("FollowRequest", "Gotcha, {{player}}.", A.Default)
    Line("FollowRequest", "On my way, {{player}}.", A.Default)
    Line("FollowRequest", "I'm coming.", A.Default)
    Line("FollowRequest", "I'm on my way.", A.Default)
    Line("FollowRequest", "I'm coming with you, {{player}}.", A.Default)
    Line("FollowRequest", "Sure thing.", A.Default)
    Line("FollowRequest", "Okay.", A.Default)
    Line("FollowRequest", "Gotcha.", A.Default)
    Line("FollowRequest", "On my way.", A.Default)
    Line("FollowRequest", "Sure.", A.Default)
    Line("FollowRequest", "Okay.", A.Default)
    Line("FollowRequest", "On it.", A.Default)
    Line("FollowRequest", "Following your lead, {{player}}.", A.Default)
    Line("FollowRequest", "Roger that.", A.Default)
    Line("FollowRequest", "Affirmative.", A.Default)
    Line("FollowRequest", "Copy that, {{player}}.", A.Default)
    Line("FollowRequest", "Understood.", A.Default)
    Line("FollowRequest", "You lead, I'll follow.", A.Default)
    Line("FollowRequest", "Right behind you, {{player}}.", A.Default)
    Line("FollowRequest", "Acknowledged.", A.Default)
    Line("FollowRequest", "I got your back.", A.Default)
    Line("FollowRequest", "You got it.", A.Default)
    Line("FollowRequest", "I hear you, {{player}}. Following.", A.Default)
    Line("FollowRequest", "You got it, champ.", A.Default)
    Line("FollowRequest", "Roger.", A.Default)
    Line("FollowRequest", "Let's roll, {{player}}!", A.Default)
    Line("FollowRequest", "yup", A.Casual)
    Line("FollowRequest", "gotcha", A.Casual)
    Line("FollowRequest", "on my way", A.Casual)
    Line("FollowRequest", "sure", A.Casual)
    Line("FollowRequest", "okay", A.Casual)
    Line("FollowRequest", "on it", A.Casual)
    Line("FollowRequest", "on my way", A.Casual)
    Line("FollowRequest", "sure, bud", A.Casual)

    -----------------------------------------------------------
    -- INVESTIGATIONS
    -----------------------------------------------------------

    RegisterCategory("InvestigateCorpse", P.IMPORTANT)
    Line("InvestigateCorpse", "I found a body!")
    Line("InvestigateCorpse", "I found a dead body!")
    Line("InvestigateCorpse", "Found a body.")
    Line("InvestigateCorpse", "Body over here!")
    Line("InvestigateCorpse", "Found a corpse!")
    Line("InvestigateCorpse", "Found a dead body!")
    Line("InvestigateCorpse", "Found a body over here!")
    Line("InvestigateCorpse", "there's a corpse over here", A.Casual)
    Line("InvestigateCorpse", "there's a body over here", A.Casual)
    Line("InvestigateCorpse", "corpse", A.Casual)
    Line("InvestigateCorpse", "body here", A.Casual)

    RegisterCategory("InvestigateNoise", P.NORMAL)
    Line("InvestigateNoise", "I heard something.")
    Line("InvestigateNoise", "What was that?")
    Line("InvestigateNoise", "What was that noise?")
    Line("InvestigateNoise", "Did you hear that?")
    Line("InvestigateNoise", "Gonna go see what that was about")
    Line("InvestigateNoise", "Uhhhh life check")
    Line("InvestigateNoise", "pew pew pew", A.Casual)
    Line("InvestigateNoise", "that sounded not good", A.Casual)
    Line("InvestigateNoise", "that sounded bad", A.Casual)
    Line("InvestigateNoise", "that sounded like a gun or smn", A.Casual)
    Line("InvestigateNoise", "uh-oh", A.Casual)
    Line("InvestigateNoise", "uhhh", A.Casual)
    Line("InvestigateNoise", "okay that's not good", A.Casual)
    Line("InvestigateNoise", "life check", A.Casual)

    -----------------------------------------------------------
    -- LIFE CHECKS
    -----------------------------------------------------------

    RegisterCategory("LifeCheck", P.IMPORTANT)
    Line("LifeCheck", "I'm alive", A.Default)
    Line("LifeCheck", "Reporting in!", A.Default)
    Line("LifeCheck", "Functioning as expected.", A.Default)
    Line("LifeCheck", "Still here.", A.Default)
    Line("LifeCheck", "In full swing!", A.Default)
    Line("LifeCheck", "Still alive, somehow.", A.Bad)
    Line("LifeCheck", "Still here, unfortunately.", A.Bad)
    Line("LifeCheck", "You again?", A.Bad)
    Line("LifeCheck", "Why do you keep checking?", A.Bad)
    Line("LifeCheck", "Does it matter?", A.Bad)
    Line("LifeCheck", "present", A.Casual)
    Line("LifeCheck", "hi", A.Casual)
    Line("LifeCheck", "life", A.Casual)
    Line("LifeCheck", "am not die", A.Casual)
    Line("LifeCheck", "chillin", A.Casual)
    Line("LifeCheck", "hmm? im living", A.Casual)
    Line("LifeCheck", "all good on this side", A.Casual)
    Line("LifeCheck", "huh?", A.Dumb)
    Line("LifeCheck", "Life...check? Okay!", A.Dumb)
    Line("LifeCheck", "What are we doing again?", A.Dumb)
    Line("LifeCheck", "Ooo! Me!", A.Dumb)
    Line("LifeCheck", "Did I do it right?", A.Dumb)
    Line("LifeCheck", "Alive.", A.Hothead)
    Line("LifeCheck", "Why are you bothering me?", A.Hothead)
    Line("LifeCheck", "I'm here, what now?", A.Hothead)
    Line("LifeCheck", "What do you want?", A.Hothead)
    Line("LifeCheck", "Every. Single. Time.", A.Hothead)
    Line("LifeCheck", "Here!", A.Nice)
    Line("LifeCheck", "Happy to be here!", A.Nice)
    Line("LifeCheck", "Always here for you.", A.Nice)
    Line("LifeCheck", "Glad to report in!", A.Nice)
    Line("LifeCheck", "Hope you're doing well too!", A.Nice)
    Line("LifeCheck", "Still alive, baby!", A.Stoic)
    Line("LifeCheck", "Still functioning.", A.Stoic)
    Line("LifeCheck", "Status unchanged.", A.Stoic)
    Line("LifeCheck", "Confirmed.", A.Stoic)
    Line("LifeCheck", "Acknowledged.", A.Stoic)
    Line("LifeCheck", "...", A.Sus)
    Line("LifeCheck", "Why do you ask?", A.Sus)
    Line("LifeCheck", "I'm watching...", A.Sus)
    Line("LifeCheck", "Why so curious?", A.Sus)
    Line("LifeCheck", "What did you hear?", A.Sus)
    Line("LifeCheck", "Duh! I'm alive.", A.Teamer)
    Line("LifeCheck", "Team, assemble!", A.Teamer)
    Line("LifeCheck", "We got this!", A.Teamer)
    Line("LifeCheck", "Hell yeah!", A.Teamer)
    Line("LifeCheck", "Let's get together!", A.Teamer)
    Line("LifeCheck", "Alive", A.Tryhard)
    Line("LifeCheck", "110% here.", A.Tryhard)
    Line("LifeCheck", "Here.", A.Tryhard)
    Line("LifeCheck", "Living.", A.Tryhard)
    Line("LifeCheck", "Dying is for the weak.", A.Tryhard)
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
