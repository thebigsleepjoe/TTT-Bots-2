# Changelog

## v1.2

### Added/Changed

* Bots will sometimes nod, shake their head, and look players up and down when approached.

* Bots care about personal space and will get upset if you stay too close for too long. Builds some suspicion every 5 seconds if you're too close.

* **TTT2** Survivalist support (TODO: fully implement)

* Bots can purchase UMP prototype and utilize it properly.

* **TTT2** Bots can use defibs to revive their allies. [This addon](https://steamcommunity.com/sharedfiles/filedetails/?id=2115944312) is required for this to happen.

* Bots will be less likely to target the head or strafe on lower difficulties.

* Placed cvars on shared realm, so clients can see them.

* Rebalanced bot inventory management. Still not perfect, but better. Bots will prioritize special weapons (e.g. UMP prototype) over normal weapons.

* Overall bot accuracy rebalance:
  1. Worse accuracy when the bot is moving.
  2. Worse accuracy when their target is moving.
  3. Worse accuracy when the bot or its target is in smoke.
  4. Better accuracy when the bot is stationary.
  5. Better accuracy when shoothing stationary targets.
  6. "Focus" system, where bots will increase in shooting accuracy when shooting at the same target for some time. Affected heavily by personality.

### Fixed

* Retrying bug that threw errors on SRCDS servers. (#34)

* Bots trying to break unbreakable obstructions. (#33)

* Bot inaccuracy not correctly scaling over distances. It was hard-capped to a lower value than it should be.

* Sending too many net msgs to syncronize bot avatars. (reported per @EntranceJew)

### Developer Notes

This is a more technical explanation of the changes in this version, and contains useful change info for developers.

* Refactored locomotor-related code to be neater and use Player:BotLocomotor instead of grabbing bot.components.locomotor every time.

* Reworked the behavior tree for modularity and consistency. You can nest priority nodes (tables sorted by numbers) inside of other priority nodes, allowing behaviors to be neatly grouped together. This improves consistency between role behaviors.

* Buyables now test for mod presence before attempting to buy a weapon. There is also the option to define if a weapon is TTT2 specific, but this is optional.

* Added easier support for setting temporary variables in the Memory component.