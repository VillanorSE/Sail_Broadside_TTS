# Bug Log

Bugs the owner reports from TTS, and bugs found by tests. Each fixed bug gets
an automated regression test where practical, named after its ID
(e.g. `B-003` in the test name) so it can be found with
`lua tests/run.lua B-003`.

Subsystems: rules, logic, TTS integration, geometry, UI, save/state, asset,
TTS limitation.

| ID | Observed | Expected | Steps to reproduce | Evidence | Subsystem | Reproduced? | Regression test | Fix | TTS verified | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B-001 | Turn button during a backward move that can't turn would crash the handler (`why` was nil) | Refusal message | Backward mode, press a Turn button when the allowance is used up | Smoke test, found before release | TTS integration (`tts/move.lua` dropped the reason) | Yes | Smoke test turn-4 backward nudge | Pass the refusal reason through | Yes (owner, 2026-10-05) | Fixed |
| B-002 | Hovering a ship shows a zoomed pop-up that covers the Move button | Move/Done easy to click | Hover a ship base during its activation | Owner report, 2026-10-05 | UI / TTS limitation (hover pop-up) | No (not reproducible outside TTS) | Smoke test: ship tooltip off; odd turns activate via panel buttons | Ship hover tooltip turned off; Move/Done buttons for the side to activate added to the panel | Pending | Fix built |

Open: B-002 (awaiting TTS check).
