# Changelog

## v1.2

### Added

* Bots will nod, shake their head, and look players up and down when approached.

* Bots care about personal space and will get upset if you stay too close for too long. Builds some suspicion every 5 seconds if you're too close.

* Bots will take into effect if you/they are in smoke by having considerably worse accuracy. This does not account for smokes inbetween you and the bot, only if you or they are within range of it.

* Bot accuracy will slowly improve while shooting at the same target for a long time, named "focus." This prevents situations where bots are unable to hit a target that is standing still for several seconds. Accuracy will begin to decrease if out of combat, and is affected by bot personality traits.

* Survivalist support (TODO: fully implement)

* Bots can purchase UMP prototype (TODO: fully implement)

* Bots can use defibs to revive their teammates. Currently detectives will only revive other detectives, and traitors will only revive other traitors. This is to prevent the bots from accidentally reviving enemies.

### Changes

* Placed cvars on shared realm, so clients can see them.

### Fixed

* Retrying bug that threw errors on SRCDS servers. (#34)

* Bots trying to break unbreakable obstructions. (#33)

* Bot inaccuracy not correctly scaling over distances.

* Sending too many net msgs to syncronize bot avatars -- reduced about 30x. (reported per @EntranceJew)

### Developer Notes

This is a more technical explanation of the changes in this version, and contains useful change info for developers.

* Refactored locomotor-related code to be neater and use Player:BotLocomotor instead of grabbing bot.components.locomotor every time.

* Reworked the behavior tree for modularity and consistency. You can nest priority nodes (tables sorted by numbers) inside of other priority nodes, allowing behaviors to be neatly grouped together. This improves consistency between role behaviors.

* Buyables now test for mod presence before attempting to buy a weapon. There is also the option to define if a weapon is TTT2 specific, but this is optional.
