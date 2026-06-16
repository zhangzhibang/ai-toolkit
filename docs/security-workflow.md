# Security Workflow

The toolkit should stay safe by default because it generates executable workflow scripts.

## Current Safety Baseline

- Uses `set -euo pipefail` in generated shell scripts.
- Limits edits through explicit scope validation.
- Keeps review checks in the generated toolkit.

## Maintainer Checklist

- Validate all user-controlled paths before writing files.
- Avoid implicit shell evaluation where possible.
- Prefer explicit error messages over silent fallbacks.
- Treat generated scripts as production code, not throwaway scaffolding.
