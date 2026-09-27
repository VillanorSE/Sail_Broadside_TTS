# Sail & Broadside TTS Mod: Project Handoff

Prepared 2026-09-27 from the Claude Code working session. The purpose of this document is to brief another assistant on the project so it can propose an agent-based structure for the rest of the build.

---

## 1. What this project is

**Sail & Broadside** is a tabletop miniatures wargame of age-of-sail ship combat, written by the project owner (Victor Fernandes, GitHub `VillanorSE`). The current ruleset is **v0.8.2.4**.

This project is a **scripted Tabletop Simulator (TTS) mod** of that game. The goal is a playable digital version where the script handles the tedious parts (wind, turn order, movement limits, shooting maths, dice, damage, effects, repairs, boarding, scoring). Players still move ships by hand, but only to legal positions.

- Repo: https://github.com/VillanorSE/Sail_Broadside_TTS (branch `main`)
- Language: Lua. TTS runs MoonSharp, which is **Lua 5.2 compatible**. Tests run under standalone **Lua 5.4**.
- Owner's role: game designer and rules authority. They test in TTS and make every rules ruling. They are not writing the code.
- Builder so far: Claude Code (an AI coding agent) writing all code, with the owner testing in TTS and reporting back.

---

## 2. Sources of truth

| Source | Location | Notes |
| --- | --- | --- |
| Rulebook | `docs/Sail And Broadside V0.8.2.4.docx` | Authoritative rules text. |
| Rulebook (text) | `docs/rules_v0.8.2.4.md` | Extracted for reading by tools; tables flattened, diagrams lost. |
| Design doc | `DESIGN.md` | Architecture, build stages, and the **Rules Decisions** table. Decisions there override the docx where they conflict. |
| This handoff | `docs/HANDOFF.md` | Snapshot of status and working knowledge. |

The owner also keeps a ChatGPT/Claude chat project with earlier design discussion. Anything decided there that isn't in `DESIGN.md` needs to be copied into the repo to be visible to coding agents.

---

## 3. Architecture

```
/rules/     Pure Lua game logic. No TTS calls. Plain tables in, plain tables out.
/data/      Faction ships, crews, bonuses (later: captains, upgrades, scenarios, objectives)
/tts/       Thin TTS glue: UI, object spawning, drawing, event handlers
/tests/     Unit tests for /rules and /data
/tools/     bundle.lua, make_save.lua, tts_smoke.lua
config.lua  Rules values still in flux (one-line edits when rules change)
```

Principles:
1. **Rules never touch TTS.** Everything testable lives in `/rules`.
2. **Dice are injectable.** Rules take a dice roller, so tests use fixed or seeded rolls; TTS passes the real RNG.
3. **`/tts` stays thin.** It converts TTS objects and positions into plain tables and back.
4. **Rule values live in `config.lua` and `/data`**, not hard-coded.

### Build and test pipeline

| Command (repo root) | What it does |
| --- | --- |
| `lua tests/run.lua [filter]` | Unit tests (92 passing as of this handoff). |
| `lua tools/bundle.lua` | Inlines every required module into `build/Global.lua`, since TTS has no `require`. |
| `lua tools/tts_smoke.lua` | Runs the bundle against a **fake TTS API** through a full 6-turn game: adding ships, moving with drag/drop/nudge/confirm, scraping, deleting a ship, save/reload, new game. Catches nil calls and typos before the owner loads anything. |
| `lua tools/make_save.lua` | Writes a TTS save file (`Sail_Broadside_Dev.json`) into the owner's TTS Saves folder with the script embedded. The owner loads it via Games > Save & Load. |

### The key constraint

**No agent can run Tabletop Simulator.** Every change is verified by unit tests and the fake-TTS smoke test, then the owner loads the save in TTS and reports what they see (often with screenshots). Keeping `/tts` thin over well-tested `/rules` keeps these round trips short.

---

## 4. Build stages and status

| Stage | Scope | Status |
| --- | --- | --- |
| 1. Foundation | Table, wind roll and indicator, turn tracker, initiative, script dice, test harness | **Done**, tested in TTS |
| 2. Ships on the table | Generated flat bases at rulebook sizes, ship state (armor per side, hull, crew, effects, cannons), fleet status panel, faction data | **Done**, tested in TTS |
| 3. Movement | Wind-attitude allowance, reach preview, drag-and-snap legal moves, heading nudges, minimum move, backward, drift, scraping | **Mostly done**, committed; needs the corrections in section 6 and terrain |
| 4. Shooting | "Fire From Here" mid-move with a ghost, target selection, line of fire, range, obstruction, modifiers, attacker dice, defender-only Roll Durability, armor-then-hull damage, damage effects | Not started |
| 5. Everything else | Repairs, boarding, objective rolls, defeated drift, wrecks, routing | Not started |
| 6. Scenarios and secret objectives | Deployment zones, objective scoring, secret objective deck, scenario setup | Not started |
| 7. Squadron builder | Captains and idea groups, upgrades, points validation (250 ship + 50 upgrade) | Not started |

### What works in TTS today
- **Setup:** a spawned 48"×48" sea on a darker surround. The host adds ships per side (faction, rate and crew dropdowns), then clicks **Start Game**, which hides setup controls and locks ships.
- **Wind:** condition and D6 direction rolled at start; Wind Phase changes each turn. An arrow indicator with an "N" sits off the east edge.
- **Turns:** initiative, with ties broken by ships running, then a re-roll. Sides alternate activations, then the Wind Phase, for 6 turns.
- **Ships:**
  - bases with a centre cross line and an X marking the wind-attitude boundaries, plus a small bow arrow;
  - a name label and a context button (Move, then Done, then Activated);
  - a fleet panel listing each ship's status.
- **Movement:** click Move, then drag the ship. The reach outline, minimum-move outline, planned path and landing outline draw live. The ship snaps to the legal spot on release. Heading nudges, Forward/Backward/Drift modes, and Confirm or Cancel come from the panel. Contact with another ship stops the move and triggers an entanglement roll at each ship's next activation.

---

## 5. Rules decisions already made (authoritative)

These are recorded in `DESIGN.md` Section 4. Agents must not re-decide them.

| Topic | Decision |
| --- | --- |
| Durability roll | D20 + durability modifier **≥ shot damage** negates the hit. |
| Armor / hull | Damage hits the struck side's armor first, and overflow goes to hull. Every hit lands on left or right armor (no unarmored rear). |
| Head-on / tail-on | −2 to hit for both. Tail-on also takes −3 on durability rolls. The struck side is whichever side of the target's centerline the shooter's line is on. |
| Critical hits | One automatic damage plus a durability roll for a second. |
| Defeated ship drift | 1.5" per turn in the Wind Phase. |
| Dice | Script-rolled. The defender clicks to roll durability. |
| Wind D6 numbering | Seen from behind Deployment Zone A: 1 is the near-left corner, then clockwise (1 SW, 2 W, 3 NW, 4 NE, 5 E, 6 SE). |
| Mild wind shift | One D6 point clockwise or counterclockwise (D20: 1-10 CCW, 11-20 CW). |
| No wind (becalmed) | Every ship moves at 1x base sail. |
| Initiative tie | More ships running wins; if that's also tied, re-roll. |
| Movement allowance order | 1. base sail minus 1" per Taking on Water; 2. minus ball & chain; 3. halved for damaged rigging; 4. times wind attitude; 5. halved once for crew under 50% or entangled. |
| 5th Rate crew | 4 for every faction (fixes the Atrytian and Denrudain tables). |
| Denrudain 3rd Rate cargo | 5 (fixes the table). |
| Becalmed drift | A ship that drifts while there is no wind doesn't move. |

---

## 6. Pending work already decided (not yet implemented)

The owner gave these rulings after the last Stage 3 build. They are **not in the code yet**:

1. **Backward moves can turn.** They are limited to 1/4 of base movement (after steps 1-3 of the allowance order, then halved per step 5 if applicable), never wind-modified. The code currently allows straight backward moves only.
2. **Drift is 1.5" with the wind** for an active ship that elects not to move. The code currently uses 2" (`config.movement.idle_drift`).
3. **Terrain** (approved plan): scripted terrain pieces placed during setup:
   - islands: round, oval and **kidney-bean shaped**, in a few sizes;
   - rough water patches;
   - each ship's **shallows** computed automatically around islands at that ship's base width, per the rules;
   - checks along the actual path at Confirm Move: shallows and rough water tables by ship rate, and stopping before land.
4. **Record rulings 1 and 2 in `DESIGN.md`.** It still says backward moves are straight and drift is 2".

---

## 7. Open questions still needing the owner

- **Obstruction versus head-on/tail-on:** obstructed is −3 to hit and head/tail-on is −2. Keep that, or make them equal?
- **Rulebook text to fix in the docx** (listed in `DESIGN.md` Section 5): drift wording, durability wording, the "Tail On +3 mod." table leftover, the rear-armor statement, and whether the "From Behind" secret objective now requires armor to be depleted first.
- **Whether Versatility / Range Control bonuses affect the tail-on durability penalty.** Currently assumed not.

---

## 8. Hard-won technical notes (TTS quirks)

Any agent writing `/tts` code needs these:

- **Lua version:** MoonSharp is Lua 5.2. No two-argument `math.atan` (use `math.atan2` with a fallback), no `//`, no `goto`, no bitwise operators.
- **No `require` in TTS:** use `tools/bundle.lua`, which builds one Global script with a local module loader.
- **Save & Play needs a save:** it fails on a fresh unsaved table ("no save found"). Use `make_save.lua` and load the save instead.
- **XML UI shows entities literally:** `&amp;` appears as-is, so set text containing `&` with `UI.setValue`. `UI.setXml` applies on the next frame, so defer value updates with `Wait.frames`.
- **Object button text** reads upside down at rotation `{0,0,0}` from behind a ship; use `{0,180,0}`. Buttons scale with their object, so they are counter-scaled by `1/object scale`.
- **Object-local positions:** convert world points with `obj.positionToLocal` rather than guessing scale behaviour.
- **Table height varies between built-in tables.** The mod uses `Table_None` plus its own spawned sea block at a known height, so lines draw reliably.
- **`Global.setVectorLines` replaces all lines** every call. Table, wind and move preview are composed into one call.
- **Locked objects can't be dragged by players.** Ships lock after Start Game and unlock only while moving.
- **Save state:** `onSave` returns `JSON.encode(State)`, and the version field gates loading old saves.

---

## 9. Working agreements with the owner

- **Rules questions:** the owner decides. Agents surface ambiguities as short questions with a recommended answer, then record the ruling in `DESIGN.md` and add a test.
- **Every rules change gets a unit test.** Every TTS change must pass the smoke test before the owner is asked to load it.
- **Commits:** make them after the owner confirms something works in TTS, and push to `origin/main`.
- **Owner-facing replies:** short, with exact steps to try in TTS and what they should see.

---

## 10. What we're asking for

Please propose an **agent-based structure** for finishing this project (stages 3-7 and beyond). It should build on the constraints above:
- a single human tester who is also the rules authority;
- no agent can run TTS;
- pure-rules and TTS-glue layers are cleanly separated, with automated tests for both.

Natural seams that may help:
- **Rules agent:** `/rules` and `/data`, plus their tests.
- **TTS integration agent:** `/tts`, the smoke-test fakes, the bundle and the save file.
- **Rules-librarian agent:** rulebook questions, `DESIGN.md` decisions, docx mismatch tracking.
- **QA / verification agent:** test coverage and smoke scenarios, and turning the owner's TTS reports into reproducible cases.

Useful things to define:
- how agents hand work to each other (for example: the rules agent finishes and tests, then the TTS agent integrates, then the owner tests);
- how rulings get captured so no agent re-litigates them;
- how in-TTS bug reports flow back.
