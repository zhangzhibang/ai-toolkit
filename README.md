# AI Toolkit

AI 工作流工具箱 - 一键初始化，全自动开发流程。

## 一句话安装

```bash
# 克隆到本地
git clone https://github.com/zhangzhibang/ai-toolkit.git ~/.ai-toolkit

# 进入你的项目目录
cd /my/project

# 初始化（生成 CLAUDE.md, AGENTS.md 等）
bash ~/.ai-toolkit/bootstrap.sh
```

## 一行命令（无克隆）

```bash
curl -sSL https://raw.githubusercontent.com/zhangzhibang/ai-toolkit/main/bootstrap.sh | bash
```

## 使用流程

```
用户: "实现 FTP 适配器"
    ↓
AI 自动: 读取 CLAUDE.md/AGENTS.md → 创建任务 → 制定计划 → 实现代码 → 审查 → 完成
```

## 特性

- **Claude Code / Codex 自动识别** - 文件生成到项目根目录
- **零配置** - 只需运行一次
- **强制工作流** - 阶段门控、边界验证、错误学习
- **跨 Session 记忆** - 中断后可恢复

## 文件结构

```
/项目目录/
├── CLAUDE.md              ← Claude Code 自动读
├── AGENTS.md              ← Codex 自动读
├── scripts/               ← 9个脚本
├── memory/                ← 跨 session 记忆
├── instructions/           ← 五阶段指令
└── ...
```

## 脚本说明

| 脚本 | 用途 |
|------|------|
| task.sh | 任务管理 |
| supervisor.sh | 监督控制 |
| validate.sh | 边界验证 |
| review.sh | 代码审查 |
| checkpoint.sh | 快照保存/恢复 |
| catalog.sh | 错误目录 |
| log.sh | 操作日志 |
| state.sh | 状态读写 |
| self-improve.sh | 自我改进 |

## 文档

- [功能说明书.md](功能说明书.md) - 人类使用指南
- [CLAUDE.md](CLAUDE.md) - AI 工作流规范
- [AGENTS.md](AGENTS.md) - Agent 角色定义
