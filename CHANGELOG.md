# Changelog

## v1.2

* Added: Bots will nod, shake their head, and look players up and down when approached.

* Added: Bots care about personal space and will get upset if you stay too close for too long.

* Added: Bots will take into effect if you/they are in smoke by having considerably worse accuracy.

* Added: Bot accuracy will slowly improve while shooting at the same target for a long time. This prevents situations where bots are unable to hit a target that is standing still for several seconds.

* Fixed: reworked the behavior tree for modularity and consistency.

* Fixed: Retrying bug that threw errors on SRCDS servers. (#34)

* Fixed: Bots trying to break unbreakable obstructions. (#33)

* Fixed: Bot accuracy not correctly scaling over distance.
