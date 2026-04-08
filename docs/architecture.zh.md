# Stackpilot 架构文档

> 最后更新：2026-04-08

Stackpilot 是一个面向 Claude Code 的方法论驱动 Sprint 编排层。它将设计文档转化为可运行代码，通过驱动 Claude Code 原生的 Agent tool、TaskCreate 和 worktree 隔离能力完成——无需自建基础设施。

---

## 核心模型

```
用户描述功能 → 设计讨论 → spec + plan → Agent 自动构建 → 验收 + 上线
```

用户的操作界面是 `/stackpilot` skill，skill 用 Claude Code 原生工具编排一切。

---

## 目录结构

```
stackpilot/                        ← 框架安装目录
├── claude-config/
│   ├── agents/                    ← Agent 方法论提示词（sp-*.md）
│   │   ├── sp-architect.md        ← 只读架构审查
│   │   ├── sp-dev.md              ← TDD 实现
│   │   ├── sp-qa.md               ← 代码审查 + 测试
│   │   └── sp-docs.md             ← 文档更新
│   └── skills/
│       ├── stackpilot/
│       │   └── SKILL.md           ← /stackpilot 主入口
│       ├── stackpilot-auto/
│       │   └── SKILL.md           ← /stackpilot-auto 全自动模式
│       ├── stackpilot-resume/
│       │   └── SKILL.md           ← /stackpilot-resume 中断恢复
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot-compete 竞品差距分析
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync 外部 skill 同步
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging（便携式）
├── scripts/
│   ├── init.sh                    ← 项目初始化（精简：目录 + 测试命令检测）
│   ├── lib/
│   │   └── config.sh              ← YAML 配置读取工具
│   ├── hooks/
│   │   └── README.md              ← hooks 在 v2 中已移除，附说明
│   └── preview/
│       ├── start-server.sh        ← 可视化设计伴侣服务器
│       └── stop-server.sh
└── templates/
    ├── stackpilot.config.yml      ← 配置模板（仅 qa 部分）
    ├── stackpilot-inner-gitignore
    └── NEEDS_REVIEW.md            ← 人工审阅收件箱模板

<项目根目录>/                      ← 用户的项目
├── stackpilot.config.yml          ← qa 配置（test_command, coverage_threshold）
└── .stackpilot/                   ← specs 和 plans 受 git 跟踪
    ├── specs/                     ← 设计文档
    ├── plans/                     ← 实现计划
    └── NEEDS_REVIEW.md            ← 人工升级通道（gitignored）
```

---

## Agent 流水线

### 标准任务（多模块、涉及架构决策）

```
sp-architect → sp-dev → sp-qa
```

### 轻量任务（单文件、需求明确）

```
sp-dev → sp-qa
```

轻量任务跳过 sp-architect，简单改动节省约 60% Agent 开销。

> sp-qa 在每个 sp-dev 完成后立即调度（即时 review，非批量）。

---

## Agent 职责

| Agent | 职责 | 核心协议 |
|-------|------|---------|
| **sp-architect** | 对照代码库审查任务；返回架构决策 | 先分析现有代码模式（file:line 引用）；唯一的架构决策；完整实现蓝图；HIGH 风险多角色对抗分析；新依赖/结构冲突返回 `[ESCALATION]` |
| **sp-dev** | 实现任务 | 读 `git log` 避免重复失败路径；追踪入口点+调用链；强制 TDD（RED-GREEN-REFACTOR）；4 阶段根因调查；verify/fix 循环含卡住检测；失败后回滚；3 轮后返回 `[SOFT-BLOCKED]` |
| **sp-qa** | 审查代码、编写测试 | 两阶段审查（spec 合规 + 代码质量）；12 维场景测试；置信度 ≥ 80 才上报；有限范围生产修复；返回 `[CRITICAL]` 或 `[SOFT-BLOCKED]` |
| **sp-docs** | 更新 README、注释、API 文档 | QA 通过后运行；只改文档不改逻辑 |

---

## Agent 调度方式（v2 — Claude Code 原生）

v2 中，`/stackpilot` skill 使用 Claude Code 原生工具编排 agent：

```
Agent(
  description="实现 TASK-001",
  prompt="<sp-dev 方法论> + <任务上下文> + <架构审查>",
  isolation="worktree"    ← Claude Code 自动管理 worktree
)
```

**相比 v1 dispatch.sh 的核心收益：**
- Fork pattern cache 共享（节省约 66% input tokens）
- 自动 worktree 创建和清理
- 内置超时和中止处理
- 结果直接返回（无需文件中转）
- Agent 输出作为 prompt 上下文级联传递：architect → dev → QA

**任务跟踪** 使用 Claude Code 原生 `TaskCreate`/`TaskUpdate`，替代 YAML 文件。

---

## 事件流

### 用户主动触发（通过 `/stackpilot` skill）

```
/stackpilot [功能描述]
  └─ 展示 Sprint 状态
       └─ 按状态路由：
            未初始化      → 运行 init.sh
            Sprint 干净   → 功能流程（轻量或标准路径）
            进行中         → 继续 sprint
            有待审阅       → 展示问题，引导回复
```

**Standard Feature — 人工介入点：**

```
Phase 1: 逐个澄清问题（深度理解后再问下一个）
Phase 1.5: 可视化伴侣（浏览器端 mockup，仅在视觉表达更优时使用）
Phase 2: 设计方案（分段展示，用户逐段确认）
Phase 3: spec 自动验证循环（自修复，仅 3 次失败才升级）
Phase 4: plan 自动验证循环（自修复，仅 3 次失败才升级）
Pre-coding: 确认开始
Coding: 自动执行 + 每 task 进度简报
Sprint finish: merge / PR / 保留 / 丢弃
```

---

## 任务生命周期

```
pending → in-progress → done
                     ↘ soft-blocked（重试 ≤ 3 次）→ done
                     ↘ blocked（3 次失败 → 用户决策）
```

- `soft-blocked`：Agent 返回 `[SOFT-BLOCKED]`；主会话重试最多 3 次
- `blocked`：重试耗尽，升级给用户
- 运行时跟踪：Claude Code 的 `TaskCreate`/`TaskUpdate`（会话级）
- 持久化：plan 文件（git 跟踪，跨会话存续）

**NEEDS_REVIEW.md** 是人工升级通道。Agent 返回升级文本；主会话将关键问题写入此处，供跨会话使用。

---

## 配置

`stackpilot.config.yml`（项目根目录，v2 — 精简）：

```yaml
qa:
  coverage_threshold: 80
  test_command: npm test    # init.sh 自动探测
```

模型路由由 Claude Code 原生管理（agent frontmatter 中的 `model:` 字段）。

---

## Skill 入口

| Slash Command | 用途 |
|--------------|------|
| `/stackpilot` | 主入口：状态 + 功能流程 + Sprint 执行 |
| `/stackpilot-auto` | 全自动：跳过所有确认，代码停在 feature branch |
| `/stackpilot-resume` | 恢复中断的 Sprint（从 plan + git log 重建状态） |
| `/stackpilot-compete` | 以竞品重度用户视角做差距分析 |
| `/stackpilot-sync` | 外部 skill 追踪和同步 |
| `/tdd-development` | **便携式** — TDD + verify/fix + 合理化阻断 |
| `/qa-12-dimensions` | **便携式** — 12 维测试覆盖 + 代码审查 |
| `/architecture-review` | **便携式** — 代码库模式分析 + 实现蓝图 |
| `/systematic-debugging` | **便携式** — 4 阶段根因调查 + 红旗检测 |

---

## Agent Skills 合规

Stackpilot 遵循 Anthropic 维护的 [Agent Skills 开放标准](https://agentskills.io)。

**便携式方法论 Skills** — 在任何 Agent Skills 兼容产品中可用（Cursor、VS Code Copilot、Gemini CLI、Codex、JetBrains Junie 等 25+）：

| Skill | 功能 | 便携？ |
|-------|------|--------|
| `tdd-development` | TDD 循环 + verify/fix + 合理化阻断 | 是 |
| `qa-12-dimensions` | 两阶段代码审查 + 12 维测试覆盖 | 是 |
| `architecture-review` | 模式分析 + 唯一架构决策 + 蓝图 | 是 |
| `systematic-debugging` | 4 阶段根因调查 + 红旗检测 | 是 |

**编排 Skills** — Claude Code 专用：

| Skill | 功能 |
|-------|------|
| `stackpilot` | 完整 sprint：设计→spec→plan→编码→QA→上线 |
| `stackpilot-auto` | 全自动，跳过确认 |
| `stackpilot-resume` | 从 plan + git log 恢复中断 sprint |

**渐进式展开** — SKILL.md 控制在 500 行以内，重内容（visual companion、optimize sprint、sprint finish）放在 `references/` 按需加载。

---

## 关键设计决策

**Claude Code 原生编排（v2）。** Agent 通过 Claude Code 的 Agent tool 调度，带 `isolation: "worktree"`。无自建 bash dispatcher、无手动 worktree 管理、无文件锁。Claude Code 处理所有基础设施。

**Prompt 级 Agent 间通信。** Agent 输出直接作为 prompt 上下文传递给下游 Agent。无中间文件（arch-review/、done/）。主会话即 coordinator。

**Plan 即持久层。** 任务在会话内通过 TaskCreate 跟踪。Plan 文件是持久化的 source of truth。`/stackpilot-resume` 从 plan + git log 重建状态。

**零外部依赖。** 所有 Agent 协议内联，无需安装任何外部插件。

**任务粒度的复杂度路由。** `complexity: light | standard`，轻量跳过 architect，省约 60% Agent 开销。

**Soft-blocked 重试。** Agent 返回 `[SOFT-BLOCKED]`，主会话重试最多 3 次才需人工。

**Git 即记忆。** sp-dev 每次任务前读 `git log --oneline -20`，不重复已失败的方案。

**强制 TDD。** RED-GREEN-REFACTOR，先写测试再写实现。

**根因调查优先。** 4 阶段调查（观察→复现→追溯→假设）后才修复。

---

## 演进记录

| 日期 | 变更 |
|------|------|
| 2026-04-08 | **v2 架构**：dispatch.sh 替换为 Claude Code 原生 Agent tool；backlog.yml 替换为 TaskCreate；移除 sp-pm 和 sp-coordinator（内联到 skill）；移除 git hooks；配置精简为仅 qa 部分；新增 /stackpilot-resume；Agent 变为纯方法论提示词，无文件 I/O |
| 2026-04-07 | 收敛交互流程；Visual Companion 内联；自动探测项目栈；TDD + 根因调查；即时 review；per-provider model routing；worktree 隔离；pre-commit 校验；文件锁；超时；自动 coding + 进度简报 |
| 2026-04-07 | 逐个澄清问题；Visual Companion 浏览器服务器；compete 12 维度 + 5 角色辩论 |
| 2026-04-04 | 集成 autoresearch 模式；12 维测试；多角色对抗分析；Optimize Sprint；docs/sync.md |
| 2026-04-04 | sp-* 前缀；.stackpilot/ 运行时状态；内联所有外部 skill 协议 |
| 2026-04-01 | 复杂度路由、verify/fix 循环、soft-blocked 重试 |
| 2026-03-29 | 初始实现 |
