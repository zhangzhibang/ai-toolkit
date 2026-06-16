# Review Workflow

The built-in review path is intentionally simple and predictable.

## Gate Order

1. `validate.sh check-files`
2. `review.sh check`
3. Fix violations
4. Re-run review

## Current Review Coverage

- Forbidden path checks
- Placeholder scans
- Compile command execution when configured

## Recommended Future Enhancements

- Test command execution as a separate stage
- Markdown lint for generated docs
- More explicit unsafe shell-pattern detection
