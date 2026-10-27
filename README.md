# 2D6 Dungeon (Godot)

An unofficial, fan-made Godot 4 take on the core loop of the solo pen-and-paper game
*2D6 Dungeon*: roll two dice to map the dungeon onto graph paper, fight with dice
manoeuvres, and keep pushing deeper. All tables (creatures, weapons, rooms, loot) are
original and simplified. The game isn't a copy of the published rules.

All graphics are drawn in code (no image assets). The map is graph paper, the dice
have pips, and the creature portraits and town are procedural.

## Running

1. Install [Godot 4.3](https://godotengine.org/download) or newer (standard build, no .NET needed).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project).

## The loop

**Town → Dungeon → Explore rooms → Fight / loot → Stairs down or back to town → …**

### Exploring
- Click a glowing door on the map (or use the buttons on the right) to open it.
  The game rolls **2d6**: the first die is the room's width and the second its height.
  If either die is a 1, the space is a **corridor** that runs away from the door.
- If the room doesn't fit, it shrinks. If nothing fits at all, the passage has collapsed.
- Each new space rolls 2d6 on a contents table:

  | 2d6 | Room | Corridor |
  |-----|------|----------|
  | 2 | Trap | Trap (2-3) |
  | 3-4, 9 | Empty | Empty (4-10) |
  | 5, 10 | Treasure | |
  | 6-8 | Creature | |
  | 11 | Shrine (heal and restore shift) | Creature (11-12) |
  | 12 | Creature guarding a hoard | |

- **Traps:** roll 2d6 and get 7+ to avoid them, otherwise take damage.
- **Stairs down:** after 5 rooms, any room rolled on doubles holds the stairs. They're
  guaranteed by room 13, or as soon as no unexplored doors remain.
- Click any visited room to walk back to it. Rooms with a living creature block the way.
- From the entrance or stair landing you can climb back to town.

### Combat
1. **Roll** two attack dice.
2. Spend **shift points** (blue pips) to nudge a die up or down by one pip.
3. Attack:
   - If the dice show a **manoeuvre's pair** (for example Slash on 5-6), it deals the dice total plus its bonus, minus armour, and applies its effect
     (pierce, guard, stun, bleed or drain).
   - **Doubles** are a critical hit: the total plus your level, ignoring armour.
     **Double ones** are a fumble: no damage, and the next hit against you does +3.
   - Otherwise, a **basic strike** deals the higher die minus armour.
4. The creature rolls 2d6 and hits if the total reaches its *hits on* number.
   Double sixes deal double damage.

You can also drink a potion or try to flee (8+ on 2d6), but either one uses your turn.
Winning gives XP, gold and +1 shift. Levelling up raises max HP and shift and
teaches you a new manoeuvre.

### Town
Rest (restores HP and shift), buy potions, upgrade armour, learn manoeuvres, buy new weapons
(each has its own set of manoeuvres), and re-enter at level 1 or your deepest level.

## Project layout

| File | Purpose |
|------|---------|
| `scenes/main.tscn` | Entry scene (one Control running `main.gd`) |
| `scripts/main.gd` | Builds all UI in code and runs the game loop |
| `scripts/dungeon.gd` | Level generation: 2d6 room placement, doors, contents, stairs, pathfinding |
| `scripts/combat.gd` | Combat rules |
| `scripts/player.gd` | Adventurer stats and progression |
| `scripts/game_data.gd` | Tables: weapons, manoeuvres, creatures, room names |
| `scripts/map_view.gd` | Graph-paper map rendering and clicks |
| `scripts/dice_view.gd`, `stat_bar.gd`, `monster_view.gd`, `town_view.gd` | Procedural graphics |

To rebalance or add content, edit the tables in `scripts/game_data.gd`.
