# Codex Workflow

AI Toolkit gives Codex a repo-local workflow contract through `AGENTS.md`.

## What Codex Gets

- A directive-to-complete execution model.
- Guardrails for file boundaries and review gates.
- Persistent task, checkpoint, and memory structure.

## Recommended Flow

1. Run `bash ~/.ai-toolkit/bootstrap.sh /path/to/project`.
2. Confirm `AGENTS.md` and `CLAUDE.md` were generated in the target repo.
3. Ask Codex to implement a scoped task.
4. Let Codex drive `task.sh`, `supervisor.sh`, and `review.sh`.

## Good Fit

- Backend feature delivery.
- Multi-step refactors.
- Bug fixing that benefits from checkpoints and review gates.
