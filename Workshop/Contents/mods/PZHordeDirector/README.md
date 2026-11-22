# PZ Horde Director

Standalone B42 roaming-horde experiment.

- virtual squads move toward players/NPCs;
- vanilla swarms spawn in waves around a squad;
- entering a building spawns extra zombies inside;
- a wiped squad respawns at the edge with one zombie and grows to the configured size;
- Mod Options: number of hordes (1–8), max size, interval, radius, player/NPC targeting,
  house infection, fence/rope/crawl flags, edge reset.

Current limits:
- fence/rope/crawl options set available zombie flags; they do not add a custom
  pathfinder for ropes;
- squads are virtual centers, not a new engine-level group AI.

Install: copy this folder to `~/Zomboid/mods/PZHordeDirector`, enable in the save
mod list. No dependencies.
