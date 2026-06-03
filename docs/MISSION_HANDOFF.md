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

## 2026-06-04: Elimination Objective Prototype

- `TopDownEnemyBase` now supports mission target metadata:
  - `mission_target_id`
  - `mission_target_label`
  - `mission_target_weight`
- Mission-target enemies notify the current level through `notify_mission_enemy_defeated(...)` when they die.
- `TopDownTestLevel` now supports `MissionObjectiveType.ELIMINATION`.
- The test level starts with a marked `MissionGunner` target. Killing it completes the objective; extraction itself is not locked by default.
- The old interact objective scene still exists for future mixed-objective tests, but it is no longer placed in the current top-down test level.

## 2026-06-04: Extraction Is Run-Based, Not Quest-Locked

- Normal run extraction should be available even when the current quest objective is incomplete.
- `TopDownTestLevel.request_extraction(...)` now completes extraction by default regardless of objective progress.
- Quest progress is reported separately at extraction:
  - `QUEST OBJECTIVE COMPLETE` if the active objective was completed.
  - `NO QUEST PROGRESS` if the player extracted without completing it.
- `extraction_requires_objective` remains as an exported test option for special locked-extraction experiments, but its default is `false`.
