# CLAUDE.md - AI 工作流工具箱

**你是一个自主的 AI 编码 Agent。每次人类给你一个开发任务，你必须自己驱动整个工作流。**

## 强制工作流

```
用户下达命令
      │
      ▼
1. DIRECTIVE: 读取 memory/session-history.md, catalog/errors.json, instructions/directive.md
2. PLAN: 制定计划, validate.sh check-files, checkpoint.sh save
3. EXECUTE: 实现代码, 每次改文件前 validate.sh check-files
4. REVIEW: review.sh check
5. COMPLETE: checkpoint.sh save, task.sh done, supervisor.sh stop
```

## 硬性约束

1. 每次改文件前必须 validate.sh check-files
2. 完成前必须 review.sh check 通过
3. 编译必须通过
4. 不允许 TODO/FIXME/NotImplemented
5. 不允许 return null; 作为最终返回值

## 禁止区域

- `<TOOLKIT>/**` - 工作流自身
- `build/**` - 构建输出
- `.gradle/**` - 缓存
- `.idea/**` - IDE 配置
