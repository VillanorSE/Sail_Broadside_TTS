# Sail & Broadside: Tabletop Simulator mod

Scripted TTS version of Sail & Broadside v0.8.2.4. See [DESIGN.md](DESIGN.md) for the plan and rulings, and [docs/](docs/) for the rules.

## Layout

| Folder | Contents |
| --- | --- |
| `rules/` | Pure Lua game rules, no TTS calls |
| `data/` | Faction ships, crews and bonuses |
| `tts/` | TTS glue: UI, drawing, Global script entry (`tts/global.lua`) |
| `tests/` | Unit tests for `rules/` |
| `tools/` | Bundler and TTS smoke test |
| `config.lua` | Rules values that may still change |

## Commands (from the repo root)

```bash
lua tests/run.lua
```

```bash
lua tools/bundle.lua
```

```bash
lua tools/tts_smoke.lua
```

`tests/run.lua` takes an optional name filter, e.g. `lua tests/run.lua wind`. The bundler writes `build/Global.lua`, one file with every module inlined (TTS has no `require`). The smoke test runs that bundle through a full 6-turn game against a fake TTS API.

## Loading into Tabletop Simulator

1. Run the bundler, then `lua tools/make_save.lua`. This writes `Sail_Broadside_Dev.json` into the TTS Saves folder with the script inside.
2. In TTS: **Games > Save & Load**, open **Sail & Broadside (dev)**.
3. The control panel appears top right. The table border and wind indicator are drawn as lines.

After a rebuild, re-run both commands and load the save again. Pasting into **Modding > Scripting > Global** and clicking **Save & Play** only works in a game that was loaded from a save; on a fresh table TTS says "no save found".

If something breaks, copy the red error text from the TTS chat window or the scripting console.
