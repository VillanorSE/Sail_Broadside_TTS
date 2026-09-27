# Decision Record

The owner's rulings on how the TTS mod implements Sail & Broadside v0.8.2.4.
**These override the rulebook where they conflict.** Agents check here before
asking a rules question, and never re-decide an entry with status `Decided`.

To add a ruling: take the next ID, fill every field, set status `Decided`
once the owner has answered, and link the tests that pin it down. If a ruling
changes, mark the old entry `Superseded by D-0xx` rather than editing it.

Statuses: `Decided` (ruled, may not be implemented yet), `Implemented`
(ruled, coded and tested), `Open` (waiting on the owner), `Superseded`.

Rulebook wording that should change in the docx is tracked separately in
[RULEBOOK_ERRATA.md](RULEBOOK_ERRATA.md). That is for the owner's tabletop
project; this project only implements.

## Index

| ID | Topic | Status |
| --- | --- | --- |
| D-001 | Durability roll comparison | Decided |
| D-002 | Armor then hull, every hit on left or right armor | Decided |
| D-003 | Head-on / tail-on to-hit | Decided |
| D-004 | Tail-on durability penalty | Decided |
| D-005 | Critical hits | Decided |
| D-006 | Defeated ship drift distance | Decided |
| D-007 | Dice: script-rolled, defender rolls durability | Decided (attacker side implemented) |
| D-008 | Wind D6 numbering | Implemented |
| D-009 | Mild wind shift | Implemented |
| D-010 | No wind (becalmed) movement | Implemented |
| D-011 | Initiative tie | Implemented |
| D-012 | Movement allowance order | Implemented |
| D-013 | 5th Rate crew | Implemented |
| D-014 | Denrudain 3rd Rate cargo | Implemented |
| D-015 | Becalmed drift | Implemented |
| D-016 | Backward moves may turn | Decided |
| D-017 | Idle drift distance | Decided |
| D-018 | Terrain model | Decided |
| D-019 | Terrain checked along the path, resolved at Confirm | Decided |
| D-020 | Land contact during a move | Decided |
| D-021 | Stuck at the start of an activation | Decided |
| D-022 | Starter terrain set | Decided |
| D-023 | Versatility / Range Control and the tail-on durability penalty | Decided |
| D-024 | Asset creation workflow | Decided |
| D-025 | Asset hosting | Decided |
| D-026 | Ship bases are flat generated tiles for now | Implemented |
| O-001 | Obstruction versus head-on / tail-on | Open (needed before Stage 4) |

---

## D-001 Durability roll comparison
- **Date:** 2026-09-24 (recorded from design discussion)
- **Question:** How does a durability roll negate a hit?
- **Source:** Rulebook, Health > Durability (wording outdated, see errata)
- **Owner ruling:** D20 + durability modifier **≥ shot damage** negates the hit. Shot damage is 8/10/12/14 by weight, carronade +4, extreme range −2.
- **Affected rules:** shooting / durability
- **Affected implementation:** `config.shooting.durability_saves_on_equal`; future `rules/shooting.lua`
- **Affected tests:** to be written in Stage 4 (boundary: total equal to damage saves)
- **Status:** Decided

## D-002 Armor then hull
- **Date:** 2026-09-24
- **Question:** Where does damage go, and does the rear have armor?
- **Source:** Rulebook, Health > Armor (says the rear has no armor)
- **Owner ruling:** Damage hits the struck side's armor first; overflow carries to hull. Every hit lands on left or right armor. There is no unarmored rear arc.
- **Affected rules:** damage
- **Affected implementation:** `rules/ship.lua` state (`armor.left/right`); Stage 4 damage code
- **Affected tests:** Stage 4
- **Status:** Decided

## D-003 Head-on / tail-on to-hit
- **Date:** 2026-09-24
- **Question:** To-hit modifier for head-on and tail-on shots, and which side is struck.
- **Source:** Rulebook, Shooting
- **Owner ruling:** −2 to hit for both. The struck side is whichever side of the target's centerline the shooter's centerline line is on.
- **Affected implementation:** `config.shooting.head_on_to_hit`, `tail_on_to_hit`
- **Affected tests:** Stage 4
- **Status:** Decided

## D-004 Tail-on durability penalty
- **Date:** 2026-09-24
- **Question:** Does a tail-on shot affect durability?
- **Source:** Rulebook, Shooting ("Tail On +3 mod." table leftover)
- **Owner ruling:** Tail-on targets take −3 on durability rolls, in addition to D-003's −2 to hit.
- **Affected implementation:** `config.shooting.tail_on_durability`
- **Affected tests:** Stage 4
- **Status:** Decided

## D-005 Critical hits
- **Date:** 2026-09-24
- **Question:** What does a critical do?
- **Owner ruling:** One automatic damage plus a durability roll for a second. Firepower (rare) makes crits two damage with no save; Sturdy Ships (common) allows a durability roll against the automatic damage.
- **Affected implementation:** `config.shooting.crit_can_be_saved`
- **Affected tests:** Stage 4
- **Status:** Decided

## D-006 Defeated ship drift
- **Date:** 2026-09-24
- **Question:** How far do defeated ships drift?
- **Source:** Rulebook, Wind Phase > Drift (says wrecks 2") vs Wrecks/Hulls > Drift (1.5")
- **Owner ruling:** Defeated ships drift 1.5" per turn with the wind in the Wind Phase. Wrecks are removed immediately and never drift.
- **Affected implementation:** `config.movement.defeated_drift`; Stage 5 Wind Phase
- **Affected tests:** Stage 5
- **Status:** Decided

## D-007 Dice
- **Date:** 2026-09-24
- **Owner ruling:** All dice are script-rolled and shown to everyone. The defender clicks a Roll Durability button (only their seat, with a host override).
- **Affected implementation:** `rules/dice.lua` (injectable roller); Stage 4 defender button
- **Status:** Decided (script-rolled dice implemented; defender button is Stage 4)

## D-008 Wind D6 numbering
- **Date:** 2026-09-24
- **Owner ruling:** Seen from behind Deployment Zone A, 1 is the near-left corner, then clockwise: 1 SW, 2 W, 3 NW, 4 NE, 5 E, 6 SE. The wind never blows between the deployment zones.
- **Affected implementation:** `config.wind.direction_table`, `blocked_axis`
- **Affected tests:** `tests/test_wind.lua`, `tests/test_config.lua`
- **Status:** Implemented

## D-009 Mild wind shift
- **Date:** 2026-09-24
- **Owner ruling:** A mild shift moves the wind one D6 point (D20 1-10 counterclockwise, 11-20 clockwise), skipping the blocked deployment axis.
- **Affected implementation:** `rules/wind.lua` `shift`; `config.wind.shift_*`
- **Affected tests:** `tests/test_wind.lua`
- **Status:** Implemented

## D-010 No wind (becalmed) movement
- **Date:** 2026-09-24
- **Owner ruling:** When there is no wind, every ship moves at 1x base sail regardless of heading.
- **Affected implementation:** `config.wind.no_wind_multiplier`, `rules/wind.lua` `move_multiplier`
- **Affected tests:** `tests/test_wind.lua`
- **Status:** Implemented

## D-011 Initiative tie
- **Date:** 2026-09-24
- **Owner ruling:** A tie on total goes to the side with more ships running; if that is also tied, re-roll.
- **Affected implementation:** `rules/initiative.lua`
- **Affected tests:** `tests/test_initiative.lua`
- **Status:** Implemented

## D-012 Movement allowance order
- **Date:** 2026-09-26
- **Owner ruling:** 1. base sail minus 1" per Taking on Water; 2. minus ball & chain losses; 3. halved for damaged rigging; 4. times wind attitude (forward only); 5. halved once for crew under 50% or entangled.
- **Affected implementation:** `rules/movement.lua` `allowance`
- **Affected tests:** `tests/test_movement.lua` (allowance cases)
- **Status:** Implemented

## D-013 5th Rate crew
- **Date:** 2026-09-24
- **Source:** Atrytian and Denrudain faction tables say 3
- **Owner ruling:** 5th Rate crew is 4 for every faction.
- **Affected implementation:** `data/factions.lua`
- **Affected tests:** `tests/test_data.lua`
- **Status:** Implemented

## D-014 Denrudain 3rd Rate cargo
- **Date:** 2026-09-24
- **Source:** Denrudain table says 4; Resilient Ships gives +1
- **Owner ruling:** 5.
- **Affected implementation:** `data/factions.lua`
- **Affected tests:** `tests/test_data.lua`
- **Status:** Implemented

## D-015 Becalmed drift
- **Date:** 2026-09-26
- **Question:** A ship elects to drift instead of moving, but there is no wind. Where does it go?
- **Owner ruling:** Nowhere. A ship that drifts while becalmed does not move.
- **Affected implementation:** `rules/movement.lua` `plan_drift` (no `drift_dir` means 0")
- **Affected tests:** `tests/test_movement.lua` (drift cases)
- **Status:** Implemented

## D-016 Backward moves may turn
- **Date:** 2026-09-27
- **Question:** Movement says backward moves are a flat 1/4 of base movement. Can they turn?
- **Source:** Rulebook, Movement
- **Owner ruling:** Backward moves may turn, using the ship's normal turning arc. Allowance: steps 1-3 of D-012, times 1/4, then step 5. Never wind-modified. A ship moves forward or backward in one activation, not both.
- **Affected implementation:** `rules/movement.lua` `plan_backward`; `tts/global.lua` nudges in backward mode
- **Affected tests:** `tests/test_movement.lua`; smoke test backward move
- **Status:** Decided

## D-017 Idle drift distance
- **Date:** 2026-09-27
- **Source:** Rulebook, Movement says 2"
- **Owner ruling:** An active ship that elects not to move drifts 1.5" with the wind (same as defeated ships).
- **Affected implementation:** `config.movement.idle_drift`
- **Affected tests:** `tests/test_config.lua`, `tests/test_movement.lua`
- **Status:** Decided

## D-018 Terrain model
- **Date:** 2026-09-27
- **Owner ruling:** Terrain is a curated set of scripted pieces placed during setup: islands (round, oval and kidney-bean shaped, several sizes) and rough-water patches. Each ship's shallows are computed automatically as the band around each island equal to that ship's base width.
- **Affected implementation:** new `rules/terrain.lua`, `/tts` terrain spawning and drawing
- **Status:** Decided

## D-019 Terrain checked along the path, resolved at Confirm
- **Date:** 2026-09-27
- **Owner ruling:** Shallows and rough water are checked along the actual legal path but rolled only at Confirm Move, not during the preview, so dragging in and out cannot re-roll. Slowed or Stuck can leave the ship short of the preview.
- **Affected implementation:** Stage 3 terrain work
- **Status:** Decided

## D-020 Land contact during a move
- **Date:** 2026-09-27
- **Question:** On a curved path, a corner of the base can sweep over land while the leading edge never touches it. Does that stop the ship?
- **Source:** Rulebook, Movement ("front edge of its base, or ... a portion of the ship's base ending the movement in contact with land")
- **Owner ruling:** The base may sweep over land during the move provided (a) the **leading edge** (front edge; rear edge on backward moves) never overlaps land, and (b) no part of the base overlaps land at the end of the move. The ship stops immediately before the point where either would be broken.
- **Affected implementation:** `rules/terrain.lua` path check
- **Affected tests:** terrain tests (sweep-past allowed, leading-edge contact stops, end overlap stops)
- **Status:** Decided

## D-021 Stuck at the start of an activation
- **Date:** 2026-09-27
- **Question:** A ship that starts its activation in rough water or shallows rolls Stuck. What happens?
- **Owner ruling:** It does not move that activation (the minimum move does not apply).
- **Affected implementation:** start-of-activation terrain check
- **Status:** Decided

## D-022 Starter terrain set
- **Date:** 2026-09-27
- **Owner ruling:** Islands of 3", 4" and 6", two rough-water patch sizes, and one large coastal-town piece for Defend the Coastal Town.
- **Affected implementation:** terrain data; terrain assets
- **Status:** Decided

## D-023 Versatility / Range Control and the tail-on durability penalty
- **Date:** 2026-09-27
- **Owner ruling:** Versatility and Range Control affect only the to-hit modifiers. They do not change the −3 tail-on durability penalty (D-004).
- **Affected implementation:** Stage 4 / Stage 7 bonuses
- **Status:** Decided

## D-024 Asset creation workflow
- **Date:** 2026-09-27
- **Owner ruling:** The visual/asset agent writes a visual specification and image-generation prompts. The owner runs them through an image generator and returns the results for review against the spec.
- **Affected implementation:** `docs/ASSETS.md`, `assets/`
- **Status:** Decided

## D-025 Asset hosting
- **Date:** 2026-09-27
- **Owner ruling:** Images ship as part of the mod and go to the Steam Workshop with it (see ASSETS.md, "How images reach TTS").
- **Affected implementation:** `docs/ASSETS.md`, asset URL table in the mod
- **Status:** Decided

## D-026 Ship bases
- **Date:** 2026-09-24
- **Owner ruling:** Ships are flat generated tiles at the rulebook base sizes (50x100, 40x80, 30x70 mm). Tokens or models can replace them later.
- **Affected implementation:** `tts/ships.lua`, `data/factions.lua` `BASE_MM`
- **Status:** Implemented

---

## Open

## O-001 Obstruction versus head-on / tail-on
- **Question:** Obstructed is −3 to hit and head-on/tail-on is −2, so an obstructed shot can be worse than a head-on one. Keep that, or make them equal?
- **Source:** Rulebook, Shooting; playtest note
- **Needed by:** Stage 4 (shooting)
- **Current value:** `config.shooting.obstructed_to_hit = -3`
- **Status:** Open
