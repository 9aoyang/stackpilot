# Stackpilot 自主 AI 开发团队框架设计

**日期**: 2026-03-28（修订：2026-03-29）
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
                  ↓ 设计文档 commit 自动触发
┌─────────────────────────────────────────┐
│  第二层：任务管理                         │
│  PM Agent → tasks/backlog.yml           │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  第三层：Coordinator（事件驱动调度）      │
│  切换分支时触发 · 检查阻塞 · 推进 Sprint │
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
| **gstack** | 工具层——定义每个开发步骤的执行方式 |
| **stackpilot** | 编排层——决定做什么、什么时候做、谁来做，自动驱动 gstack skill |
| **用户** | 决策层——输入想法，审批设计文档，偶尔拍板 |

### Sprint 流程（基于 gstack 七步结构）

stackpilot 实际使用的 gstack skill：`/plan-eng-review`、`/qa`、`/qa-only`、`/ship`、`/review`、`/investigate`

> `/plan-ceo-review`、`/cso` 等其他 gstack skill 可按需手动调用，不纳入自动化流程。

```
设计文档 commit
    ↓ 自动触发 PM Agent → backlog.yml
Think  → Architect Agent 审查技术风险（/investigate）
Plan   → 任务细化，依赖排序（/plan-eng-review）
Build  → Dev Agent × N（git worktree 并行）
Review → Architect Agent 审查（/review）
Test   → QA Agent（/qa + Playwright）
Ship   → /ship → 生产就绪报告
Reflect → Docs Agent 写总结 → 通知用户验收
```

---

## Agent 团队详细设计

### 通用上报协议（所有 Agent 遵守）

遇到以下情况**必须**写入 `tasks/NEEDS_REVIEW.md`，不得猜测或自行决定：

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

### 用户回复机制

用户收到桌面通知后，直接编辑 `tasks/NEEDS_REVIEW.md`，在末尾追加：

```
REPLY: 选项B
```

Coordinator 下次运行时检测到 `REPLY:` 行，读取回复 → 清空文件 → 继续执行。

### 错误恢复机制

所有 Agent 执行结果必须写入任务状态：

- **成功**：更新状态为 `done`，写 `tasks/done/TASK-ID.md`
- **失败**：更新状态为 `failed`，写入错误信息，Coordinator 下次运行时上报
- **超时**（>2h 无状态更新）：Coordinator 强制标记为 `failed`，写入 `tasks/NEEDS_REVIEW.md`

---

### PM Agent

- **触发**：设计文档 commit 后，由 git post-commit hook 自动触发（检测到新的 `docs/specs/*.md`）
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
- **完成产物**：实现代码 · 更新任务状态为 `done` · 写 `tasks/done/TASK-ID.md`
- **失败处理**：连续失败 2 次 → 写入 `tasks/NEEDS_REVIEW.md`，标记任务为 `blocked`

### QA Agent

- **触发**：Dev Agent 完成后自动触发
- **职责**：编写测试、运行测试、验证覆盖率
- **工具**：Read · Write · Bash · Glob · Grep（**不可修改 src/ 生产代码**）
- **完成标准**：测试文件已创建 + 测试全部通过 + 覆盖率 ≥ 项目配置阈值（默认 80%，可在 `stackpilot.config.yml` 中覆盖）
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
  NEEDS_REVIEW.md    ← 上报问题 + 用户 REPLY: 回复
  done/
    TASK-001.md      ← 每个任务的完成报告
```

### backlog.yml 任务结构

```yaml
- id: TASK-001
  title: 实现用户登录功能
  type: dev          # dev | qa | docs | arch
  priority: high     # high | medium | low
  status: pending    # pending | in-progress | blocked | done | failed
  depends_on: []
  description: |
    详细需求描述...
  assigned_to: null  # 由 Coordinator 填写
```

### stackpilot.config.yml（项目级配置）

```yaml
qa:
  coverage_threshold: 80    # 覆盖率阈值，百分比
  test_command: npm test

coordinator:
  worktree_limit: 3         # 最大并行 Dev Agent 数量
```

---

## Coordinator 调度层

### 触发方式

Coordinator 是一个通过 `claude -p`（headless 模式）运行的独立进程，**不是** subagent。通过两个 git hook 触发：

```bash
# .git/hooks/post-checkout（切换分支时触发，是进入仓库工作的自然入口）
claude -p "运行 Stackpilot Coordinator：读取 tasks/ 目录，推进 Sprint，处理阻塞"

# .git/hooks/post-commit（每次 commit 后）
# 检测本次 commit 是否新增 docs/specs/*.md → 若是则触发 PM Agent
# 检测逻辑：git diff HEAD^ HEAD --name-only | grep "^docs/specs/.*\.md$"
claude -p "检测新设计文档，若本次 commit 新增了 docs/specs/*.md 则运行 PM Agent 拆解任务到 tasks/backlog.yml"
```

> `post-checkout` 不是"打开文件夹"事件，而是 `git checkout` / `git switch` 时触发。首次进入仓库（`git clone` 后）也会触发一次，覆盖主要使用场景。

### 每周维护任务（cron，周一 3:00）

```bash
# 仅用于 gstack 更新，频率降低
git -C ~/.claude/skills/gstack pull --ff-only
# 验证核心 skill 文件存在：/plan-eng-review, /qa, /ship, /review
# 有更新则写入日志，失败则通知用户 + 自动回滚
```

### Coordinator 执行逻辑

```
1. 读取 tasks/NEEDS_REVIEW.md
   → 有 REPLY: 行 → 解析回复，清空文件，恢复对应任务
   → 有未回复问题 → 发桌面通知，本次跳过该任务
2. 读取 tasks/in-progress.yml（不存在则创建空文件）
   → 检查超时任务（>2h 无更新）→ 标记 failed，写 tasks/NEEDS_REVIEW.md
3. 读取 tasks/backlog.yml → 取最高优先级 pending 且依赖已满足的任务
4. 按 worktree_limit 并行调度对应 Agent
5. 将新任务写入 tasks/in-progress.yml
```

### gstack 更新验证（非 dry-run）

gstack 没有内置 dry-run 模式，更新后只做以下验证：

1. 核心 skill 文件存在：`/plan-eng-review`、`/qa`、`/ship`、`/review`、`/investigate`
2. 无文件则通知用户 + 回滚到上一个 commit（`git -C ~/.claude/skills/gstack reset --hard HEAD~1`）

---

## 通知方案

| 场景 | 通知方式 | 内容 |
|------|---------|------|
| 需要拍板 | macOS 桌面通知（osascript）+ `tasks/NEEDS_REVIEW.md` | 问题 + 选项 + 建议答案 |
| 生产就绪 | 桌面通知 | 完成清单 + 测试报告路径 |
| gstack 更新成功 | 静默 | — |
| gstack 更新失败 | 桌面通知 | 问题描述 + 已回滚版本号 |
| 任务执行失败 | 桌面通知 + `tasks/NEEDS_REVIEW.md` | 失败原因 + 建议处理方式 |

---

## Bootstrap 流程（新项目接入）

新项目接入 stackpilot 只需三步：

```bash
# 1. 安装 gstack（若未安装）
git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack

# 2. 初始化项目结构
stackpilot init   # 创建 tasks/ 目录、stackpilot.config.yml、git hooks

# 3. 开始工作
# 运行 /brainstorm → 确认设计文档 → commit → 自动接管
```

`stackpilot init` 创建的内容：
- `tasks/backlog.yml`（空）
- `tasks/NEEDS_REVIEW.md`（空）
- `stackpilot.config.yml`（默认配置）
- `.git/hooks/post-checkout`
- `.git/hooks/post-commit`

---

## 通用性设计

本框架设计为**项目无关**的通用框架：

- Agent 定义放在 `~/.claude/agents/`（全局），不绑定特定项目
- 任务文件结构统一，任何项目均可复用
- gstack 作为全局工具安装在 `~/.claude/skills/gstack`
- 新项目只需：`stackpilot init` → `/brainstorm` → commit 设计文档 → 框架自动接管

---

## 目录结构

```
~/.claude/
  agents/
    pm-agent.md
    dev-agent.md
    qa-agent.md
    architect-agent.md
    docs-agent.md
  skills/
    gstack/              ← git clone 安装，每周自动更新
    stackpilot/          ← 本框架的辅助 skill
      update-gstack.md   ← gstack 更新 + 验证

任意项目/
  tasks/
    backlog.yml
    in-progress.yml
    NEEDS_REVIEW.md
    done/
  stackpilot.config.yml  ← 项目级配置（覆盖率阈值等）
  .git/hooks/
    post-checkout        ← 触发 Coordinator
    post-commit          ← 触发 PM Agent（检测新设计文档）
```
