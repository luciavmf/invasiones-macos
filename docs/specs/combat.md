# Combat

How units fight, die, heal and patrol, matching the C# original (`Unidad.cs`, `Unidades.Ordenes.cs`, `Unidad.EstadoSanando.cs`), including its quirks.

Tests: `UnitCombatTests` (rules) and `UnitStatsTests` (stats).

## Stats

Each unit type's stats come from its `unidades/*.csv` file, read into `UnitStats`. A unit starts at full health.

| CSV key | Stat | Patricio | British |
|---|---|---|---|
| `Puntos_Resistencia` | Maximum health | 100 | 50 |
| `Puntos_Ataque` | Damage per shot | 20 | 20 |
| `Alcance_Tiro` | Attack range (tiles) | 8 | 8 |
| `Intervalo_Entre_Ataques` | Frames between shots | 30 | 20 |
| `Visibilidad` | Sight (tiles) | 10 | 10 |
| `Velocidad` | Speed (pixels per frame) | 2 | 2 |
| `Punteria` | Accuracy, never used | 5 | 5 |
| `Puntos_De_Recuperacion` | Health per recovery | 20 | (20) |
| `Ticks_Entre_Recuparacion` | Frames between recoveries | 50 | (50) |

Missing or invalid values fall back to the defaults in brackets. `Tipo` and `Modo` are in the files but not read.

## Attacking

- An **attack order** (from the player, a group or the AI) makes the unit chase the enemy. The path is recalculated whenever the enemy changes tile, and the unit starts shooting as soon as it's **closer than** its range; at exactly the range it keeps chasing. If no path reaches the enemy, the unit goes idle.
- While attacking, the unit turns toward the enemy whenever it moves, and chases it again if it leaves the range.
- A shot comes one frame after each `Intervalo_Entre_Ataques` frames (the original compares the count before increasing it). Each shot always does the full `Puntos_Ataque` damage; there is no accuracy roll. It plays the shot sound of the unit's side (Patricio or British).
- When its shot kills the enemy, the unit goes idle on the same frame. If someone else kills it, the unit goes idle on its next frame.
- Ordering an attack on a dead or dying unit leaves the unit idle.

**Fighting back.** A unit that starts being shot fights back only if it's idle and the attacker is within its range. Moving, chasing or healing units don't fight back.

**Attacking on sight.** Every frame, idle and patrolling units attack an enemy they can see (within `Visibilidad` tiles).

## Dying

- A unit with no health left starts dying. On its next frame it plays its death animation once (staying on the last frame) and the death sound. The original only has the Patricio's death sound and plays it for every unit, British ones included.
- On the 151st frame (`Unit.Constants.deathFrameCount` is 150, checked before counting) it's dead and is removed from the map.
- Dying units count as dead: they can't be attacked, and a selected one is deselected.

## Healing

A unit sent to an infirmary (see [selection-and-orders.md](selection-and-orders.md)) walks there and then recovers `Puntos_De_Recuperacion` health until it's back to full health, then goes idle. The original counts each frame twice against `Ticks_Entre_Recuparacion`, so with 50 ticks a recovery comes every 26 frames.

## Patrolling

Enemy units without a group patrol. Each patrol walks to a random walkable tile 8 to 15 tiles from where the unit started, in both directions, then picks another. The unit attacks any enemy it sees on the way.
