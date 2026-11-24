# Selection and orders

How the player selects units and gives them orders with the mouse. This matches the C# original (`BandoArgentino.cs`).

`PlayerInput` reads the mouse and turns it into `PlayerIntent`s; `ArgentineTeam.handle(_:)` carries them out. Tests: `PlayerInputTests` (mouse → intents, cursor) and `SelectionAndOrderTests` (intents → team).

## Selecting

**Drag selection.** Dragging with the left button draws a rectangle; the units inside it are selected when the button is released.

- The drag must be at least 4 pixels in both directions; smaller drags are ignored.
- It only selects when nothing is selected. In practice the press that starts a drag deselects first (see below).
- A unit is inside when the rectangle covers its sprite's full width, and its height from the middle down to its feet.
- Only the player's units are selected, at most 6 (`Player.maxSelectedUnits`), in the order the team lists them. The rest stay unselected.
- With more than one unit, they leave any group they were in and form a new, selected group. With one, that unit is selected.

**Clicking a unit.** A left click on one of the player's units selects only it.

- If it was in a group, it leaves the group.
- Holding the button while dragging a rectangle is not a click.
- Enemy units can't be selected.

**Deselecting.** A left click anywhere else (empty ground, an enemy) clears the selection.

**Other ways a selection changes.**

- A selected unit that dies is deselected.
- When a selected group is down to one unit, that unit becomes the selection.
- A group that is idle and not selected dissolves.
- The `U` key selects the next unit and centres the camera on it.

## Orders

Orders are given with a right click and go to the selected unit or group. Without a selection, right clicks are ignored.

| Under the pointer | Order |
|---|---|
| A living enemy on a walkable tile | **Attack**: the unit, or every unit of the group, pursues it. |
| Any other walkable tile | **Move** there. A unit walks the A* path. A group first gathers into formation around its commander. An arrow marks the destination for 100 frames. |
| An infirmary | **Heal**, but only if the selection has lost health. The selection walks to the last free tile on the straight line from the infirmary toward it, then recovers. A group's health is the average of its units'. |
| Any other blocked tile | Nothing. |

A click that selects a unit and a right click in the same frame give the order to the newly selected unit.

## Cursor

With nothing selected the cursor is always the normal one. With a selection:

| Under the pointer | Cursor |
|---|---|
| An infirmary, and the selection has lost health | Infirmary |
| An enemy unit | Sword |
| Anything else | Normal |

The sword also shows over dead enemies, although a right click on one moves instead of attacking. The original does the same.
