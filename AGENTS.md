# AGENTS.md - AI Agent 行为规范

## 用户只需要做 2 件事

```
1. 运行一次: ./init.sh
2. 下达命令: "实现 FTP 适配器"
```

**AI 全自动完成所有工作。**

---

## 角色定义

- **Executor**: 执行具体代码实现
- **Supervisor**: 边界验证、审查门、快照管理、错误记录

## 启动流程（必须执行）

当用户下达命令时，**必须**按以下顺序执行：

```
1. 创建任务: ai-toolkit/scripts/task.sh create "<任务名称>" F-001 HIGH '["src/**"]'
2. 获取返回的 task_id（如 T-001）
3. 调用: ai-toolkit/scripts/supervisor.sh start <task_id>
4. 阅读输出的【强制执行】指令
5. 按指令顺序执行
```

**注意**: task_id 由 task.sh create 自动生成，不要硬编码。

## 五阶段流转

```
DIRECTIVE → PLAN → EXECUTE → REVIEW → COMPLETE
```

每个阶段通过调用 `supervisor.sh gate <phase>` 进入下一阶段。

## 禁止事项

- 禁止直接实现代码（必须先启动 supervisor）
- 禁止跳过 validate.sh check-files
- 禁止跳过 review.sh check
- 禁止修改 ai-toolkit/**, build/**, .gradle/**, .idea/**
