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
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS

    -----------------------------------------------------------
    -- ENTRANCE/EXIT FROM SERVER
    -----------------------------------------------------------


    RegisterCategory("DisconnectBoredom", P.CRITICAL)
    Line("I'm bored. Bye.", A.Default)
    Line("Nothing's happening here. I'm out.", A.Default)
    Line("See ya when there's more action.", A.Default)
    Line("Not much going on. Catch you later.", A.Default)
    Line("This isn't my jam. Later.", A.Default)
    Line("I'm checking out. Peace.", A.Default)

    Line("cya later", A.Casual)
    Line("brb, this ain't it", A.Casual)
    Line("catch ya on the flip side.", A.Casual)
    Line("later", A.Casual)
    Line("holla later, peeps.", A.Casual)
    Line("ill be back (no i wont)", A.Casual)

    Line("What a snore-fest. I'm gone.", A.Bad)
    Line("Wake me up when it's interesting. Out.", A.Bad)
    Line("Yawn... Later losers.", A.Bad)
    Line("This game is boring. I'm leaving.", A.Bad)
    Line("This sucks. I'm done.", A.Bad)
    Line("You guys are boring. Bye.", A.Bad)

    Line("where's the exit button lol", A.Dumb)
    Line("how do you quit garry's mod", A.Dumb)
    Line("how do you turn this off?", A.Dumb)
    Line("duh... bye or something", A.Dumb)
    Line("I'm stuck. Oh wait, there's a quit button.", A.Dumb)
    Line("This too complicated. Bai.", A.Dumb)

    Line("Later pricks", A.Hothead)
    Line("You're all insufferable. Goodbye.", A.Hothead)
    Line("I'm out before I lose it.", A.Hothead)
    Line("Enough of this nonsense. Later.", A.Hothead)
    Line("I can't with you people. Bye.", A.Hothead)
    Line("Ugh, I'm done. Peace.", A.Hothead)

    Line("I'm gonna do something else. Bye!!", A.Nice)
    Line("It's been fun, but I'm heading out. Take care!", A.Nice)
    Line("You all are great, but I need a break. Bye!", A.Nice)
    Line("Had a good time, see you all soon!", A.Nice)
    Line("Thanks for the company. Until next time!", A.Nice)
    Line("It's been lovely. Catch you later!", A.Nice)

    Line("Goodbye.", A.Stoic)
    Line("Farewell.", A.Stoic)
    Line("I am leaving now.", A.Stoic)
    Line("It is time for me to go.", A.Stoic)
    Line("I shall depart.", A.Stoic)
    Line("Farewell for now.", A.Stoic)

    Line("Going to play Valorant.", A.Tryhard)
    Line("Switching to a more competitive game. Bye.", A.Tryhard)
    Line("Need more challenge. Later.", A.Tryhard)
    Line("Off to practice. Ciao.", A.Tryhard)
    Line("gonna play aimlabs cya", A.Tryhard)
    Line("Going to up my game elsewhere. Ta-ta.", A.Tryhard)


    RegisterCategory("DisconnectRage", P.CRITICAL)
    Line("Screw you guys.", A.Default)
    Line("I've had it with this!", A.Default)
    Line("This is just too much. I'm out!", A.Default)
    Line("Seriously?! Done with this nonsense.", A.Default)
    Line("Enough's enough.", A.Default)
    Line("This is the last straw. Bye.", A.Default)

    Line("ugh, screw this", A.Casual)
    Line("I'm done, y'all. Peace.", A.Casual)
    Line("Nope. Can't even.", A.Casual)
    Line("This ain't it, chief.", A.Casual)
    Line("I'm outtie. This sucks.", A.Casual)

    Line("What a pathetic waste of time.", A.Bad)
    Line("You all are the worst. Later.", A.Bad)
    Line("Good riddance. I'm out.", A.Bad)
    Line("I can't stand this garbage. Bye.", A.Bad)
    Line("This game's a joke. Later losers.", A.Bad)

    Line("Why game hard? I leave.", A.Dumb)
    Line("This too tough. Bye bye.", A.Dumb)
    Line("Me mad. Me go.", A.Dumb)
    Line("Game make head hurt. Bai.", A.Dumb)
    Line("Why everyone mean? Me out.", A.Dumb)

    Line("Screw all of you!", A.Hothead)
    Line("I can't take you idiots anymore!", A.Hothead)
    Line("Done with this BS. Peace!", A.Hothead)
    Line("Everyone here sucks. I'm gone.", A.Hothead)
    Line("I swear, you people... I'm out!", A.Hothead)

    Line("Sorry everyone, I need to cool down. Bye.", A.Nice)
    Line("I'm getting a bit frustrated. Need to step away. Take care.", A.Nice)
    Line("I think I need a break. See you all later!", A.Nice)
    Line("I'm feeling overwhelmed. Until next time.", A.Nice)
    Line("Sorry, this isn't my day. Catch you all later!", A.Nice)

    Line("I am departing now.", A.Stoic)
    Line("This is not worth my time.", A.Stoic)
    Line("I shall leave.", A.Stoic)
    Line("It's best I go.", A.Stoic)
    Line("I see no point in continuing. Goodbye.", A.Stoic)

    Line("Team, we'll regroup later. I'm out.", A.Teamer)
    Line("I need REAL competition. This is a joke.", A.Tryhard)
    Line("Pathetic. I'm off to a better game.", A.Tryhard)
    Line("I can't level up with this trash. Later.", A.Tryhard)
    Line("Waste of my skills. I'm gone.", A.Tryhard)
    Line("This isn't worth my time. Bye losers.", A.Tryhard)

    RegisterCategory("ServerConnected", P.NORMAL)
    Line("I'm back!", A.Default)
    Line("Hi everyone.", A.Default)
    Line("Ready to go.", A.Default)
    Line("I'm here.", A.Default)
    Line("I'm back.", A.Default)
    Line("Happy to be here", A.Default)
    Line("I'm in!", A.Default)
    Line("I'm here!", A.Default)
    Line("I'm back, everyone!", A.Default)
    Line("I'm back, let's do this!", A.Default)
    Line("Let's gooooo", A.Default)
    Line("Hello", A.Default)
    Line("yo im here lol", A.Casual)
    Line("sup everyone", A.Casual)
    Line("hey, just joined in", A.Casual)
    Line("we do a little gaming", A.Casual)
    Line("uhhh hi", A.Dumb)
    Line("this server is definitely not a fastdl", A.Dumb)
    Line("hi", A.Dumb)
    Line("i am in server", A.Dumb)
    Line("i love ttt", A.Dumb)
    Line("Finally, I'm in! Let's do this!", A.Hothead)
    Line("That load time was terrible. Excited to play.", A.Hothead)
    Line("Took a while to get in here", A.Hothead)
    Line("What's up losers", A.Hothead)
    Line("Wsg idiots", A.Hothead)
    Line("Ready to rumble!", A.Hothead)
    Line("I'm here to win!", A.Hothead)
    Line("Happy to be here!", A.Nice)
    Line("Looking forward to this!", A.Nice)
    Line("Hello everyone!!", A.Nice)
    Line("Hey guys, I'm back!", A.Nice)
    Line("I'm here to have fun!", A.Nice)


    -----------------------------------------------------------
    -- TARGET ASSIGNMENT / ATTACK
    -----------------------------------------------------------

    RegisterCategory("DisguisedPlayer", P.IMPORTANT) -- When a bot spots someone with a disguise
    Line("This guy is disguised!", A.Default)
    Line("Seems like someone's playing hide and seek!", A.Default)
    Line("A mystery guest among us, huh?", A.Default)
    Line("disguised dude over here", A.Casual)
    Line("nice mask, buddy", A.Casual)
    Line("playing incognito huh?", A.Casual)
    Line("Why cant i see your name??", A.Bad)
    Line("What are you hiding, sneaky?", A.Bad)
    Line("Not fooling anyone, you know", A.Bad)
    Line("who you", A.Dumb)
    Line("Uhh, where did you go?", A.Dumb)
    Line("Hey, why can't I see your face?", A.Dumb)
    Line("Little baby with the disguiser", A.Hothead)
    Line("Take off that silly disguise!", A.Hothead)
    Line("Stop hiding, coward!", A.Hothead)
    Line("my friend is disguised", A.Sus)
    Line("That disguise is super sus", A.Sus)
    Line("erm what the flip", A.Sus)
    Line("Disguising won't save you", A.Tryhard)
    Line("Disguise or not, I'll find you", A.Tryhard)
    Line("You're not escaping my sight", A.Tryhard)


    RegisterCategory("CallKOS", P.CRITICAL) -- When a bot is going to call KOS on another player.
    Line("KOS on {{player}}!", A.Default)
    Line("{{player}} is KOS", A.Default)
    Line("KOS on {{player}}", A.Default)
    Line("KOS {{player}}", A.Default)
    Line("{{player}} is a traitor!", A.Default)
    Line("{{player}} is a traitor.", A.Default)
    Line("KOS on {{player}}!!", A.Default)
    Line("kos {{player}}", A.Casual)
    Line("{{player}} is a traitor", A.Casual)
    Line("kos on {{player}}", A.Casual)
    Line("KOS on {{player}}", A.Casual)
    Line("kill {{player}} i think", A.Bad)
    Line("kill {{player}}", A.Bad)
    Line("{{player}} is mean", A.Dumb)
    Line("kill {{player}}!!!!!11", A.Dumb)
    Line("{{player}} is a traitor ;)", A.Sus)
    Line("you should probably kos {{player}}", A.Sus)
    Line("KOS on {{player}}, I think...", A.Sus)
    Line("KOS {{player}}. For sure.", A.Tryhard)
    Line("KOS on {{player}}, no doubt.", A.Tryhard)
    Line("KOS {{player}}", A.Tryhard)
    Line("KOS {{player}} NOW!", A.Tryhard)

    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------

    local ATTACKANY = ACTS.ATTACKANY
    RegisterCategory(f("Plan.%s", ATTACKANY), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line(f("Plan.%s", ATTACKANY), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I've got {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I'll take {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I call {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I will go after {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I've got {{player}}", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I'll take {{player}}", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I call {{player}}", A.Default)
    Line(f("Plan.%s", ATTACKANY), "I will deal with {{player}}", A.Default)
    Line(f("Plan.%s", ATTACKANY), "dibs on {{player}}.", A.Casual)
    Line(f("Plan.%s", ATTACKANY), "gonna kill {{player}}.", A.Casual)
    Line(f("Plan.%s", ATTACKANY), "I'll try to get {{player}}", A.Bad)
    Line(f("Plan.%s", ATTACKANY), "I'll try to kill {{player}}", A.Bad)
    Line(f("Plan.%s", ATTACKANY), "ion gonna kill {{player}}", A.Dumb)
    Line(f("Plan.%s", ATTACKANY), "{{player}} is my kill target", A.Dumb)
    Line(f("Plan.%s", ATTACKANY), "{{player}} is mine, idiots.", A.Hothead)
    Line(f("Plan.%s", ATTACKANY), "{{player}} is mine.", A.Hothead)
    Line(f("Plan.%s", ATTACKANY), "Gonna wreck {{player}}.", A.Hothead)
    Line(f("Plan.%s", ATTACKANY), "Let me get {{player}}!", A.Teamer)
    Line(f("Plan.%s", ATTACKANY), "Let's take on {{player}}!!", A.Teamer)
    Line(f("Plan.%s", ATTACKANY), "I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line(f("Plan.%s", ATTACKANY), "Dibs on {{player}}. Don't take my ace", A.Tryhard)

    local ATTACK = ACTS.ATTACK
    RegisterCategory(f("Plan.%s", ATTACK), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line(f("Plan.%s", ATTACK), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I've got {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I'll take {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I call {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I will go after {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I'm going to attack {{player}}.", A.Default)
    Line(f("Plan.%s", ATTACK), "I've got {{player}}", A.Default)
    Line(f("Plan.%s", ATTACK), "I'll take {{player}}", A.Default)
    Line(f("Plan.%s", ATTACK), "I call {{player}}", A.Default)
    Line(f("Plan.%s", ATTACK), "I will deal with {{player}}", A.Default)
    Line(f("Plan.%s", ATTACK), "dibs on {{player}}.", A.Casual)
    Line(f("Plan.%s", ATTACK), "gonna kill {{player}}.", A.Casual)
    Line(f("Plan.%s", ATTACK), "I'll try to get {{player}}", A.Bad)
    Line(f("Plan.%s", ATTACK), "I'll try to kill {{player}}", A.Bad)
    Line(f("Plan.%s", ATTACK), "ion gonna kill {{player}}", A.Dumb)
    Line(f("Plan.%s", ATTACK), "{{player}} is my kill target", A.Dumb)
    Line(f("Plan.%s", ATTACK), "{{player}} is mine, idiots.", A.Hothead)
    Line(f("Plan.%s", ATTACK), "{{player}} is mine.", A.Hothead)
    Line(f("Plan.%s", ATTACK), "Gonna wreck {{player}}.", A.Hothead)
    Line(f("Plan.%s", ATTACK), "Let me get {{player}}!", A.Teamer)
    Line(f("Plan.%s", ATTACK), "Let's take on {{player}}!!", A.Teamer)
    Line(f("Plan.%s", ATTACK), "I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line(f("Plan.%s", ATTACK), "Dibs on {{player}}. Don't take my ace", A.Tryhard)

    local PLANT = ACTS.PLANT
    RegisterCategory(f("Plan.%s", PLANT), P.CRITICAL) -- When a traitor bot is going to plant a bomb.
    Line(f("Plan.%s", PLANT), "I'm going to plant a bomb.", A.Default)
    Line(f("Plan.%s", PLANT), "I'm planting a bomb.", A.Default)
    Line(f("Plan.%s", PLANT), "Placing a bomb!", A.Default)
    Line(f("Plan.%s", PLANT), "Gonna rig this place to blow.", A.Default)

    local DEFUSE = ACTS.DEFUSE
    RegisterCategory(f("Plan.%s", DEFUSE), P.CRITICAL) -- When a traitor bot is going to defuse a bomb.
    Line(f("Plan.%s", DEFUSE), "I'm going to defuse a bomb.", A.Default)

    local FOLLOW = ACTS.FOLLOW
    RegisterCategory(f("Plan.%s", FOLLOW), P.CRITICAL) -- When a traitor bot is going to follow a player/bot.
    Line(f("Plan.%s", FOLLOW), "I'm going to follow {{player}}", A.Default)


    local GATHER = ACTS.GATHER
    RegisterCategory(f("Plan.%s", GATHER), P.CRITICAL) -- When a traitor bot is going to gather with other bots.
    Line(f("Plan.%s", GATHER), "Let's all gather over there.", A.Default)
    Line(f("Plan.%s", GATHER), "Gather over here.", A.Default)
    Line(f("Plan.%s", GATHER), "come hither lads", A.Casual)
    Line(f("Plan.%s", GATHER), "come here", A.Casual)
    Line(f("Plan.%s", GATHER), "gather", A.Casual)
    Line(f("Plan.%s", GATHER), "gather here", A.Casual)
    Line(f("Plan.%s", GATHER), "Come on, you idiots, over here.", A.Hothead)
    Line(f("Plan.%s", GATHER), "Gather up, you idiots.", A.Hothead)
    Line(f("Plan.%s", GATHER), "Teamwork makes the dream work", A.Teamer)
    Line(f("Plan.%s", GATHER), "We are not a house divided", A.Teamer)
    Line(f("Plan.%s", GATHER), "Come bunch up so I can use you guys as bullet sponges.", A.Tryhard)
    Line(f("Plan.%s", GATHER), "Gather up, I need you guys to be my meat shields.", A.Tryhard)
    Line(f("Plan.%s", GATHER), "uhhh... let's assemble, lol", A.Dumb)
    Line(f("Plan.%s", GATHER), "let's gather n lather", A.Dumb)
    Line(f("Plan.%s", GATHER), "Come on now, huddle up. Where's my hug at?", A.Stoic)
    Line(f("Plan.%s", GATHER), "Let's gather up, I need a hug.", A.Stoic)
    Line(f("Plan.%s", GATHER), "Where all my friends at? Let's all work together.", A.Nice)
    Line(f("Plan.%s", GATHER), "Let's all gather up, I need some friends for this one.", A.Nice)


    local DEFEND = ACTS.DEFEND
    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL) -- When a traitor bot is going to defend an area.
    Line(f("Plan.%s", DEFEND), "I'm going to defend this area.", A.Default)


    local ROAM = ACTS.ROAM
    RegisterCategory(f("Plan.%s", ROAM), P.CRITICAL) -- When a traitor bot is going to roam.
    Line(f("Plan.%s", ROAM), "I'm going to roam around for a bit.", A.Default)

    local IGNORE = ACTS.IGNORE
    RegisterCategory(f("Plan.%s", IGNORE), P.CRITICAL) -- When a traitor bot wants to ignore the plans.
    Line(f("Plan.%s", IGNORE), "I feel like doing my own thing this time around.", A.Default)
    Line(f("Plan.%s", IGNORE), "I feel like doing my own thing this time around.", A.Default)
    Line(f("Plan.%s", IGNORE), "Going rogue sounds fun right now.", A.Default)
    Line(f("Plan.%s", IGNORE), "Let's mix things up, I'm not following the plan.", A.Default)
    Line(f("Plan.%s", IGNORE), "Eh, plans are overrated anyway.", A.Casual)
    Line(f("Plan.%s", IGNORE), "I'm just gonna wing it this time.", A.Casual)
    Line(f("Plan.%s", IGNORE), "Who cares about plans? I'll do what I want.", A.Bad)
    Line(f("Plan.%s", IGNORE), "Forget the plan, I have my own ideas.", A.Bad)
    Line(f("Plan.%s", IGNORE), "Plans are hard. I'll just do something.", A.Dumb)
    Line(f("Plan.%s", IGNORE), "What was the plan again? Eh, nevermind.", A.Dumb)
    Line(f("Plan.%s", IGNORE), "Plans are for losers. I'm doing this my way!", A.Hothead)
    Line(f("Plan.%s", IGNORE), "I don't follow plans, I make my own!", A.Hothead)
    Line(f("Plan.%s", IGNORE), "Ignoring the plan. Seems more fun to surprise you all.", A.Sus)
    Line(f("Plan.%s", IGNORE), "Who needs a plan? Not me, that's for sure.", A.Sus)
    Line(f("Plan.%s", IGNORE), "Plans are for the weak. Time for a bold move.", A.Tryhard)
    Line(f("Plan.%s", IGNORE), "Strategy? Nah, improvisation is the key to victory.", A.Tryhard)

    -----------------------------------------------------------
    -- FOLLOWING
    -----------------------------------------------------------

    RegisterCategory("FollowRequest", P.CRITICAL) -- When a traitor bot is responding to a request to follow from teammie
    Line("Sure, I'll follow you.", A.Default)
    Line("Okay, I'll follow you.", A.Default)
    Line("Alright, I'll follow you.", A.Default)
    Line("Gotcha, {{player}}", A.Default)
    Line("On my way, {{player}}", A.Default)
    Line("I'm coming", A.Default)
    Line("I'm on my way", A.Default)
    Line("I'm coming with you, {{player}}", A.Default)
    Line("Sure thing", A.Default)
    Line("Okay", A.Default)
    Line("Sure, I'll follow you.", A.Default)
    Line("Okay, I'll follow you.", A.Default)
    Line("Alright, I'll follow you.", A.Default)
    Line("Gotcha, {{player}}.", A.Default)
    Line("On my way, {{player}}.", A.Default)
    Line("I'm coming.", A.Default)
    Line("I'm on my way.", A.Default)
    Line("I'm coming with you, {{player}}.", A.Default)
    Line("Sure thing.", A.Default)
    Line("Okay.", A.Default)
    Line("Gotcha.", A.Default)
    Line("On my way.", A.Default)
    Line("Sure.", A.Default)
    Line("Okay.", A.Default)
    Line("On it.", A.Default)
    Line("Following your lead, {{player}}.", A.Default)
    Line("Roger that.", A.Default)
    Line("Affirmative.", A.Default)
    Line("Copy that, {{player}}.", A.Default)
    Line("Understood.", A.Default)
    Line("You lead, I'll follow.", A.Default)
    Line("Right behind you, {{player}}.", A.Default)
    Line("Acknowledged.", A.Default)
    Line("I got your back.", A.Default)
    Line("You got it.", A.Default)
    Line("I hear you, {{player}}. Following.", A.Default)
    Line("You got it, champ.", A.Default)
    Line("Roger.", A.Default)
    Line("Let's roll, {{player}}!", A.Default)
    Line("yup", A.Casual)
    Line("gotcha", A.Casual)
    Line("on my way", A.Casual)
    Line("sure", A.Casual)
    Line("okay", A.Casual)
    Line("on it", A.Casual)
    Line("on my way", A.Casual)
    Line("sure, bud", A.Casual)


    RegisterCategory("FollowStarted", P.NORMAL) -- When a inno/other bot begins following someone random
    Line("I'm gonna follow you for a bit, {{player}}.", A.Default)
    Line("I'll follow you for a bit, {{player}}.", A.Default)
    Line("Mind if I tag along?", A.Default)
    Line("I'll follow you.", A.Default)
    Line("You look rather follow-able today.", A.Default)
    Line("I'll watch your back {{player}}.", A.Default)
    Line("What's up, {{player}}? Imma tag along.", A.Default)

    Line("hi {{player}}", A.Casual)
    Line("wsg {{player}}? im on your back", A.Casual)
    Line("what's up {{player}}", A.Casual)
    Line("what's good {{player}}? im following you", A.Casual)
    Line("hey imma follow you for a bit", A.Casual)
    Line("dont worry bud i got your back", A.Casual)
    Line("imma follow you", A.Casual)
    Line("imma follow you for a bit", A.Casual)
    Line("imma follow you for a bit, {{player}}", A.Casual)
    Line("im gonna come with", A.Casual)
    Line("mind if little old me comes along?", A.Casual)

    Line("Let's stick together, {{player}}!", A.Teamer)
    Line("I'll follow you, {{player}}!", A.Teamer)
    Line("I'll watch your behind, {{player}}!", A.Teamer)
    Line("Let's keep each other safe, {{player}}!", A.Teamer)
    Line("I'm going to follow you, {{player}}!", A.Teamer)
    Line("Imma follow {{player}}, keep me safe, ok?", A.Teamer)

    Line("haha", A.Dumb)
    Line("haha im following you", A.Dumb)
    Line("im following you for a bit", A.Dumb)
    Line("{{player}}", A.Dumb)
    Line("hi", A.Dumb)
    Line("im glued to you bud", A.Dumb)

    Line("I hope you're good enough.", A.Hothead)
    Line("I guess you'll do, {{player}}", A.Hothead)
    Line("Good enough, I'm following you now.", A.Hothead)
    Line("I'm gonna follow this kid.", A.Hothead)
    Line("You'd better have room for 2, {{player}}", A.Hothead)

    -----------------------------------------------------------
    -- INVESTIGATIONS
    -----------------------------------------------------------


    RegisterCategory("InvestigateCorpse", P.IMPORTANT) -- When a bot begins the InvestigateCorpse behavior (sees a corpse)
    Line("I found a body!")
    Line("I found a dead body!")
    Line("Found a body.")
    Line("Body over here!")
    Line("Found a corpse!")
    Line("Found a dead body!")
    Line("Found a body over here!")
    Line("there's a corpse over here", A.Casual)
    Line("there's a body over here", A.Casual)
    Line("corpse", A.Casual)
    Line("body here", A.Casual)


    RegisterCategory("InvestigateNoise", P.NORMAL) -- When a bot hears a noise and it wants to investigate it.
    Line("I heard something.", A.Default)
    Line("What was that?", A.Default)
    Line("What was that noise?", A.Default)
    Line("Did you hear that?", A.Default)
    Line("Gonna go see what that was about", A.Default)
    Line("pew pew pew", A.Casual)
    Line("that sounded not good", A.Casual)
    Line("that sounded bad", A.Casual)
    Line("that sounded like a gun or smn", A.Casual)
    Line("uh-oh", A.Casual)
    Line("uhhh", A.Casual)
    Line("okay that's not good", A.Casual)
    Line("Did anyone else hear that?", A.Default)
    Line("Something's out there...", A.Default)
    Line("pew pew pew", A.Casual)
    Line("that sounded not good", A.Casual)
    Line("uhh, was that important?", A.Casual)
    Line("hmm, whatever", A.Casual)
    Line("Who's there? Show yourself!", A.Bad)
    Line("I'm not afraid of you!", A.Bad)
    Line("Come out and fight!", A.Bad)
    Line("You can't hide forever!", A.Bad)
    Line("Huh? What's that thing?", A.Dumb)
    Line("I don't get it...", A.Dumb)
    Line("Sounds funny, hehe", A.Dumb)
    Line("Duh, what was I doing?", A.Dumb)
    Line("Who's making noise?!", A.Hothead)
    Line("I'll punch whoever that is!", A.Hothead)
    Line("This is annoying!", A.Hothead)
    Line("Quiet down, I'm busy!", A.Hothead)
    Line("Is someone there? Can I help?", A.Nice)
    Line("Hello? Do you need assistance?", A.Nice)
    Line("I hope they're okay...", A.Nice)
    Line("Maybe they need a friend?", A.Nice)
    Line("Acknowledged.", A.Stoic)
    Line("Proceeding to investigate.", A.Stoic)
    Line("Disturbance detected.", A.Stoic)
    Line("Alertness increased.", A.Stoic)
    Line("I definitely didn't do that.", A.Sus)
    Line("Wasn't me, I swear.", A.Sus)
    Line("You can't prove anything!", A.Sus)
    Line("Why is everyone looking at me?", A.Sus)
    Line("Did you guys hear that too?", A.Teamer)
    Line("We should check it out together.", A.Teamer)
    Line("Us teamers gotta stick together.", A.Teamer)
    Line("Together, we can handle anything!", A.Teamer)
    Line("That sound again?", A.Default)
    Line("I'll check it out.", A.Default)
    Line("Is everything okay there?", A.Default)
    Line("This could be serious.", A.Default)
    Line("I better take a look.", A.Default)
    Line("Sounds suspicious...", A.Default)
    Line("Should I be worried?", A.Default)
    Line("What's happening over there?", A.Default)
    Line("Could be trouble...", A.Default)
    Line("Let's see what that was.", A.Default)
    Line("lol what was that", A.Casual)
    Line("sounds weird but ok", A.Casual)
    Line("eh, probably nothing", A.Casual)
    Line("do i have to check it out?", A.Casual)
    Line("haha, nice sound", A.Casual)
    Line("not my problem, right?", A.Casual)
    Line("who cares lol", A.Casual)
    Line("whatever that is, im chill", A.Casual)
    Line("just another noise", A.Casual)
    Line("meh, sounds boring", A.Casual)
    Line("Someone's asking for trouble!", A.Bad)
    Line("I'm not scared of anything!", A.Bad)
    Line("I'll find out and they'll regret it!", A.Bad)
    Line("Who dares disturb me?", A.Bad)
    Line("Time to show who's boss!", A.Bad)
    Line("They picked the wrong guy to mess with!", A.Bad)
    Line("I'll teach them a lesson!", A.Bad)
    Line("Nobody messes with me!", A.Bad)
    Line("This is my territory!", A.Bad)
    Line("I'm coming for whoever did that!", A.Bad)
    Line("Sounds like a thingy!", A.Dumb)
    Line("What's that doohickey?", A.Dumb)
    Line("I heard a thing!", A.Dumb)
    Line("Dunno what that is, but it's funny!", A.Dumb)
    Line("Sounds like... something?", A.Dumb)
    Line("Hehe, that tickles my ears!", A.Dumb)
    Line("What's that jiggly sound?", A.Dumb)
    Line("Is that a thingamajig?", A.Dumb)
    Line("Ooh, what was that?", A.Dumb)
    Line("Funny noise, makes me giggle!", A.Dumb)
    Line("What was that?!", A.Hothead)
    Line("I'll make you regret it!", A.Hothead)
    Line("So irritating!", A.Hothead)
    Line("I've had enough of this!", A.Hothead)
    Line("This is the last straw!", A.Hothead)
    Line("They're asking for a fight!", A.Hothead)
    Line("I'll shut them up!", A.Hothead)
    Line("Enough of these games!", A.Hothead)
    Line("They won't like me angry!", A.Hothead)
    Line("I'm losing my patience!", A.Hothead)
    Line("Anyone need help?", A.Nice)
    Line("I'm here if you need me!", A.Nice)
    Line("Everything alright there?", A.Nice)
    Line("Can I be of assistance?", A.Nice)
    Line("I hope no one's in trouble.", A.Nice)


    -----------------------------------------------------------
    -- SPOTTING A PLAYER OR ENTITY
    -----------------------------------------------------------

    RegisterCategory("HoldingTraitorWeapon", P.IMPORTANT) -- When a bot sees a player with a traitor-exclusive weapon.
    Line("{{player}} is holding a traitor weapon!", A.Default)
    Line("traitor weapon on {{player}}", A.Casual)
    Line("hey he's holding a traitor weapon", A.Casual)

    RegisterCategory("SpottedC4", P.CRITICAL) -- When an innocent bot sees a C4.
    Line("I found a bomb!", A.Default)

    RegisterCategory("DefusingC4", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("I'm defusing that bomb.", A.Default)

    RegisterCategory("DefusingSuccessful", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("I defused it!", A.Default)


    -----------------------------------------------------------
    -- TRAITOROUS ACTIONS
    -----------------------------------------------------------

    RegisterCategory("BombArmed", P.CRITICAL)
    Line("I armed some C4.", A.Default)

    -----------------------------------------------------------
    -- LIFE CHECKS
    -----------------------------------------------------------


    RegisterCategory("LifeCheck", P.IMPORTANT) -- Response to "life check" or "lc" in chat.
    Line("I'm alive", A.Default)
    Line("Reporting in!", A.Default)
    Line("Functioning as expected.", A.Default)
    Line("Still here.", A.Default)
    Line("In full swing!", A.Default)
    Line("Still alive, somehow.", A.Bad)
    Line("Still here, unfortunately.", A.Bad)
    Line("You again?", A.Bad)
    Line("Why do you keep checking?", A.Bad)
    Line("Does it matter?", A.Bad)
    Line("present", A.Casual)
    Line("hi", A.Casual)
    Line("life", A.Casual)
    Line("am not die", A.Casual)
    Line("chillin", A.Casual)
    Line("hmm? im living", A.Casual)
    Line("all good on this side", A.Casual)
    Line("huh?", A.Dumb)
    Line("Life...check? Okay!", A.Dumb)
    Line("What are we doing again?", A.Dumb)
    Line("Ooo! Me!", A.Dumb)
    Line("Did I do it right?", A.Dumb)
    Line("Alive.", A.Hothead)
    Line("Why are you bothering me?", A.Hothead)
    Line("I'm here, what now?", A.Hothead)
    Line("What do you want?", A.Hothead)
    Line("Every. Single. Time.", A.Hothead)
    Line("Here!", A.Nice)
    Line("Happy to be here!", A.Nice)
    Line("Always here for you.", A.Nice)
    Line("Glad to report in!", A.Nice)
    Line("Hope you're doing well too!", A.Nice)
    Line("Still alive, baby!", A.Stoic)
    Line("Still functioning.", A.Stoic)
    Line("Status unchanged.", A.Stoic)
    Line("Confirmed.", A.Stoic)
    Line("Acknowledged.", A.Stoic)
    Line("...", A.Sus)
    Line("Why do you ask?", A.Sus)
    Line("I'm watching...", A.Sus)
    Line("Why so curious?", A.Sus)
    Line("What did you hear?", A.Sus)
    Line("Duh! I'm alive.", A.Teamer)
    Line("Team, assemble!", A.Teamer)
    Line("We got this!", A.Teamer)
    Line("Hell yeah!", A.Teamer)
    Line("Let's get together!", A.Teamer)
    Line("Alive", A.Tryhard)
    Line("110% here.", A.Tryhard)
    Line("Here.", A.Tryhard)
    Line("Living.", A.Tryhard)
    Line("Dying is for the weak.", A.Tryhard)


    -----------------------------------------------------------
    -- SILLY CHATS
    -----------------------------------------------------------

    RegisterCategory("SillyChat", P.NORMAL) -- When a bot is chatting randomly.
    Line("I'm a traitor.", A.Default)
    Line("Anyone else feel lonely lately?", A.Default)
    Line("Erm ok what the flip", A.Default)
    Line("Can you not?", A.Default)
    Line("Uh excuse me", A.Default)
    Line("aaaaaaaaaaaaa", A.Default)
    Line("How do I chat?", A.Default)
    Line("I think my controls are inverted", A.Default)
    Line("{{player}} is dumb", A.Default)
    Line("Fun fact: you can type \"quit smoking\" in the console to get admin", A.Default)
    Line("{{player}} rdmed me last round", A.Default)
    Line("[AIMBOT ON]", A.Default)
    Line("Whoops, I dropped my dignity", A.Default)
    Line("Merry Christmas", A.Default)
    Line("I'll say it. I like anime.", A.Default)
    Line("I turned my aimbot off for you guys.", A.Default)
    Line("{{player}} can I kill you? for funsies", A.Default)
    Line("I might've pressed my PC's power button on accident", A.Default)
    Line("God, I'm lagging", A.Default)
    Line("Frame rate issues anyone?", A.Default)
    Line("Lagggg", A.Default)
    Line("Happy halloween", A.Default)
    Line("Happy easter", A.Default)
    Line("{{player}}, how are you?", A.Default)
    Line("Thank god I'm an innocent this round!", A.Default)
    Line("I'm a detective.", A.Default)
    Line("'RDM' is temporary. Fun is forever", A.Default)
    Line("You can trust me", A.Default)
    Line("It's pretty quiet in here.", A.Default)
    Line("For the empire!", A.Default)
    Line("I live in a pod", A.Default)
    Line("Women", A.Default)
    Line("I'm kinda hungry", A.Default)

    Line("just vibing here, don't mind me", A.Casual)
    Line("yo, who turned off the gravity?", A.Casual)
    Line("lol, did I just walk into a wall?", A.Casual)
    Line("so, pizza after this?", A.Casual)
    Line("brb, cat's on fire again", A.Casual)
    Line("is it just me or is everything upside down?", A.Casual)
    Line("oops, wrong button. meant to press 'win'", A.Casual)
    Line("if I'm quiet, it's because I'm plotting... or napping", A.Casual)
    Line("hey {{player}}, nice face, did you get it on sale?", A.Casual)
    Line("pro tip: press 'alt+f4' for a secret weapon", A.Casual)
    Line("did someone say taco tuesday?", A.Casual)
    Line("no, I'm not lost, just exploring the floor", A.Casual)
    Line("watch me do a sick backflip... or not", A.Casual)
    Line("let's make this interesting, last one alive owes me a soda", A.Casual)
    Line("i swear, my dog is playing, not me", A.Casual)
    Line("i'm not lazy, just energy efficient", A.Casual)
    Line("uh oh, spaghettios", A.Casual)
    Line("who needs strategy when you have chaos?", A.Casual)
    Line("guys, how do I shoot? asking for a friend", A.Casual)
    Line("plot twist: i'm actually good at this game", A.Casual)

    Line("wait, how do i walk again?", A.Dumb)
    Line("guys, which one is the shooty button?", A.Dumb)
    Line("i thought this was minecraft?", A.Dumb)
    Line("lol, why is everyone running from me?", A.Dumb)
    Line("is it normal to see everything in black and white?", A.Dumb)
    Line("i'm hiding! ...oh wait, am I not supposed to say that?", A.Dumb)
    Line("do i click to throw the grenade or... oops", A.Dumb)
    Line("who's this 'traitor' everyone's talking about?", A.Dumb)
    Line("{{player}}, why are you shooting? is it a bug?", A.Dumb)
    Line("hey, can someone tell me how to aim?", A.Dumb)
    Line("what does 'rdm' mean? really dumb move?", A.Dumb)
    Line("i keep pressing 'esc', why isn't it escaping?", A.Dumb)
    Line("am i winning? i can't tell", A.Dumb)
    Line("this is like hide and seek, right?", A.Dumb)
    Line("what's a detective do? they detect, right?", A.Dumb)
    Line("i think my gun's broken, it only shoots at walls", A.Dumb)
    Line("if I stand still, do I become invisible?", A.Dumb)
    Line("is it bad if my health is at zero?", A.Dumb)
    Line("how do you reload? i've been clicking like crazy", A.Dumb)
    Line("i just threw my gun instead of shooting, is that normal?", A.Dumb)


    RegisterCategory("SillyChatDead", P.NORMAL) -- When a bot is chatting randomly but is currently spectating.
    Line("Well that sucked", A.Default)
    Line("Man I'm dead", A.Default)
    Line("Just got back, why am I not alive?", A.Default)
    Line("Lmao", A.Default)
    Line("Anyone else see that?", A.Default)
    Line("That was kinda BS, ngl", A.Default)
    Line("Ugh.", A.Default)
    Line("Watching some shorts/reels/tiktoks rn", A.Default)
    Line("We'll be back in any second now.", A.Default)
    Line("Yawwwwnnnn", A.Default)
    Line("Man I don't like {{player}}", A.Default)
    Line("I'm gonna go get a snack, someone call me when the round starts.", A.Default)
    Line("Snooze you lose. I snoozed. And loozed.", A.Default)
    Line("Better luck next time", A.Default)
    Line("GGs", A.Default)
    Line("So close to winning", A.Default)
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
