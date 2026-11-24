# Combat

How units fight, die, heal and patrol. The reference is the C# original (`Unidad.cs`, `Unidades.Ordenes.cs`, `Unidad.EstadoSanando.cs`). Where the port still differs, it's listed at the end.

Tests: `UnitCombatTests` (rules) and `UnitStatsTests` (stats). The differences that matter in play are tests marked as known issues, which describe the original.

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

- An **attack order** (from the player, a group or the AI) makes the unit chase the enemy until it's in range, then shoot.
- In range, the unit turns toward the enemy and shoots every `Intervalo_Entre_Ataques` frames. Each shot always does the full `Puntos_Ataque` damage; there is no accuracy roll. Each shot plays the shot sound of the unit's side.
- If the enemy moves out of range, the unit chases it again.
- When the enemy dies, the unit goes idle.
- Ordering an attack on a dead or dying unit leaves the unit idle.

**Fighting back.** A unit that starts being shot fights back only if it's idle and the attacker is within its range. Moving, chasing or healing units don't fight back.

**Attacking on sight.** Every frame, idle and patrolling units attack an enemy they can see (within `Visibilidad` tiles).

## Dying

- A unit with no health left starts dying: it plays its death animation once and stays on the last frame.
- A Patricio's death plays the death sound.
- After 150 frames (`Unit.Constants.deathFrameCount`) it's dead and is removed from the map.
- Dying units count as dead: they can't be attacked, and a selected one is deselected.

## Healing

A unit sent to an infirmary (see [selection-and-orders.md](selection-and-orders.md)) walks there and then recovers `Puntos_De_Recuperacion` health every `Ticks_Entre_Recuparacion` frames until it's back to full health, then goes idle.

## Patrolling

Enemy units without a group patrol. Each patrol walks to a random walkable tile 8 to 15 tiles from where the unit started, in both directions, then picks another. The unit attacks any enemy it sees on the way.

## Differences from the original

| | Original | Port |
|---|---|---|
| Chasing | Stays in the chase: the path is updated when the enemy moves, and the unit shoots as soon as it's in range. | Walks to the tile where the enemy was, then goes idle; it only attacks again if it sees an enemy from there. *(known issue in the tests)* |
| Healing speed | Counts each frame twice, so a recovery comes every 26 frames instead of 50. | Waits the full 50 frames. *(known issue in the tests)* |
| Range | Shoots only when closer than the range; at exactly the range it chases. | A chasing unit shoots at exactly the range too, and an attacking one keeps shooting there. |
| First shot | Comes one frame after the interval. | Comes on the interval's last frame. |
| Death | Dead after 151 frames. Every dying unit plays the Patricio death sound, British ones included. | Dead after 150 frames. Only Patricios play it. |
| After a kill | The attacker goes idle on the frame of the killing shot. | It goes idle one frame later. |
