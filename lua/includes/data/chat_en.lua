--[[
    This file defines a list of chats that bots will say upon a certain kind of event. It is designed for one-off chatter events, instead of back-and-forth conversation.
    For that, we will have a separate file, and likely use the Localized String system.
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadLang = function()
    local A = TTTBots.Archetypes
    local Line = function(event, line, archetype)
        return TTTBots.Locale.AddLine(event, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority)
        return TTTBots.Locale.RegisterCategory(event, "en", priority)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS

    -----------------------------------------------------------
    -- ENTRANCE/EXIT FROM SERVER
    -----------------------------------------------------------


    RegisterCategory("DisconnectBoredom", P.CRITICAL)
    Line("DisconnectBoredom", "I'm bored. Bye.", A.Default)
    Line("DisconnectBoredom", "Nothing's happening here. I'm out.", A.Default)
    Line("DisconnectBoredom", "See ya when there's more action.", A.Default)
    Line("DisconnectBoredom", "Not much going on. Catch you later.", A.Default)
    Line("DisconnectBoredom", "This isn't my jam. Later.", A.Default)
    Line("DisconnectBoredom", "I'm checking out. Peace.", A.Default)

    Line("DisconnectBoredom", "cya later", A.Casual)
    Line("DisconnectBoredom", "brb, this ain't it", A.Casual)
    Line("DisconnectBoredom", "catch ya on the flip side.", A.Casual)
    Line("DisconnectBoredom", "later", A.Casual)
    Line("DisconnectBoredom", "holla later, peeps.", A.Casual)
    Line("DisconnectBoredom", "ill be back (no i wont)", A.Casual)

    Line("DisconnectBoredom", "What a snore-fest. I'm gone.", A.Bad)
    Line("DisconnectBoredom", "Wake me up when it's interesting. Out.", A.Bad)
    Line("DisconnectBoredom", "Yawn... Later losers.", A.Bad)
    Line("DisconnectBoredom", "This game is boring. I'm leaving.", A.Bad)
    Line("DisconnectBoredom", "This sucks. I'm done.", A.Bad)
    Line("DisconnectBoredom", "You guys are boring. Bye.", A.Bad)

    Line("DisconnectBoredom", "where's the exit button lol", A.Dumb)
    Line("DisconnectBoredom", "how do you quit garry's mod", A.Dumb)
    Line("DisconnectBoredom", "how do you turn this off?", A.Dumb)
    Line("DisconnectBoredom", "duh... bye or something", A.Dumb)
    Line("DisconnectBoredom", "I'm stuck. Oh wait, there's a quit button.", A.Dumb)
    Line("DisconnectBoredom", "This too complicated. Bai.", A.Dumb)

    Line("DisconnectBoredom", "Later pricks", A.Hothead)
    Line("DisconnectBoredom", "You're all insufferable. Goodbye.", A.Hothead)
    Line("DisconnectBoredom", "I'm out before I lose it.", A.Hothead)
    Line("DisconnectBoredom", "Enough of this nonsense. Later.", A.Hothead)
    Line("DisconnectBoredom", "I can't with you people. Bye.", A.Hothead)
    Line("DisconnectBoredom", "Ugh, I'm done. Peace.", A.Hothead)

    Line("DisconnectBoredom", "I'm gonna do something else. Bye!!", A.Nice)
    Line("DisconnectBoredom", "It's been fun, but I'm heading out. Take care!", A.Nice)
    Line("DisconnectBoredom", "You all are great, but I need a break. Bye!", A.Nice)
    Line("DisconnectBoredom", "Had a good time, see you all soon!", A.Nice)
    Line("DisconnectBoredom", "Thanks for the company. Until next time!", A.Nice)
    Line("DisconnectBoredom", "It's been lovely. Catch you later!", A.Nice)

    Line("DisconnectBoredom", "Goodbye.", A.Stoic)
    Line("DisconnectBoredom", "Farewell.", A.Stoic)
    Line("DisconnectBoredom", "I am leaving now.", A.Stoic)
    Line("DisconnectBoredom", "It is time for me to go.", A.Stoic)
    Line("DisconnectBoredom", "I shall depart.", A.Stoic)
    Line("DisconnectBoredom", "Farewell for now.", A.Stoic)

    Line("DisconnectBoredom", "Going to play Valorant.", A.Tryhard)
    Line("DisconnectBoredom", "Switching to a more competitive game. Bye.", A.Tryhard)
    Line("DisconnectBoredom", "Need more challenge. Later.", A.Tryhard)
    Line("DisconnectBoredom", "Off to practice. Ciao.", A.Tryhard)
    Line("DisconnectBoredom", "gonna play aimlabs cya", A.Tryhard)
    Line("DisconnectBoredom", "Going to up my game elsewhere. Ta-ta.", A.Tryhard)


    RegisterCategory("DisconnectRage", P.CRITICAL)
    Line("DisconnectRage", "Screw you guys.", A.Default)
    Line("DisconnectRage", "I've had it with this!", A.Default)
    Line("DisconnectRage", "This is just too much. I'm out!", A.Default)
    Line("DisconnectRage", "Seriously?! Done with this nonsense.", A.Default)
    Line("DisconnectRage", "Enough's enough.", A.Default)
    Line("DisconnectRage", "This is the last straw. Bye.", A.Default)

    Line("DisconnectRage", "ugh, screw this", A.Casual)
    Line("DisconnectRage", "I'm done, y'all. Peace.", A.Casual)
    Line("DisconnectRage", "Nope. Can't even.", A.Casual)
    Line("DisconnectRage", "This ain't it, chief.", A.Casual)
    Line("DisconnectRage", "I'm outtie. This sucks.", A.Casual)

    Line("DisconnectRage", "What a pathetic waste of time.", A.Bad)
    Line("DisconnectRage", "You all are the worst. Later.", A.Bad)
    Line("DisconnectRage", "Good riddance. I'm out.", A.Bad)
    Line("DisconnectRage", "I can't stand this garbage. Bye.", A.Bad)
    Line("DisconnectRage", "This game's a joke. Later losers.", A.Bad)

    Line("DisconnectRage", "Why game hard? I leave.", A.Dumb)
    Line("DisconnectRage", "This too tough. Bye bye.", A.Dumb)
    Line("DisconnectRage", "Me mad. Me go.", A.Dumb)
    Line("DisconnectRage", "Game make head hurt. Bai.", A.Dumb)
    Line("DisconnectRage", "Why everyone mean? Me out.", A.Dumb)

    Line("DisconnectRage", "Screw all of you!", A.Hothead)
    Line("DisconnectRage", "I can't take you idiots anymore!", A.Hothead)
    Line("DisconnectRage", "Done with this BS. Peace!", A.Hothead)
    Line("DisconnectRage", "Everyone here sucks. I'm gone.", A.Hothead)
    Line("DisconnectRage", "I swear, you people... I'm out!", A.Hothead)

    Line("DisconnectRage", "Sorry everyone, I need to cool down. Bye.", A.Nice)
    Line("DisconnectRage", "I'm getting a bit frustrated. Need to step away. Take care.", A.Nice)
    Line("DisconnectRage", "I think I need a break. See you all later!", A.Nice)
    Line("DisconnectRage", "I'm feeling overwhelmed. Until next time.", A.Nice)
    Line("DisconnectRage", "Sorry, this isn't my day. Catch you all later!", A.Nice)

    Line("DisconnectRage", "I am departing now.", A.Stoic)
    Line("DisconnectRage", "This is not worth my time.", A.Stoic)
    Line("DisconnectRage", "I shall leave.", A.Stoic)
    Line("DisconnectRage", "It's best I go.", A.Stoic)
    Line("DisconnectRage", "I see no point in continuing. Goodbye.", A.Stoic)

    Line("DisconnectRage", "Team, we'll regroup later. I'm out.", A.Teamer)
    Line("DisconnectRage", "I need REAL competition. This is a joke.", A.Tryhard)
    Line("DisconnectRage", "Pathetic. I'm off to a better game.", A.Tryhard)
    Line("DisconnectRage", "I can't level up with this trash. Later.", A.Tryhard)
    Line("DisconnectRage", "Waste of my skills. I'm gone.", A.Tryhard)
    Line("DisconnectRage", "This isn't worth my time. Bye losers.", A.Tryhard)

    -----------------------------------------------------------
    -- TARGET ASSIGNMENT / ATTACK
    -----------------------------------------------------------

    RegisterCategory("DisguisedPlayer", P.IMPORTANT) -- When a bot spots someone with a disguise
    Line("DisguisedPlayer", "This guy is disguised!", A.Default)
    Line("DisguisedPlayer", "disguised dude over here", A.Casual)
    Line("DisguisedPlayer", "Why cant i see your name??", A.Bad)
    Line("DisguisedPlayer", "who you", A.Dumb)
    Line("DisguisedPlayer", "Little baby with the disguiser", A.Hothead)
    Line("DisguisedPlayer", "my friend is disguised", A.Sus)
    Line("DisguisedPlayer", "Disguising won't save you", A.Tryhard)


    RegisterCategory("CallKOS", P.CRITICAL) -- When a bot is going to call KOS on another player.
    Line("CallKOS", "KOS on {{player}}!", A.Default)
    Line("CallKOS", "{{player}} is KOS", A.Default)
    Line("CallKOS", "KOS on {{player}}", A.Default)
    Line("CallKOS", "KOS {{player}}", A.Default)
    Line("CallKOS", "{{player}} is a traitor!", A.Default)
    Line("CallKOS", "{{player}} is a traitor.", A.Default)
    Line("CallKOS", "KOS on {{player}}!!", A.Default)
    Line("CallKOS", "kos {{player}}", A.Casual)
    Line("CallKOS", "{{player}} is a traitor", A.Casual)
    Line("CallKOS", "kos on {{player}}", A.Casual)
    Line("CallKOS", "KOS on {{player}}", A.Casual)
    Line("CallKOS", "kill {{player}} i think", A.Bad)
    Line("CallKOS", "kill {{player}}", A.Bad)
    Line("CallKOS", "{{player}} is mean", A.Dumb)
    Line("CallKOS", "kill {{player}}!!!!!11", A.Dumb)
    Line("CallKOS", "{{player}} is a traitor ;)", A.Sus)
    Line("CallKOS", "you should probably kos {{player}}", A.Sus)
    Line("CallKOS", "KOS on {{player}}, I think...", A.Sus)
    Line("CallKOS", "KOS {{player}}. For sure.", A.Tryhard)
    Line("CallKOS", "KOS on {{player}}, no doubt.", A.Tryhard)
    Line("CallKOS", "KOS {{player}}", A.Tryhard)
    Line("CallKOS", "KOS {{player}} NOW!", A.Tryhard)

    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------


    RegisterCategory(f("Plan.%s", ACTS["ATTACKANY"]), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I've got {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I call {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I will go after {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I've got {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I call {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I will deal with {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "dibs on {{player}}.", A.Casual)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "gonna kill {{player}}.", A.Casual)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll try to get {{player}}", A.Bad)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll try to kill {{player}}", A.Bad)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "ion gonna kill {{player}}", A.Dumb)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is my kill target", A.Dumb)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is mine, idiots.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is mine.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Gonna wreck {{player}}.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Let me get {{player}}!", A.Teamer)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Let's take on {{player}}!!", A.Teamer)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Dibs on {{player}}. Don't take my ace", A.Tryhard)


    RegisterCategory(f("Plan.%s", ACTS["ATTACK"]), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I've got {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I call {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I will go after {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I've got {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I call {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I will deal with {{player}}", A.Default)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "dibs on {{player}}.", A.Casual)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "gonna kill {{player}}.", A.Casual)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll try to get {{player}}", A.Bad)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll try to kill {{player}}", A.Bad)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "ion gonna kill {{player}}", A.Dumb)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is my kill target", A.Dumb)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is mine, idiots.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "{{player}} is mine.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Gonna wreck {{player}}.", A.Hothead)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Let me get {{player}}!", A.Teamer)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Let's take on {{player}}!!", A.Teamer)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line(f("Plan.%s", ACTS["ATTACKANY"]), "Dibs on {{player}}. Don't take my ace", A.Tryhard)


    RegisterCategory(f("Plan.%s", ACTS["PLANT"]), P.CRITICAL) -- When a traitor bot is going to plant a bomb.
    Line(f("Plan.%s", ACTS["PLANT"]), "I'm going to plant a bomb.", A.Default)
    Line(f("Plan.%s", ACTS["PLANT"]), "I'm planting a bomb.", A.Default)
    Line(f("Plan.%s", ACTS["PLANT"]), "Placing a bomb!", A.Default)
    Line(f("Plan.%s", ACTS["PLANT"]), "Gonna rig this place to blow.", A.Default)


    RegisterCategory(f("Plan.%s", ACTS["DEFUSE"]), P.CRITICAL) -- When a traitor bot is going to defuse a bomb.
    Line(f("Plan.%s", ACTS["DEFUSE"]), "I'm going to defuse a bomb.", A.Default)


    RegisterCategory(f("Plan.%s", ACTS["FOLLOW"]), P.CRITICAL) -- When a traitor bot is going to follow a player/bot.
    Line(f("Plan.%s", ACTS["FOLLOW"]), "I'm going to follow {{player}}", A.Default)


    RegisterCategory(f("Plan.%s", ACTS["GATHER"]), P.CRITICAL) -- When a traitor bot is going to gather with other bots.
    Line(f("Plan.%s", ACTS["GATHER"]), "Let's all gather over there.", A.Default)
    Line(f("Plan.%s", ACTS["GATHER"]), "Gather over here.", A.Default)
    Line(f("Plan.%s", ACTS["GATHER"]), "come hither lads", A.Casual)
    Line(f("Plan.%s", ACTS["GATHER"]), "come here", A.Casual)
    Line(f("Plan.%s", ACTS["GATHER"]), "gather", A.Casual)
    Line(f("Plan.%s", ACTS["GATHER"]), "gather here", A.Casual)
    Line(f("Plan.%s", ACTS["GATHER"]), "Come on, you idiots, over here.", A.Hothead)
    Line(f("Plan.%s", ACTS["GATHER"]), "Gather up, you idiots.", A.Hothead)
    Line(f("Plan.%s", ACTS["GATHER"]), "Teamwork makes the dream work", A.Teamer)
    Line(f("Plan.%s", ACTS["GATHER"]), "We are not a house divided", A.Teamer)
    Line(f("Plan.%s", ACTS["GATHER"]), "Come bunch up so I can use you guys as bullet sponges.", A.Tryhard)
    Line(f("Plan.%s", ACTS["GATHER"]), "Gather up, I need you guys to be my meat shields.", A.Tryhard)
    Line(f("Plan.%s", ACTS["GATHER"]), "uhhh... let's assemble, lol", A.Dumb)
    Line(f("Plan.%s", ACTS["GATHER"]), "let's gather n lather", A.Dumb)
    Line(f("Plan.%s", ACTS["GATHER"]), "Come on now, huddle up. Where's my hug at?", A.Stoic)
    Line(f("Plan.%s", ACTS["GATHER"]), "Let's gather up, I need a hug.", A.Stoic)
    Line(f("Plan.%s", ACTS["GATHER"]), "Where all my friends at? Let's all work together.", A.Nice)
    Line(f("Plan.%s", ACTS["GATHER"]), "Let's all gather up, I need some friends for this one.", A.Nice)


    RegisterCategory(f("Plan.%s", ACTS["DEFEND"]), P.CRITICAL) -- When a traitor bot is going to defend an area.
    Line(f("Plan.%s", ACTS["DEFEND"]), "I'm going to defend this area.", A.Default)


    RegisterCategory(f("Plan.%s", ACTS["ROAM"]), P.CRITICAL) -- When a traitor bot is going to roam.
    Line(f("Plan.%s", ACTS["ROAM"]), "I'm going to roam around for a bit.", A.Default)


    RegisterCategory(f("Plan.%s", ACTS["IGNORE"]), P.CRITICAL) -- When a traitor bot wants to ignore the plans.
    Line(f("Plan.%s", ACTS["IGNORE"]), "I feel like doing my own thing this time around.", A.Default)

    -----------------------------------------------------------
    -- FOLLOWING
    -----------------------------------------------------------

    RegisterCategory("FollowRequest", P.CRITICAL) -- When a traitor bot is responding to a request to follow from teammie
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


    RegisterCategory("FollowStarted", P.NORMAL) -- When a inno/other bot begins following someone random
    Line("FollowStarted", "I'm gonna follow you for a bit, {{player}}.", A.Default)
    Line("FollowStarted", "I'll follow you for a bit, {{player}}.", A.Default)
    Line("FollowStarted", "Mind if I tag along?", A.Default)
    Line("FollowStarted", "I'll follow you.", A.Default)
    Line("FollowStarted", "You look rather follow-able today.", A.Default)
    Line("FollowStarted", "I'll watch your back {{player}}.", A.Default)
    Line("FollowStarted", "What's up, {{player}}? Imma tag along.", A.Default)

    Line("FollowStarted", "hi {{player}}", A.Casual)
    Line("FollowStarted", "wsg {{player}}?", A.Casual)
    Line("FollowStarted", "what's up {{player}}", A.Casual)
    Line("FollowStarted", "what's good {{player}}? im following you", A.Casual)
    Line("FollowStarted", "hey imma follow you for a bit", A.Casual)
    Line("FollowStarted", "dont worry bud i got your back", A.Casual)
    Line("FollowStarted", "imma follow you", A.Casual)
    Line("FollowStarted", "imma follow you for a bit", A.Casual)
    Line("FollowStarted", "imma follow you for a bit, {{player}}", A.Casual)
    Line("FollowStarted", "im gonna come with", A.Casual)
    Line("FollowStarted", "mind if little old me comes along?", A.Casual)

    Line("FollowStarted", "Let's stick together, {{player}}!", A.Teamer)
    Line("FollowStarted", "I'll follow you, {{player}}!", A.Teamer)
    Line("FollowStarted", "I'll watch your six!", A.Teamer)
    Line("FollowStarted", "Let's keep each other safe, {{player}}!", A.Teamer)
    Line("FollowStarted", "I'm going to follow you, {{player}}!", A.Teamer)
    Line("FollowStarted", "Imma follow {{player}}, keep me safe, ok?", A.Teamer)

    Line("FollowStarted", "haha", A.Dumb)
    Line("FollowStarted", "haha im following you", A.Dumb)
    Line("FollowStarted", "im following you for a bit", A.Dumb)
    Line("FollowStarted", "{{player}}", A.Dumb)
    Line("FollowStarted", "hi", A.Dumb)
    Line("FollowStarted", "im glued to you bud", A.Dumb)

    Line("FollowStarted", "I hope you're good enough.", A.Hothead)
    Line("FollowStarted", "I guess you'll do, {{player}}", A.Hothead)
    Line("FollowStarted", "Good enough, I'm following you now.", A.Hothead)
    Line("FollowStarted", "I'm gonna follow this kid.", A.Hothead)
    Line("FollowStarted", "You'd better have room for 2, {{player}}", A.Hothead)

    -----------------------------------------------------------
    -- INVESTIGATIONS
    -----------------------------------------------------------


    RegisterCategory("InvestigateCorpse", P.IMPORTANT) -- When a bot begins the InvestigateCorpse behavior (sees a corpse)
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


    RegisterCategory("InvestigateNoise", P.NORMAL) -- When a bot hears a noise and it wants to investigate it.
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
    -- SPOTTING A PLAYER WITH A TRAITOR WEAPON
    -----------------------------------------------------------

    RegisterCategory("HoldingTraitorWeapon", P.IMPORTANT) -- When a bot sees a player with a traitor-exclusive weapon.
    Line("HoldingTraitorWeapon", "{{player}} is holding a traitor weapon!", A.Default)
    Line("HoldingTraitorWeapon", "traitor weapon on {{player}}", A.Casual)
    Line("HoldingTraitorWeapon", "hey he's holding a traitor weapon", A.Casual)


    -----------------------------------------------------------
    -- LIFE CHECKS
    -----------------------------------------------------------


    RegisterCategory("LifeCheck", P.IMPORTANT) -- Response to "life check" or "lc" in chat.
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
