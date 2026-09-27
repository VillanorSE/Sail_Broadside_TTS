# Status and Roadmap

Keep this current: update it in the same commit that changes what works.
Last updated: 2026-09-27.

## What works in TTS

| Stage | Scope | Status |
| --- | --- | --- |
| 1. Foundation | Table, wind roll and indicator, turn tracker, initiative, script dice | Done, owner-tested |
| 2. Ships on the table | Bases at rulebook sizes, ship state, fleet panel, faction data | Done, owner-tested |
| 3. Movement | Allowance, reach preview, drag-and-snap, nudges, minimum move, backward, drift, scraping | Mostly done; M1 and M2 below remain |
| 4. Shooting | Fire From Here, ghost, modifiers, attacker dice, defender durability, damage, effects | Not started |
| 5. Everything else | Repairs, boarding, objective rolls, defeated drift, wrecks, routing | Not started |
| 6. Scenarios | Deployment zones, objectives, secret objectives | Not started |
| 7. Squadron builder | Captains, idea groups, upgrades, points | Not started |

## Milestones

- **M0 Housekeeping.** Decision record, errata, bug log, asset workflow, CLAUDE.md, agent definitions, Lua 5.2 check in the bundler, real JSON round trip in the smoke test. *Done.*
- **M1 Stage 3 close-out.** Backward moves may turn (D-016); idle drift 1.5" (D-017). *In progress.*
- **M2 Terrain.** `rules/terrain.lua` (island shapes, per-ship shallows, rough water, leading-edge path checks, Slowed/Stuck, land stop per D-020, start-of-activation checks per D-021); TTS terrain placement during setup; starter set per D-022. First asset family: terrain.
- **M3 Stage 4 Shooting.** Needs O-001 answered first.
- **M4 Stage 5.** Then Stage 6 scenarios, Stage 7 squadron builder.
- **Visual track (parallel from M2).** Terrain, then ship tokens, then status markers.

## Known gaps (not bugs)

- Crew under 50% "move or act" is not enforced yet (no actions exist until Stage 4).
- Flooding to 1" or less defeating a ship is not in `rules/ship.lua` yet (Stage 5).
- Defeated-ship drift in the Wind Phase is a stub (Stage 5).
