# Workspace Rules

## Mandatory Git Commit Per Change & Conversation Milestone

- **Always commit verified code changes to `git`**: After every completed feature, fix, rollback, or conversation milestone that modifies EA source or header files in this workspace, compile cleanly (`0 errors`) with MetaEditor and commit the changes locally before wrapping up.
- **Stage only the intended EA files** (never `git add -A`, which can sweep unrelated scratch files, `.log` files, or strategy tester reports into history):
  - Example: `git add V_EMAMULTIPLE_ORDERS.mq4 logger_engine.mqh V_EMAMULTIPLE_ORDERS.ex4` (plus any other explicitly modified tracked files).
- **Pre-edit safety check**: Before starting edits when `git status` has uncommitted changes from an earlier step or external compile, either commit a checkpoint first or note the baseline so rollback via `git` is always exact.
- **Commit message convention**: Match this repository's history by using the active `glbVersion` string when bumping EA versions (e.g., `VMULTI-1148- <short description>`), or a clear concise summary for non-version changes.
- **Keep working tree clean of temporary artifacts**: Remove temporary compile logs in `MQL4\Experts` (write temporary scripts/logs to the artifact `scratch/` folder instead).
- **Local commits by default**: Commit locally on `main` after each completed change; only run `git push` when the user explicitly requests pushing to `origin`.

## Two-Regime Strategy Architecture (|EMA Angle| < 4° vs. >= 4°)

- **Always maintain a 2-regime framework**:
  - **Strategy 1 (Low Angle / Ranging, $|EMA\ Angle| < 4.0^\circ$)**: Designed for sideways/consolidation environments. Uses tighter base order gaps (no heavy drawdown/sweep gap expansion), baseline Method 6 thresholds (1X opposite, 3X same-type), and range-appropriate SL breathing/locking.
  - **Strategy 2 (High Angle / Trending, $|EMA\ Angle| \ge 4.0^\circ$)**: Designed for strong momentum and trend runs. Applies wider protective order gaps (Drawdown Multiplier up to 4X, LSD Sweep Guard 2X), higher Method 6 profit thresholds (2X opposite, 6X same-type), and trend-following SL ratchet/protection.
- **Mandatory Reminder**: Whenever proposing, modifying, reviewing, or analyzing test results for:
  1. **Order Creation** (signals, pending stops/limits, minimum gaps, lot sizing)
  2. **Order Closing** (basket targets, Method 6 combos, partial cuts, flip ladder)
  3. **Order Modify with StopLoss** (breakeven, trailing SL, breathing room, locking winners)
  **Always remind the user and evaluate the logic through these two separate strategies instead of sticking to a single one-size-fits-all rule for all market conditions.**
