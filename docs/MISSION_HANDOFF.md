# Mission Handoff

## 2026-06-04: Prototype Mission/Extraction Loop

- `scenes/levels/top_down_test_level.tscn` now has a minimal mission loop.
- `MissionObjective` is placed as the prototype objective. Interacting with it completes `prototype_cache`.
- `ExtractionPoint` is placed near the starting side. It stays locked until the objective is complete.
- After the objective is complete, interacting with the extraction point shows `MISSION COMPLETE`.
- `MissionStatusHud` shows the current objective, short mission messages, and the completion overlay.
- Level-level mission state lives in `scripts/levels/top_down_test_level.gd`.

## Current Scope

- This is a prototype loop only.
- There is no reward screen, save persistence, result summary, extraction timer, or item-based objective validation yet.
- The next useful step is deciding whether objectives should be interact-based, item-based, kill-based, or mixed.
