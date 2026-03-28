# 自主 AI 开发团队框架设计

**日期**: 2026-03-28
**状态**: 已确认，待实施
**作者**: 用户 + Claude

---

## 概述

构建一套通用框架，使 Claude Code 能够在用户最小介入的情况下，从设计文档出发，自主完成完整的产品开发周期直至生产就绪状态。

### 核心原则

- **用户角色**：提供想法 + 关键决策拍板，不参与日常执行
- **自主范围**：设计文档确认后，全程自动执行
- **介入触发**：AI 主动上报——模糊需求、重大技术选型、意外情况
- **交付标准**：代码完成、测试通过、文档齐全、可部署状态

---

## 系统架构（五层）

```
┌─────────────────────────────────────────┐
│  第一层：想法摄入（已有，复用）            │
│  /brainstorm → 设计文档 → /writing-plans │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  第二层：任务管理                         │
│  PM Agent → tasks/backlog.yml           │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  第三层：Coordinator（定时调度）          │
│  每小时推进 Sprint · 检查阻塞 · 发通知   │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  第四层：执行团队（四个专职 Agent）        │
│  Dev · QA · Architect · Docs           │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  第五层：上报 & 验收                      │
│  NEEDS_REVIEW.md + 桌面通知 → 你拍板    │
└─────────────────────────────────────────┘
```

---

## 与 gstack 的关系

本框架基于 [gstack](https://github.com/garrytan/gstack)（Garry Tan 开源的 28 个专业 Claude Code skill）构建。

| 层级 | 职责 |
|------|------|
| **gstack** | 工具层——定义每个开发步骤的执行方式（/plan, /build, /qa, /ship 等） |
| **本框架** | 编排层——决定做什么、什么时候做、谁来做，自动驱动 gstack skill |
| **用户** | 决策层——输入想法，审批设计文档，偶尔拍板 |

### Sprint 流程（基于 gstack 七步结构）

```
设计文档确认
    ↓ PM Agent 拆解 → backlog.yml
Think  → Architect Agent 审查技术风险
Plan   → 任务细化，依赖排序
Build  → Dev Agent × N（git worktree 并行）
Review → Architect Agent /plan-eng-review
Test   → QA Agent /qa + Playwright
Ship   → /ship → 生产就绪报告
Reflect → Docs Agent 写总结 → 通知用户验收
```

---

## Agent 团队详细设计

### 通用上报协议（所有 Agent 遵守）

遇到以下情况**必须**写入 `NEEDS_REVIEW.md`，不得猜测或自行决定：

- 需求描述有两种以上合理解读
- 修改涉及超过 3 个文件的架构变更
- 引入新的外部依赖
- 改变核心数据结构
- 发现与现有代码的冲突

**上报格式**：
```
[AGENT名称][TASK-ID] 问题简述
选项A：...
选项B：...
建议：选项X，原因：...
```

### PM Agent

- **触发**：设计文档确认后，由用户或 Coordinator 手动触发一次
- **职责**：读取实施计划 → 拆解为原子任务 → 写入 `tasks/backlog.yml`
- **工具**：Read · Write · Glob
- **产物**：`tasks/backlog.yml`（含任务 ID、描述、类型、优先级、依赖关系）

### Architect Agent

- **触发**：Sprint Think/Plan 阶段，以及 Dev Agent 遇到架构问题时
- **职责**：技术选型建议、现有代码与新任务冲突检查、提供实现方案
- **工具**：Read · Glob · Grep · WebSearch（**只读，不写代码**）
- **必须上报**：引入新依赖 · 改变核心数据结构 · 影响跨模块接口的任何决策

### Dev Agent

- **触发**：Coordinator 从 backlog 中分配任务
- **职责**：功能实现、代码编写
- **工具**：Read · Edit · Write · Bash · Glob · Grep
- **开始前必读**：CLAUDE.md → 任务描述 → 相关现有代码
- **完成产物**：实现代码 · 更新任务状态 · 写 `tasks/done/TASK-ID.md` 完成报告

### QA Agent

- **触发**：Dev Agent 完成后自动触发
- **职责**：编写测试、运行测试、验证覆盖率
- **工具**：Read · Write · Bash · Glob · Grep（**不可修改 src/ 生产代码**）
- **完成标准**：测试文件已创建 + `npm test` 全部通过 + 核心路径覆盖率 ≥ 80%
- **上报触发**：测试连续失败 3 次 · 覆盖率无法达标 · 发现范围外 Bug

### Docs Agent

- **触发**：QA Agent 通过后自动触发
- **职责**：更新 README、API 文档、代码注释
- **工具**：Read · Edit · Write · Glob
- **完成产物**：文档更新 + 任务完成总结

---

## 任务文件结构

```
tasks/
  backlog.yml        ← PM Agent 写入，待执行任务列表
  in-progress.yml    ← Coordinator 维护，执行中任务
  done/
    TASK-001.md      ← 每个任务的完成报告
  NEEDS_REVIEW.md    ← 任何 Agent 遇到不确定时写入此处
```

### backlog.yml 任务结构

```yaml
- id: TASK-001
  title: 实现用户登录功能
  type: dev          # dev | qa | docs | arch
  priority: high     # high | medium | low
  status: pending    # pending | in-progress | blocked | done
  depends_on: []
  description: |
    详细需求描述...
  assigned_to: null  # 由 Coordinator 填写
```

---

## Coordinator 调度层

### 三个定时任务

| 任务 | 频率 | 职责 |
|------|------|------|
| **Sprint Coordinator** | 每小时 | 推进任务状态 · 检查阻塞 · 调度 Agent |
| **gstack Auto-Updater** | 每天 3:00 | git pull → 冒烟测试 → 通过静默 / 失败回滚并通知 |
| **Daily Standup** | 每天 9:00 | 汇总进度 → 写日报 → 桌面通知 |

### Coordinator 执行逻辑

```
1. 读取 NEEDS_REVIEW.md → 有内容 → 发桌面通知，等待用户回复
2. 读取 in-progress.yml → 检查超时任务（>2h 无更新）→ 上报
3. 读取 backlog.yml → 取最高优先级 pending 任务
4. 检查依赖是否满足 → 满足则调度对应 Agent
5. 更新 in-progress.yml
```

### gstack 冒烟测试内容

1. 核心 skill 文件存在（/plan, /build, /qa, /ship, /review）
2. Coordinator 依赖的 skill 输出格式未变化
3. dry-run 模式跑一次完整 Sprint 流程

---

## 通知方案

| 场景 | 通知方式 | 内容 |
|------|---------|------|
| 需要拍板 | macOS 桌面通知 + NEEDS_REVIEW.md | 问题 + 选项 + 建议答案 |
| 生产就绪 | 桌面通知 + 日报 | 完成清单 + 测试报告 |
| gstack 更新成功 | 静默 | — |
| gstack 更新失败 | 桌面通知 | 问题描述 + 已回滚版本号 |

---

## 通用性设计

本框架设计为**项目无关**的通用框架：

- Agent 定义放在 `~/.claude/agents/`（全局），不绑定特定项目
- 任务文件结构统一，任何项目均可复用
- gstack 作为全局工具安装在 `~/.claude/skills/gstack`
- 新项目只需：提供想法 → 走 brainstorm → 设计文档 → 框架自动接管

---

## 目录结构（新增部分）

```
~/.claude/
  agents/
    pm-agent.md
    coordinator-agent.md
    dev-agent.md
    qa-agent.md
    architect-agent.md
    docs-agent.md
  skills/
    gstack/              ← git clone 安装
    autonomous-team/     ← 本框架的辅助 skill
      update-gstack.md   ← gstack 更新 + 冒烟测试
      standup.md         ← 日报生成

任意项目/
  tasks/
    backlog.yml
    in-progress.yml
    done/
    NEEDS_REVIEW.md
  docs/standups/         ← 每日 standup 日报
```

---

## 待讨论（实施阶段确认）

- Coordinator 通过何种机制调用子 Agent（Claude Code `Agent` tool vs 独立进程）
- 桌面通知具体实现（`osascript` AppleScript vs 其他）
- gstack 版本锁定策略（tag vs commit hash）
- 多项目并行时 Coordinator 的优先级调度规则
