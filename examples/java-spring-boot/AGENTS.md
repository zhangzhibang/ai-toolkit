# AGENTS.md - Codex Behavior

Read `CLAUDE.md` first, then execute the generated workflow in this repository.

## Repository Expectations

- Use `scripts/task.sh` to create or resume work.
- Use `scripts/validate.sh check-files` before edits.
- Use `scripts/review.sh check` before completion.
- Keep generated toolkit files in sync with project conventions.

## Spring Boot Notes

- Prefer `./mvnw` or `./gradlew` over system-wide tooling when the repo provides wrappers.
- Keep the compile command fast enough for frequent review runs.
