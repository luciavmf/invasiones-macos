# Movement

How units and groups move across the map. The reference is the C# original (`Unidad.EstadoMoviendo.cs`, `Unidad.cs`, `Grupo.cs`). Where the port differs, it's listed at the end.

Tests: `PathFinderTests`, `LineOfSightTests`, `UnitTests`, `UnitOnBattlefieldTests`.

## Paths

Units walk on the **physical grid**, which has twice the map's resolution. Grass and dirt are walkable; obstacles and the fires started by triggers are not.

- A move order asks the pathfinder for the shortest path. It uses A*, with a cost of 10 per straight step and 14 per diagonal step. A diagonal step is only allowed when both straight neighbours are walkable, and a search gives up after 4.5 s.
- With no path, the unit stays idle.
- The unit walks the path one tile at a time. When the path ends, it switches to its next state: idle after a move, healing at an infirmary, or attacking at the end of a chase (see [combat.md](combat.md)).

**Steps.** Each frame the unit moves toward the centre of its next tile at `Velocidad` pixels and faces one of 8 directions. Once it's within one step of the centre it stands on that tile and takes the next one.

**Collisions.** Each frame, a moving unit checks the units within 4 tiles. It collides with one when its next tile is:
- that unit's next tile, if the unit is moving;
- the tile that unit stands on, if it isn't moving.

On a collision it **evades**. It looks for a new path to the next tile of its route that avoids the tiles of the units it can see, then continues on the rest of its route. If that tile can't be reached it tries the following ones, and if none can be reached it stays where it is.

## Groups

A move order to a group happens in two phases.

1. **Grouping.** The first unit is the commander and stops. The others get formation spots in a spiral around the commander, every 2 tiles and only on walkable tiles, and walk there.
2. **Moving.** Once every unit is idle, the commander plans its path to the target. Each other unit follows the commander's path shifted by its formation offset. Where the shifted path is blocked, the unit skips ahead to the next free point (and up to two more) and goes around the blocked part with A*.

The group has arrived when every unit is idle. With a move order, it also counts as arrived as soon as one of its units meets the level's move objective (below). Groups the AI controls then ask it for their next order.

**Healing.** A group sent to an infirmary moves to the last free tile on the line toward its commander. Hurt units start healing as they arrive, and the group is done when everyone is back to full health.

**Losing units.** If the commander dies, the first unit left takes over. A group with one unit left breaks up.

## Move objectives

A level's *move* (and *take object*) objective is met when a unit is fewer than 3 tiles from the objective's tile on each axis (at most 2 rows and 2 columns away). For a group, one unit is enough. Objectives are described in the level files (`nivel/nivel_N.xml`).

## Differences from the original

| | Original | Port |
|---|---|---|
| Steps | A fixed speed on each axis, by direction | Moves straight toward the tile's centre. This change was made on purpose: on isometric tiles the original's equal per-axis speed overshoots the shorter axis and makes units jitter. |
| Evading | Steps back by one frame's movement and re-plans in the same frame | Snaps back to the centre of its tile and re-plans on the next frame |
