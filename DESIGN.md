# Sail & Broadside: Tabletop Simulator Mod Design

Target ruleset: **Sail & Broadside v0.8.2.4** (the rules docx in this repo is the source of truth). The owner's rulings live in [docs/DECISIONS.md](docs/DECISIONS.md) and override the docx where they conflict.

This project implements the existing game in TTS. It does not redesign or rebalance the rules; ambiguities go to the owner as questions and the answers are recorded in DECISIONS.md.

Implementation language: **Lua** (Tabletop Simulator scripting), with rules logic kept in pure Lua so it can be unit tested outside TTS.

---

## 1. Goals and Scope

- Script a playable digital version of Sail & Broadside for Tabletop Simulator.
- Automate the tedious parts: wind, turn tracking, shooting modifiers and dice, durability, damage, effects, repairs, boarding, scoring.
- Keep movement physical and natural: players drag their ships, but only to places the ship can legally reach.
- **Flat bases for now.** Ships are generated as flat tiles at the base sizes below. Ship tokens, terrain art and markers are being added through the asset workflow in [docs/ASSETS.md](docs/ASSETS.md).
- **Script-rolled dice** (no physical dice), so results are fast, consistent, and visible to everyone.

### Non-goals (for now)
- Sound and 3D ship models.
- AI opponents.
- Arbitrary freeform terrain. Shallows and rough water need known footprints, so terrain will be a curated set of island and zone objects.

---

## 2. Architecture

```
/rules/     Pure Lua, no TTS calls. Fully unit tested.
            wind, dice, crew status, shooting, durability, damage, effects,
            repairs, boarding, routing, movement geometry
/data/      Factions, ships, crews, captains, idea groups, upgrades, scenarios,
            secret objectives
/tts/       TTS glue only: object spawning, UI/buttons, cursor-constrained
            movement, path drawing, ghosts, per-seat defender rolls, undo
/tests/     Tests for /rules (run with a standalone Lua interpreter)
config.lua  Flags and values for rules that are still in flux
DESIGN.md   This file
```

Principles:
- **Rules logic never touches TTS.** `/rules` takes plain tables in and returns plain tables out (including the dice results), so it can be tested with hundreds of cases outside the game.
- **Dice are injectable.** `/rules` receives a dice function so tests can use fixed or seeded rolls; TTS uses the real RNG.
- **`/tts` stays thin.** It converts between TTS objects/positions and the plain tables `/rules` uses.
- **Rules that may change live in `config.lua`**, so a rules change is a one-line edit.

The main limitation: TTS itself cannot be run by Claude Code, so in-game testing is done by the user, who reports errors back. Thin glue over tested logic should keep those rounds short.

---

## 3. Core Design Decisions

### 3.1 Ship bases
Flat generated tiles, semi-transparent-capable, at the rulebook base sizes:

| Ship | Base |
| --- | --- |
| 1st / 2nd Rate | 50mm x 100mm |
| 3rd / 4th Rate | 40mm x 80mm |
| 5th Rate / Frigate | 30mm x 70mm |

Transparency on 3D objects in TTS is inconsistent, but tiles with a semi-transparent image are reliable. Script-drawn outline lines are the fallback.

### 3.2 Movement: cursor-constrained dragging along a legal path

TTS cannot hard-limit an object the player is physically holding, so the **player's pointer drives the ship** and the script clamps it to what is reachable.

Flow:
1. Player clicks **Begin Move**. The script records start position and heading and computes the ship's **movement allowance** (see below).
2. The script draws the reachable area and shows the legal path (arc, then straight) as the pointer moves.
3. The ship follows the pointer but is held at the edge of the reachable area, like dragging against an invisible wall.
4. **Heading:** by default the ship faces along the cheapest legal path to the pointer position. Left/right **nudge buttons** bias the final heading within what is reachable.
5. Player clicks **Confirm Move** (or continues via Fire From Here, below).

**Allowance** = base sail x wind attitude multiplier, modified by flooding ("Taking on Water", -1" each to unmodified sail), damaged rigging (halved), ball & chain reductions, and crew status.

| Attitude | Wind relative to ship | Multiplier |
| --- | --- | --- |
| Running | < 30 degrees off stern | 1x |
| Reaching | 30-90 degrees off stern | 1.5x |
| Beating | 30-90 degrees off bow | 0.5x |
| Against | < 30 degrees off bow | 0.25x |

Attitude is fixed at the **start of the turn** and applies for the whole move. Movement Mastery captain bonuses alter these multipliers (see rules).

**Turning:** ships have a minimum turn arc of 3", 4" or 5" (a quarter circle, i.e. a 90-degree turn). Minimum turn radius = `2L / pi` (about 1.91", 2.55", 3.18"). Wider turns are always allowed. Legal reachable poses are computed from the shortest curved path (Dubins-style) and checked against the allowance.

**Other movement rules to script:**
- Minimum move of 2" (or full movement if the modified value is under 2"). If a ship elects not to move, it drifts 1.5" with the wind (D-017); becalmed, it does not move (D-015).
- Backward move: may turn with the normal arc (D-016); 1/4 of base movement after allowance steps 1-3, then halved per step 5; never wind-modified; cannot combine with forward movement.
- Crew under 50%: the ship either moves or acts, not both (see 3.6).
- Land contact (D-020): the base may sweep over land, but the leading edge (rear edge when backward) may not touch it and no part of the base may overlap it at the end of the move; the ship stops immediately before either happens. A later full-movement activation can turn it up to 90 degrees to sit tangential to the land.
- **Scraping:** ship-to-ship contact stops the mover. On each involved ship's next activation, a repair roll (free, not counting as the activation) decides entanglement; failure means half speed.
- **Shallows and rough water** are checked **along the actual legal path**, but **resolved at Confirm Move**, not during the preview. This stops players dragging in and out of a zone to re-roll. A ship that starts its activation in rough water or shallows checks first; Stuck means it does not move that activation (D-021). If a check results in Slowed or Stuck, the ship ends short of where the preview showed. Rough water and shallows each have their own tables by ship class in the rules.

An optional **waypoint mode** can be added later for contested paths.

### 3.3 Shooting: Fire From Here, ghost, defender-rolled durability

**Declaring the shot (mid-move):**
1. During a move, the attacker clicks **Fire From Here**.
2. The script spawns a **ghost**: a mostly transparent copy of the ship at the exact position and heading, tinted in the owner's colour and locked (cannot be grabbed and does not bump other objects).
3. The attacker picks the target and shot type (standard, grapeshot, ball & chain).
4. The script locks in **line of fire, range band, obstruction, head-on/tail-on, and all modifiers** as measured from the ghost, and shows the target number. A line is drawn from the ghost's centerline to the target with range band and line-of-fire status.
5. If the target is out of range or line of fire at declaration, the script warns the player. Per the rules, the shots then miss.
6. The real ship continues its move with the **remaining allowance**.

**Resolving the shot (after the move is confirmed):**
1. The attacker's dice are rolled by the script (one D20 per cannon, grouped by cannon weight) and **shown to everyone**: hits, criticals, misses.
2. The **defender's seat gets a "Roll Durability" button** that only that colour can click. It rolls one D20 per hit, shows the results, and applies damage.
3. Damage effects roll automatically and the ship's status panel updates.

Multiplayer safety: a **host override** if the defender is away, and an **undo** for misclicks.

**The ghost** stays on the table until the defender has rolled durability and damage is applied. It disappears if the move is undone or cancelled. (One-line config change if it should vanish as soon as the attacker's dice are rolled instead.) Only one shooting action per activation means at most one ghost per ship at a time.

**Firing at a target is one action per activation**, and the ship also gets its move. Shooting may occur at any point during a move.

### 3.4 Hit resolution (to-hit)

A shot hits on a D20 roll **equal to or less than** the modified gunnery target number. A roll **exactly equal** to the target number is a **critical** (extended critical range from bonuses extends downward).

Target number = crew Gunnery + range modifier (by cannon/shot type) + faction/captain bonuses + situational modifiers.

**Range bands** (inches): Point Blank 0-4, Near 4-8, Middle 8-12, Far 12-16, Extreme 16-20.

| Range | PB | Near | Mid | Far | Extreme |
| --- | --- | --- | --- | --- | --- |
| Standard cannon | +4 | +2 | 0 | -3 | -6 |
| Carronade | +3 | +1 | -2 | -5 | -8 |
| Ball & chain | -12 | -10 | -8 | -6 | -8 |
| Grapeshot | -2 | -4 | -6 | -9 | -12 |

**Situational modifiers:**

| Situation | To-hit modifier |
| --- | --- |
| Target one class larger | +1 per class |
| Target one class smaller | -1 per class |
| Head on / tail on | -2 (tail-on also takes a -3 durability modifier, see 3.5) |
| Grounded / stuck target | +2 |
| Entangled (with an enemy ship) | -2 |
| Obstructed | -3 |
| Damaged gun ports (firing ship) | -3, stacks to a maximum of two |

Size classes: 1st/2nd = large, 3rd/4th = medium, 5th/frigate = small.

**Line of fire:** extend a line along the centerline of the shooter's base; if it intersects any part of the target's base, the target can be shot. **Range** is measured from the center of the nearest long side of the shooter's base to the nearest point of the target base. **Head on / tail on:** the shooter's centerline line intersects the target's front or rear narrow side. In that case, which side of the target takes the hit depends on which side of the target's centerline the shooter's line is more on.

**Obstruction:** less than half of the target's base visible from the shooter's centerline-nearest point. Implemented by sampling points across the target base and raycasting against terrain and ships; this is approximate. The ruling on obstruction versus head/tail-on is open (O-001 in DECISIONS.md).

### 3.5 Durability and damage

**Shot damage:**

| Cannon weight | Standard | Carronade (+4) |
| --- | --- | --- |
| Light | 8 | 12 |
| Medium | 10 | 14 |
| Heavy | 12 | 16 |
| Super Heavy | 14 | 18 |

- Extreme range: **-2** damage on all cannon shots (Long Range Combat, common, removes this for all shot types).
- Firepower (common): +1 damage on standard shots.

**Durability roll (one per hit):** roll a D20, add the ship's **durability modifier** to the result. If the modified total is **equal to or greater than the shot damage**, the hit is negated (no armor or hull damage).

- **Tail-on targets take a -3 modifier on the durability roll** (fragile cabin end of the ship). This is in addition to the -2 to-hit penalty that applies to all head-on and tail-on shots.
- **Special shots** (grapeshot, ball & chain) may be rolled against for durability, but the ship's durability modifier does **not** apply. Versatility and Range Control bonuses can add modifiers against special shots.
- Heavy Timbers adds +2 to durability rolls (+1 more with Sturdy Ships, common).

**Applying damage (each unsaved hit = 1 damage):**
1. Determine the **struck side**. For a broadside shot, it is the side facing the shooter. For a **head-on or tail-on** shot, it is whichever side of the target's centerline the shooter's centerline is on.
2. Damage goes to that side's **armor** first.
3. When that side's armor is gone, remaining damage **carries over to hull**.
4. Each **hull damage** point rolls once on the Damage Effect table.

Every hit therefore lands on left or right armor first; there is no unarmored arc in this model (D-002; the rulebook still says the rear has no armor, see RULEBOOK_ERRATA.md).

**Critical hits:** a crit causes one immediate point of damage and also gets a durability roll. If the roll fails, the crit does a total of two damage; if it succeeds, one. Overflow rules apply as normal, so a crit can take a side's last armor point and then a hull point. Captain bonuses change this: Firepower (rare) makes crits automatically two damage with no save; Sturdy Ships (common) allows a durability roll against the normally automatic damage.

**Special shot damage:** grapeshot and ball & chain do no armor or hull damage. Every unsaved grapeshot hit kills one crew; every unsaved ball & chain hit reduces movement by 1".

**Damage effect table (D20):**

| Roll | Effect |
| --- | --- |
| 1-2 | No additional effect |
| 3-5 | Fire |
| 6-8 | Flooding |
| 9-11 | Damaged gun ports (-3 to shooting, stacks max two) |
| 12-14 | Damaged guns (one weight of guns destroyed, owner's choice) |
| 15-17 | Damaged rigging (base movement halved) |
| 18-20 | Crew death (D2 crew) |

**Hull states:**
- Hull damage equal to hull value: ship is **Defeated** (surrendered). It drifts 1.5" per turn in the wind direction during the Wind Phase.
- Hull at -2 or below: ship is a **Wreck** and is **removed immediately**; cargo and captains float in the water in the footprint of its base.
- Flooding to 1" or less of movement: defeated, removed during the drift phase on the second turn after.

### 3.6 Crew status
Compared against the ship's **base** crew value (extra crew berths do not raise the baseline):
- 50% or more: normal (move plus one action).
- Under 50%: **either** move (half speed) and fire with half the cannons (rounded down) **or** conduct a crew/objective roll at -5 to the target number.
- 25% or less: ship abandoned.

### 3.7 Turn structure
1. **Initiative:** one player per side rolls D20 plus captain initiative bonuses. Highest goes first. Ties go to the side with more ships in the "running" attitude.
2. **Activation:** players alternate, one ship at a time until every ship has activated once. Each activation is a move plus one action (shoot, repair, board, or objective roll). Objective and boarding actions happen before or after moving, not part way through.
3. **Wind Phase:** defeated ships drift (1.5"), then the wind roll for the next turn.

Game lasts **6 turns**, or ends the turn a player is **routed** (at the start of their turn they have half or fewer of their total game points remaining, rounded up). Captured ships count per the routing rules.

### 3.8 Wind
- Wind condition is rolled once at game start (D20: 1-5 Calm, 6-15 Fair Weather, 16-20 Rough Seas).
- Initial direction: D6, and the wind blows from the rolled point to the opposite side or corner; the wind never blows directly between the two deployment zones.
- Each Wind Phase: roll a D20 on the condition's table (no wind, steady, mild shift, or squall). Shifts: 1-10 counterclockwise, 11-20 clockwise. Squalls re-roll direction on a D6.
- A **wind indicator** rotates on the table to match.
- The Cargo Must be Recovered scenario forces a squall every turn.

### 3.9 Boarding, repairs, objectives
- **Boarding:** a ship contacts a long side of another (auto-rotation up to 90 degrees to the side minimizing rotation). Both sides roll one D20 per crew; successes at or under the boarding target number count, criticals count double; the loser loses crew equal to the difference in successes. Multi-ship boarding and surrender/capture crew-splitting rules are scripted per the rules.
- **Repairs:** one D20 against the crew Repair value; success removes one hull damage and one effect (chosen before the roll); critical removes one more. Fire, flooding and ball & chain movement loss are repairable by default; damaged rigging and damaged guns require upgrades.
- **Objective rolls:** D20 against crew Objective value, positional requirements per scenario.

---

## 4. Rules Decisions

Moved to [docs/DECISIONS.md](docs/DECISIONS.md), one entry per ruling with an ID (D-001, D-002, ...), its source, affected code and tests, and status. Refer to rulings by ID in code comments and commit messages.

---

## 5. Open Items

- Open rules questions: the "Open" section of [docs/DECISIONS.md](docs/DECISIONS.md).
- Rulebook wording that disagrees with the rulings: [docs/RULEBOOK_ERRATA.md](docs/RULEBOOK_ERRATA.md).
- Known bugs: [docs/BUGS.md](docs/BUGS.md).

**Rules in flux (keep in `config.lua`):** head/tail-on modifiers, drift distances, durability comparison (equal or exceed), ghost lifetime, ability of critical hits to be saved.

---

## 6. Build Stages

**Stages 1-4 produce a playable mod.**

1. **Foundation:** table, wind roll and indicator, turn tracker, initiative, script-rolled dice, test harness.
2. **One ship on the table:** generated flat base, state for armor per side, hull, crew and effects, and a status panel.
3. **Movement:** wind-attitude allowance, reachable-area preview, cursor-constrained dragging along the legal path, heading nudges, 2" minimum move, shallows/rough water/scraping resolved at confirm along the real path.
4. **Shooting:** Fire From Here with ghost, target selection, locked line of fire/range/obstruction/modifiers, finish move, attacker dice shown, defender-only Roll Durability button, armor-then-hull damage, automatic damage effects.
5. **Everything else:** repairs, boarding, objective rolls, wrecks and defeated-ship drift, routing check.
6. **Scenarios and secret objectives:** deployment zones, objective scoring, secret objective deck, scenario setup.
7. **Squadron builder:** faction data, captains and idea groups, upgrades, points validation (250 ship points plus 50 upgrade points by default; unused ship points can become upgrade points, not the reverse).

## 7. Testing Strategy

- Unit tests for everything in `/rules`: wind tables and shifts, attitude multipliers, crew status thresholds, to-hit modifier stacking, range bands, durability (equal-or-exceed boundary cases), tail-on penalties, armor/hull overflow, crit handling, damage effect table, repair and boarding outcomes, routing calculations.
- Geometry tests for the movement solver: turn radius, reachable set boundaries, minimum move, backward move, heading edge cases.
- Fixed and seeded dice for reproducible cases.
- In-game testing by the user; errors and screenshots pasted back for fixes.

## 8. Known Risks

- **Obstruction sampling** is approximate.
- **Cursor-driven movement** feel will need tuning in-game.
- **Transparency** of ghosts depends on TTS rendering; tiles first, outlines as fallback.
- **Terrain footprints** for shallows and rough water require curated terrain objects.
- **Rules still changing** (v0.8.x): keep rule values in config and data files, not hard-coded.
