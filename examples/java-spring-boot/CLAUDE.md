# CLAUDE.md - Spring Boot Workflow

You are working in a Spring Boot repository bootstrapped by AI Toolkit.

## Default Flow

1. Read repository context.
2. Create a task.
3. Plan the change.
4. Validate file scope before each edit.
5. Run compile or tests before review completion.

## Build Hints

- Typical compile command: `./mvnw -q -DskipTests compile`
- Typical test command: `./mvnw -q test`
- Keep generated docs and agent instructions updated when the workflow changes.
