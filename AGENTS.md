# Workspace Rules

## Mandatory Git Commit Per Change & Conversation Milestone

- **Always commit verified code changes to `git`**: After every completed feature, fix, rollback, or conversation milestone that modifies EA source or header files in this workspace, compile cleanly (`0 errors`) with MetaEditor and commit the changes locally before wrapping up.
- **Stage only the intended EA files** (never `git add -A`, which can sweep unrelated scratch files, `.log` files, or strategy tester reports into history):
  - Example: `git add V_EMAMULTIPLE_ORDERS.mq4 logger_engine.mqh V_EMAMULTIPLE_ORDERS.ex4` (plus any other explicitly modified tracked files).
- **Pre-edit safety check**: Before starting edits when `git status` has uncommitted changes from an earlier step or external compile, either commit a checkpoint first or note the baseline so rollback via `git` is always exact.
- **Commit message convention**: Match this repository's history by using the active `glbVersion` string when bumping EA versions (e.g., `VMULTI-1148- <short description>`), or a clear concise summary for non-version changes.
- **Keep working tree clean of temporary artifacts**: Remove temporary compile logs in `MQL4\Experts` (write temporary scripts/logs to the artifact `scratch/` folder instead).
- **Local commits by default**: Commit locally on `main` after each completed change; only run `git push` when the user explicitly requests pushing to `origin`.
