⚠️⚠️⚠️ WARNING: THIS IS NOT READY FOR PRODUCTION USE. ⚠️⚠️⚠️

The repo may be public, but the master branch is constantly being updated at least weekly with often untested code. Do not use this for non-development use until this warning is removed.

![TTT Bots Header](tttbots-banner2.png)
## What is this?
This is a player bot addon for the Trouble in Terrorist Town gamemode in Garry's Mod. It is currently a **WIP**.

It is designed to be as modular as possible, allowing for easy customization and expansion. It is designed for TTT2, while being fully playable in regular TTT.

## How to use
1. Download the latest version from the Steam Workshop **(Will go here when ready)**
2. Start a p2p or dedicated server with sufficient player slots on a map with a navmesh or on one of the included maps.
3. *As a superadmin,* either type `!addbot X` in chat, or write `ttt_bot_add X` in the console.
4. You're done!

## Commands
TODO: Put a wiki here

## Progress:
🚧 = WIP as of last master update

✅ = Done/done 'enough' (may still be tweaked)

❌ = Can't/won't do

📃 = Planned

Locomotion:
1. ✅ Bots can walk around
2. ✅ Bots can open doors
3. ✅ Bots can climb ladders
4. ✅ Bots can semi-realistically look around (like a human), and track nearby players
5. ❌ Advanced obstacle avoidance: They have a rudimentary form of this, but it's not super competent. Basically too complicated for it to be worthwhile.
6. ✅ Break (breakable) props and other stuff blocking the path
7. ✅ Strafe out of the way of trolling/blocking players

Inventory Management:
1. ✅ Bots can pick up weapons
2. ✅ Bots can equip the best weapon for the situation
3. ✅ Bots can reload
4. ✅ Bots can reload shotguns (FINALLY)

Morality:
1. ✅ Bots determine who is the traitor individually based off evidence they see
2. ✅ Traitors will help each other when they get shot
3. ✅ Bots trust trusted players and detectives more, and this affects suspicion on others
4. ✅ SUS: Players shooting randomly are suspicious
5. ✅ SUS: Players shooting near a bot gain more suspicion than if they were shooting randomly
6. 📃 SUS: Players holding a traitor weapon are KOS
7. 📃 SUS: Players disguised are always KOS
8. 📃 SUS: KOS callouts should be made and listened to (from trusted players).
9. 📃 SUS: Players killing traitors should be trusted immediately, just makes more sense.

Basic behavior tree (this is out of order):
1. ✅ Wandering
2. ✅ Attack or hunt current target (WITHOUT wallhacks)
3. 📃 Place a health station if is detective
4. 📃 Heal from health stations
5. ✅ Investigate/search corpses on the ground
6. ✅ Find a weapon
7. ❌ Find ammo: This is not necessary, as the bot will naturally find ammo when it finds a weapon.
8. ✅ Investigate noises
9. 📃 Use DNA scanner to locate traitors
10. 📃 Avoid areas spotted with bombs close by, and communicate when spotting a bomb.
11. 📃 Sniper bots should sit in good sniping areas

Combat:
1. ✅ Attack enemies without wallhacks; hunt players we haven't seen recently.
2. ✅ Traitors should auto-buy radar (this is simulated)
3. 📃 Bots should strafe properly while shooting
4. 📃 Bots should feel pressure when aiming (less accuracy), and should be affected by rage (i.e., losing streaks)
5. 📃 Bot camera should 'flick' when getting shot at, particularly if from behind
6. 📃 Traitor bots should use knives to assassinate innocents
7. 📃 Bots using shotguns should walk towards their target while strafing

User customization/administration:
1. 📃 Difficulty settings; make bots more accurate, have better hearing, etc.
2. 📃 Enable RDMing for the true multiplayer experience
3. 📃 Disable text chatter that isn't strictly utilitarian (e.g., traitor bots sharing plans)
4. 📃 Bot quotas: always have X bots, or fill to X total players
5. 📃 Ban certain traits from being selected, have a UI to explain assigned traits
6. 📃 Have a full UI for bot customization
7. ✅ Include basic bot chat commands, like !addbot
8. 📃 Enable custom player models for bots. Will likely be done thru cvar.
9. 📃 Enable/disable bots blending in on the scoreboard via fake ping, profile pictures, or "BOT" prefix. Some users may not like them blending in with real players.

Traitor bot coordination:
1. ✅ Traitor bots should share their plans with other traitors
2. ✅ Human traitors should be able to tell the nearest bot to follow them
3. 📃 Traitor bots should follow each other around and coordinate attacks
4. 📃 Traitors bots should plant bombs intelligently and avoid bomb areas

Misc. features and non-programming stuff:
1. 📃 Ensure TTT/2 cross-compatibility
2. 📃 CUSTOM Tutorial on how to create navmeshes + how to let them use ladders
3. 📃 Push the first 'ready' build to Steam
4. 📃 Extreme baby-proofing: tell user if no navmesh, no player slots, etc. Maybe even link them to tutorial from #2.