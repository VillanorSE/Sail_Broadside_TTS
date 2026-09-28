# Bug Log

Bugs the owner reports from TTS, and bugs found by tests. Each fixed bug gets
an automated regression test where practical, named after its ID
(e.g. `B-003` in the test name) so it can be found with
`lua tests/run.lua B-003`.

Subsystems: rules, logic, TTS integration, geometry, UI, save/state, asset,
TTS limitation.

| ID | Observed | Expected | Steps to reproduce | Evidence | Subsystem | Reproduced? | Regression test | Fix | TTS verified | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B-001 | Turn button during a backward move that can't turn would crash the handler (`why` was nil) | Refusal message | Backward mode, press a Turn button when the allowance is used up | Smoke test, found before release | TTS integration (`tts/move.lua` dropped the reason) | Yes | Smoke test turn-4 backward nudge | Pass the refusal reason through | Pending M1 check | Fixed |

No open bugs.
