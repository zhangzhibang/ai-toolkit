# Claude Workflow

Claude consumes the generated `CLAUDE.md` as the primary contract for how work should be executed inside a target repository.

## Core Pattern

1. Read `CLAUDE.md`.
2. Create or resume a task.
3. Validate editable scope before edits.
4. Implement changes.
5. Run the review gate before claiming completion.

## Why It Helps

- Keeps long-running tasks structured.
- Makes agent behavior auditable.
- Reduces "I changed the wrong files" mistakes.
