# Java Spring Boot Example

This example shows how to bootstrap AI Toolkit into a Spring Boot service repository.

## Bootstrap

```bash
git clone https://github.com/zhangzhibang/ai-toolkit.git ~/.ai-toolkit
cd /path/to/spring-boot-service
bash ~/.ai-toolkit/bootstrap.sh .
```

## Expected Result

- `AGENTS.md`
- `CLAUDE.md`
- `scripts/`
- `memory/`
- `instructions/`

## Suggested Project Config

Update `config.json` after bootstrap:

```json
{
  "compile_cmd": "./mvnw -q -DskipTests compile",
  "test_cmd": "./mvnw -q test",
  "forbidden_patterns": [],
  "placeholder_patterns": ["TODO", "FIXME", "NotImplemented", "return null;"],
  "language": "java"
}
```
