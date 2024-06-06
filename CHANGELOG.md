# Changelog

## v1.3

A major feature overhaul.

### Added

- **TTT2** Bots will show their avatars in the top-right when their corpse is revealed. ([#41](https://github.com/thebigsleepjoe/TTT-Bots-2/issues/41))

- **TTT2** Role suppport for Bodyguard ([#37](https://github.com/thebigsleepjoe/TTT-Bots-2/issues/37))

- Added concommand `ttt_bot_nav_gen` to utilize Navmesh Optimizer for quick navmesh generation.

- Added `Decrowding` behavior to main bot classes. This behavior will make bots without the `lovesCrowds` attribute (most bots) try to find less populated areas when they feel too crowded.

### Changed

- Dramatically increased time interval between the Interaction behavior and the crowbar minge behavior. This should prevent the bots from grouping up too much.

- Increased `CommonSense` timer interval for optimization.

- Increased follow distance target so that bots following another player don't keep bumping into them (as much)

### Removed

- Removed concommand `ttt_bot_nav_generate`, as it was outdated.

### Fixed

- Potential bug created when a bot would try to grab a weapon in the world

- Lua error caused by quota trying to kick an uninitialized bot. Oops!

- Lua error related to plymeta:GetDifficulty

- Lua error related to fetching the BotLocomotor in one of the timers

- Fixed caching issue in inventory component which prevented caching from actually working.

## v1.2.2

Very small bugfix.

### Fixed

- A rare bug when a bot leaves could cause an issue with the silly chat system.

## v1.2.1-meta

This version brings mostly nominal changes. I.e., mostly chore tasks which do not effect gameplay. This is to overcome some technical debt and drastically increase long-term maintainability using LuaLS annotations.

This means more features can be developed quicker. The next actual version will likely be a feature release.

This build will probably not be going to steam due to it having minimal gameplay changes.

### Fixed

- Cache WeaponInfo class to prevent unnecessary computation.

- Traitor aggression now properly considers the bot's current rage level.

### Developer Notes

- Added a large number of class definitions and improved commenting across the entire codebase.

- There are no longer linting errors present using LuaLS. Which is saying a lot, as there were probably a hundred or so before these changes.

- Changed `Player:GetMorality` --> `Player:BotMorality` for consistency.

- BStatus is now a public enum, and can be found by querying the TTTBots global for the STATUS field (`TTTBots.STATUS`)

- Removed deprecated Follow.GetVisibleNavs function

- Removed deprecated Follow.GetRandomVisiblePointOnNavmeshTo function. (Holy, that was a long name)

- lib.GetComp is now obsolete. Use `Player:BotCOMPONENTNAME` instead. (e.g., `Player:BotLocomotor`)

- Added hook "TTTBotJoined" which is called AFTER full bot initialization. sv_miscnetwork now depends on this hook.

## v1.2

### Features

- Bots will sometimes nod, shake their head, and look players up and down when approached.

- Bots care about personal space and will get upset if you stay too close for too long. Builds some suspicion every 5 seconds if you're too close.

- **TTT2** Survivalist support. Survivalist bots will buy same (default) store items as if they were a detective.

- Bots can purchase UMP prototype and utilize it properly.

- **TTT2** Bots can use defibs to revive their allies. [This addon](https://steamcommunity.com/sharedfiles/filedetails/?id=2115944312) is required for this to happen.

- Bots can push you away with crowbars if you get too close. Some bots will do this much more often than others.

- Bots will avoid ladders with people on them, assuming there is another reasonable route available

- Bots will back away from people that are trying to melee them

- Bots will reload outside of combat more often, and reload when they can't see their enemy.

### Changes/Rebalances

- Bots will be less likely to target the head or strafe on lower difficulties.

- Placed cvars on shared realm, so clients can see them.

- Rebalanced bot inventory management. Bots will prioritize special weapons (e.g. UMP prototype) over normal weapons.

- Overall bot accuracy rebalance:

  1. Worse accuracy when the bot is moving.
  2. Worse accuracy when their target is moving.
  3. Worse accuracy when the bot or its target is in smoke.
  4. Better accuracy when the bot is stationary.
  5. Better accuracy when shoothing stationary targets.
  6. Focus system like CSGO bots, where they will increase in shooting accuracy when shooting at the same target over time. Affected heavily by personality.

- Decreased time between quote management updates (2.5s -> 1s)

- **TTT2** Improved behavior consistency between custom roles by unifying behavior trees (i.e., clumped together common sequences into priority nodes)

- Bots won't be repelled from one another when at a health station

### Fixed

- Retrying bug that threw errors on SRCDS servers. (#34)

- Bots trying to break unbreakable obstructions. (#33)

- Bot inaccuracy not correctly scaling over distances. It was hard-capped to a lower value than it should be.

- Sending too many net msgs to syncronize bot avatars. (reported per @EntranceJew)

- Bots will place their crosshair closer to the stomach when they lose sight of their enemy.

- No longer EthicalNotify if there are no bots in the game.

- Bots with a melee will no longer slow themselves down by stafing while approaching.

- **TTT2** Jackal will start fights to prevent stalling rounds.

### Developer Notes

This is a more technical explanation of the changes in this version, and contains useful change info for developers.

- Refactored locomotor-related code to be neater and use Player:BotLocomotor instead of grabbing bot.components.locomotor every time.

- Reworked the behavior tree for modularity and consistency. You can nest priority nodes (tables sorted by numbers) inside of other priority nodes, allowing behaviors to be neatly grouped together. This improves consistency between role behaviors.

- Buyables now test for mod presence before attempting to buy a weapon. There is also the option to define if a weapon is TTT2 specific, but this is optional.

- Added easier support for setting temporary variables in the Memory component.

- Locomotor now supports +attack2 for right click actions.
