# Sail & Broadside TTS: agent guide

This repo is the **Tabletop Simulator implementation** of Sail & Broadside
v0.8.2.4. It implements the owner's existing rules. Do not redesign,
rebalance or "improve" the game; if a rule is ambiguous, ask the owner (quote
the rule, give the fewest plausible readings, recommend one) and record the
answer in `docs/DECISIONS.md`.

## Read first

- `docs/DECISIONS.md`: owner rulings by ID. They override the rulebook. Never re-decide a `Decided` entry.
- `docs/STATUS.md`: what works and the milestone plan.
- `DESIGN.md`: architecture and how each system is meant to work.
- `docs/rules_v0.8.2.4.md`: rulebook text (the docx in `docs/` is authoritative; tables are flattened here).
- `docs/BUGS.md`, `docs/ASSETS.md`, `docs/RULEBOOK_ERRATA.md` as needed.

Decision order: owner ruling > DECISIONS.md > rulebook > existing tested behavior > inference (flag it) > ask.

## Layout and rules of the road

```
rules/    pure Lua game logic; never calls TTS; dice are injected
data/     factions, ships, crews (later captains, upgrades, scenarios, assets)
tts/      thin glue: UI, spawning, drawing, event handlers
tests/    unit tests for rules/ and data/
tools/    bundle.lua, tts_smoke.lua, make_save.lua
config.lua  rules values still in flux
```

- New rules code gets unit tests. New TTS code gets smoke-test coverage.
- Rule values go in `config.lua` or `data/`, not inline.
- Cite decision IDs in comments where code implements a ruling (`-- D-016`).
- Don't restructure working code for looks.

## Pipeline (all from the repo root; Lua 5.4 is on PATH)

```
lua tests/run.lua [filter]   # unit tests
lua tools/bundle.lua         # build/Global.lua; fails on Lua 5.3+ syntax
lua tools/tts_smoke.lua      # full game against a fake TTS API
lua tools/make_save.lua      # writes Sail_Broadside_Dev.json to the TTS Saves folder
```

All four must pass before asking the owner to test in TTS. No agent can run TTS.

## TTS / MoonSharp constraints

- Lua 5.2: no `//`, `goto`, bitwise operators, `utf8`, `math.type`, two-argument `math.atan` (use `math.atan2` with a fallback). Tests run on 5.4, so the bundler checks for these.
- No `require` in TTS: the bundler inlines modules into one Global script.
- Save & Play fails on a fresh unsaved table; load the generated save instead.
- XML UI shows entities literally: set text containing `&` with `UI.setValue`. `UI.setXml` applies next frame; defer value updates with `Wait.frames`.
- Object buttons: use rotation `{0,180,0}` so text reads from behind the ship; counter-scale by `1/object scale`.
- Convert world points with `obj.positionToLocal`.
- Table height varies: the mod uses `Table_None` and its own sea block at `config.table.surface_y`.
- `Global.setVectorLines` replaces all lines; table, wind and move preview are drawn in one call.
- Locked objects can't be dragged: ships lock after Start Game and unlock only while moving.
- Saves: `onSave` returns `JSON.encode(State)`; `State.version` gates old saves. Bump it when the state shape changes. Keep State JSON-safe: string keys or proper arrays, no functions, no NaN/inf.

## Working with the owner

- Owner-facing test requests: which save to load, numbered steps, what should happen, what would count as a failure. No implementation detail unless asked.
- Bugs go in `docs/BUGS.md`; reproduce them in a test before fixing where practical.
- Commit in small logical pieces; commit TTS-visible changes after the owner confirms them in TTS, then push to `origin/main`.

## Agents

Role definitions are in `.claude/agents/`. The lead session owns the roadmap,
DECISIONS.md, integration and commits; subagents own their folders and hand
back a summary of what changed and what was tested.
