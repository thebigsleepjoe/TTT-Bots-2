# Changelog

## v1.2

### Added

* Bots will nod, shake their head, and look players up and down when approached.

* Bots care about personal space and will get upset if you stay too close for too long. Builds some suspicion every 5 seconds if you're too close.

* Bots will take into effect if you/they are in smoke by having considerably worse accuracy. This does not account for smokes inbetween you and the bot, only if you or they are within range of it.

* Bot accuracy will slowly improve while shooting at the same target for a long time, named "focus." This prevents situations where bots are unable to hit a target that is standing still for several seconds. Accuracy will begin to decrease if out of combat, and is affected by bot personality traits.

* Survivalist support (TODO: fully implement)

* Bots can purchase UMP prototype and utilize it properly.

* Bots can use defibs to revive their teammates. Bots will only revive explicit members of their team/role. This is to prevent the bots from accidentally reviving enemies. Detectives will *generally* not defib innocents.

* Bots are less likely to target the head when shooting at a player. This is to prevent bots from getting crazy lucky headshots. Scales with difficulty, being far more common on hard.

* Depending on difficulty, bots will be more or less likely to strafe in combat. On the easiest difficulty, bots will never strafe.

* Bots will have much better accuracy against immobile players within a certain distance.

### Changes

* Placed cvars on shared realm, so clients can see them.

* Rebalanced bot inventory management. Still not perfect, but better. Bots will prioritize special weapons (e.g. UMP prototype) over normal weapons.

### Fixed

* Retrying bug that threw errors on SRCDS servers. (#34)

* Bots trying to break unbreakable obstructions. (#33)

* Bot inaccuracy not correctly scaling over distances.

* Sending too many net msgs to syncronize bot avatars. (reported per @EntranceJew)

### Developer Notes

This is a more technical explanation of the changes in this version, and contains useful change info for developers.

* Refactored locomotor-related code to be neater and use Player:BotLocomotor instead of grabbing bot.components.locomotor every time.

* Reworked the behavior tree for modularity and consistency. You can nest priority nodes (tables sorted by numbers) inside of other priority nodes, allowing behaviors to be neatly grouped together. This improves consistency between role behaviors.

* Buyables now test for mod presence before attempting to buy a weapon. There is also the option to define if a weapon is TTT2 specific, but this is optional.

* Added easier support for setting temporary variables in the Memory component.