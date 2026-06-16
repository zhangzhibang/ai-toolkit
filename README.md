# AI Toolkit

AI Toolkit is a lightweight bootstrapper for repositories that want repeatable AI coding workflows.

It generates `AGENTS.md`, `CLAUDE.md`, task scripts, review gates, checkpoint storage, and memory scaffolding so Codex or Claude can work inside a repo with explicit rules instead of ad hoc prompting.

## Positioning

Use this when you want AI agents to behave more like disciplined contributors than one-shot assistants.

Good fits:

- backend or internal service repos
- repos with multi-step feature work
- teams that want review gates and checkpoints
- solo maintainers who want structured AI execution

## Installation

### Option 1: clone locally

```bash
git clone https://github.com/zhangzhibang/ai-toolkit.git ~/.ai-toolkit
```

### Option 2: run the bootstrap script directly

```bash
curl -sSL https://raw.githubusercontent.com/zhangzhibang/ai-toolkit/main/bootstrap.sh | bash -s -- /path/to/your/project
```

## Quick Start

```bash
cd /path/to/your/project
bash ~/.ai-toolkit/bootstrap.sh .
```

After bootstrap, your project gets:

- `AGENTS.md`
- `CLAUDE.md`
- `scripts/`
- `memory/`
- `instructions/`
- `catalog/`
- `checkpoints/`

Then you can ask your agent to do real work, for example:

```text
实现 FTP 适配器
```

## Workflow Summary

```text
User request
  -> task creation
  -> planning
  -> file-scope validation
  -> implementation
  -> review gate
  -> completion
```

## Repository Contents

- [docs/codex-workflow.md](docs/codex-workflow.md)
- [docs/claude-workflow.md](docs/claude-workflow.md)
- [docs/review-workflow.md](docs/review-workflow.md)
- [docs/security-workflow.md](docs/security-workflow.md)
- [docs/release-v0.1.0.md](docs/release-v0.1.0.md)
- [docs/roadmap.md](docs/roadmap.md)
- [examples/java-spring-boot/README.md](examples/java-spring-boot/README.md)
- [功能说明书.md](功能说明书.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CHANGELOG.md](CHANGELOG.md)

## Built-in Scripts

| Script | Purpose |
|------|------|
| `task.sh` | task lifecycle |
| `supervisor.sh` | stage gates |
| `validate.sh` | file boundary checks |
| `review.sh` | placeholder and compile review |
| `checkpoint.sh` | save and restore checkpoints |
| `catalog.sh` | record repeated errors |
| `log.sh` | operation audit log |
| `state.sh` | current state |
| `self-improve.sh` | summarize recurring errors |

## Real Maintenance Signals

This repository now includes:

- issue templates for roadmap, docs, security, and features
- a PR template with linked issue and review checklist
- GitHub Actions CI for `bash -n` and `shellcheck`
- release notes and changelog structure
