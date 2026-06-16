# Contributing

Thanks for helping improve AI Toolkit.

## Development Flow

1. Create a feature branch from `main`.
2. Make a focused change with docs or examples when behavior changes.
3. Run the local checks before opening a pull request.
4. Open a PR with a linked issue, a short checklist, and testing notes.

## Local Checks

```bash
bash -n bootstrap.sh
```

If `shellcheck` is installed locally, run:

```bash
shellcheck bootstrap.sh
```

## Pull Request Expectations

- Link the related issue in the PR description.
- Describe the user-facing outcome, not just file changes.
- Call out any bootstrap compatibility risk.
- Keep generated examples realistic and ready to copy into a repo.
