# Battle flow

The screens a battle goes through, and when it switches between them. The reference is the C# original (`Episodio.cs`, `Episodio.EstadoCargando.cs`, `Episodio.EstadoMostrarIntroduccion.cs`, `Episodio.EstadoJugando.cs`), including its quirks.

`BattleFlow` holds these rules; `Episode` loads the battle, updates it and draws each screen.

Tests: `BattleFlowTests`.

```
loading → showIntro → playing ⇄ showObjectives
                         ↓
                     won / lost → end
```

## Loading

Loading takes one step per frame:

1. The HUD, the camera, the map and the `Battlefield`.
2. The map file and the level file (`nivel/nivel_N.xml`).
3. The sprites.
4. The buttons and the unit types.
5. The obstacles.
6. Both teams.
7. The player's units.
8. Three frames that do nothing.
9. The enemy units.

Then the battle runs one frame of play, gives the first objective, switches from the splash music to the battle music, and shows the intro.

## Intro

Each battle has three pages of text (`StringID.introPages`). The intro shows the first two, the first one in the title font. **Next** turns the page, and after the second page the battle starts.

## Objectives

The level file lists each battle's objectives, which are given one at a time. When an objective is given:

- the player's team receives it (the ring and the arrow pointing at it);
- the objectives popup is due, and the count of frames played restarts.

After **51 frames of play** the objectives popup opens over the paused battle, showing the battle's third page. **Accept** goes back to playing. From then on, the objective reminder (`StringID.objectiveReminders`, by the number of completed objectives) is shown in the corner. While a new objective's popup is due, the reminder is hidden.

When the player completes the objective, the next one is given:

- If it belongs to the next battle, that battle's intro is shown first.
- If there are none left, the battle is won.

The original checks whether the popup is due while drawing the battle, which every screen draws behind its own. The port does the same.

## Winning and losing

- **Won** shows "You won" and a **Next** button, which ends the battle and goes back to the main menu.
- The battle is **lost** when the player has no units left, checked every frame of play. "You lost" is shown, and after 51 frames a menu asks whether to play again. **Yes** loads the battle again from the start, and **No** goes back to the main menu.

The in-game menu button only works while playing.

## Cheats

While playing, the keys pressed each frame are read and then cleared. Typed one letter at a time:

| Keys | Effect |
|---|---|
| G A N X W | Wins the battle |
| P E R X W | Loses the battle |
| O B J X W | Skips to the next objective |

Any other key resets all three. **U** also selects the next unit.

As in the original, O B J X W isn't reset when it works. The next key resets it, so typing it again right away needs one extra key first.
