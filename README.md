# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io)

**English** | [中文](#中文文档)

General methodology for coding agents. Turn a request into verified software
through design, spec, plan, execution, review, and finish — across models and
hosts, with the Claude Code adapter currently the most complete implementation.

```
 Feature request → Design → Spec → Plan → sp-architect → sp-dev → sp-qa → Delivery
```

## One StackPilot Entry

Users should start with **StackPilot**, not a menu of skills. In Claude Code the
entry is `/stackpilot` or a natural-language request routed by the plugin
bootstrap. In other hosts, StackPilot should still feel like one product entry;
the portable skill files are adapter primitives for hosts that require discrete
Agent Skills, not commands users are expected to memorize.

**Default gates behind StackPilot** — these run automatically or on demand when
the route needs them:

| Internal route | When StackPilot uses it |
|----------------|-------------------------|
| `stackpilot-methodology` | Feature work enters the host-neutral explore → design → spec/criteria → plan → execute → review → finish flow |
| `stackpilot-planning` | Approved spec/design/clear requirement needs exact implementation tasks |
| `stackpilot-workspace` | Non-trivial implementation needs isolated setup and clean baseline verification |
| `stackpilot-plan-execution` | Existing plans need task-by-task execution with controller verification |
| `stackpilot-parallel-agents` | Independent tasks, failures, research domains, or review domains can safely run concurrently |
| `stackpilot-review-response` | Human or external review feedback needs technical verification before fixes |
| `stackpilot-completion-verification` | Completion, merge, PR, or success claims need fresh evidence |
| `tdd-development` | Production code changes need RED/GREEN/REFACTOR discipline |
| `qa-12-dimensions` | QA or review work needs scenario coverage and adversarial review |
| `architecture-review` | Shared structures or multi-file designs need a grounded architecture decision |
| `systematic-debugging` | Bugs, failing tests, and broken integrations need root-cause investigation |

**Host adapters** implement the same method with host-native tools. The Claude
Code adapter is currently the full autonomous sprint adapter:

| Entry | What it does |
|-------|-------------|
| `/stackpilot` | Primary user entry in Claude Code: tidy → resume → design → spec → plan → autonomous coding → QA → ship. Dispatches `sp-*` subagents via Claude Code's native `Agent` tool. |
| `/stackpilot-compete` | Expert on-demand mode for competitive gap analysis |
| `/stackpilot-research` | Expert on-demand mode for deep research reports using cross-longitudinal analysis (横纵分析法) |
| `/stackpilot-sync` | Maintainer-only mode for tracking and syncing external skill references |
| `stackpilot-skill-authoring` | Maintainer-only internal gate for changing StackPilot skills |

## Automatic Routing

When installed as a Claude Code plugin, Stackpilot uses a session bootstrap hook
to make StackPilot the default route for non-trivial coding work. Natural
feature requests are routed into the internal `stackpilot-methodology` gate
before implementation; in Claude Code, that gate can hand execution to the
`/stackpilot` host adapter for autonomous sprints. Bugs route to
`systematic-debugging`, production code routes through `tdd-development`, and
completion claims require fresh verification evidence. A `PreToolUse` gate backs
this up mechanically by blocking feature/bug/code tools before a StackPilot
process has been activated. Explicit user and project instructions still win;
saying to skip planning or verify manually disables the corresponding route for
that request.

## Demo

```
> /stackpilot

━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
  No active sprint.
━━━━━━━━━━━━━━━━━━━━━━━━━

What feature would you like to build?

> Add user search with fuzzy matching

Node 1: Exploring codebase...
Node 2: Design proposal ready in terminal. Browser view skipped: text is clearer here.
Node 3: Writing spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
        Writing criteria → .stackpilot/specs/2026-04-05-user-search-criteria.md ✓
        Review in terminal: approve / changes: <text> / reverify
Node 4: Writing plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓
        Live dashboard skipped: single straightforward wave

Plan is ready. Proceed with coding? (Y/n)

  ✅ TASK-001  design search API       arch → dev → QA passed   (1/3)
  ✅ TASK-002  implement endpoint      dev → QA passed           (2/3)
  ✅ TASK-003  integration tests       dev → QA passed           (3/3)

Sprint complete. All tests passing.
Sprint evals written: .stackpilot/runs/2026-04-05-user-search-plan/sprint-evals.md
Feedback inbox: no unresolved HIGH/CRITICAL items
Dev server running at: http://localhost:3000

A. Merge into main  B. Push and create PR  C. Leave as-is  D. Discard
```

## Install

StackPilot installs as one package with two internal layers:

- **Methodology gates** — portable Agent Skills used by the StackPilot route in
  hosts that support the Agent Skills standard.
- **Host adapters** — host-native implementations of the same gates. Claude
  Code is currently the full autonomous sprint adapter.

| Host | Current support |
|------|-----------------|
| Claude Code | Full adapter + SessionStart auto-routing via `.claude-plugin/` |
| Cursor | StackPilot routing bootstrap + portable internal gates via `.cursor-plugin/` |
| OpenAI Codex | StackPilot package metadata + portable internal gates via `.codex-plugin/` |
| Gemini CLI | StackPilot routing context + portable internal gates via `gemini-extension.json` / `GEMINI.md` |

Claude Code one-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/9aoyang/stackpilot.git ~/Documents/github/stackpilot
bash ~/Documents/github/stackpilot/scripts/restore.sh
```

The full autonomous sprint adapter requires git and Claude Code. The methodology
gates are portable to Agent Skills-compatible hosts; additional host adapters
should expose one StackPilot entry and reuse the same core gates instead of
forking the method. If you use skillshare, make it the single synchronization
source for shared skills.

Skills auto-update: `/stackpilot` checks for upstream updates once per day and pulls new skills automatically.

## Config

`stackpilot.config.yml` is **auto-generated** when you first run `/stackpilot`. It detects your test framework automatically.

```yaml
# stackpilot.config.yml (auto-generated)
qa:
  coverage_threshold: 80
  test_command: npm test    # auto-detected from project files
```

Auto-detection supports: Node.js, Python, Go, Rust, Ruby, Java/Kotlin, Elixir, PHP, .NET.

## Architecture

See [docs/architecture.md](docs/architecture.md) for the full system design.
See [docs/superpowers-gap-audit.md](docs/superpowers-gap-audit.md) for the
Superpowers workflow coverage audit. It is a gap audit, not a goal to mirror the
number or shape of Superpowers skills.

Key design decisions:
- **One StackPilot entry** — users start with StackPilot; internal gates route automatically or on demand
- **Methodology core first** — StackPilot is a general methodology, not a single-host script
- **Host adapters** — Claude Code adapter uses Agent tool with `isolation: "worktree"` for parallel development
- **Agent Skills standard** — core methodology skills work across 30+ agent products
- **Progressive disclosure** — SKILL.md stays lean (<500 lines), heavy content in `references/`
- **Plan/handoff as persistence** — TaskCreate for runtime; plan, handoff, state, and event files for cross-session recovery
- **Data-layer handoff** — `handoff.json` records phase/status/next action for reliable resume
- **Sprint evals** — `sprint-evals.md` summarizes retries, plateau/stuck signals, criteria state, and recommendation
- **Feedback inbox** — `.stackpilot/feedback/open|resolved` keeps external audit feedback visible through Finish

## [Contributing](CONTRIBUTING.md) | [License](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io)

**[English](#stackpilot)** | 中文

面向 coding agents 的通用方法论。把需求推进为经过验证的软件：设计、spec、
plan、执行、审查、收尾都纳入同一套流程；Claude Code adapter 目前是最完整实现。

```
 功能需求 → 设计讨论 → Spec → Plan → sp-architect → sp-dev → sp-qa → 交付
```

## 一个 StackPilot 入口

用户应该从 **StackPilot** 开始，而不是记一串 skills。在 Claude Code 里入口是
`/stackpilot`，或者由 plugin bootstrap 自动路由的自然语言需求。在其他宿主里，
StackPilot 也应该表现为一个产品入口；portable skill 文件只是那些需要离散 Agent
Skills 的宿主所用的 adapter primitives，不是要求用户记住的命令菜单。

**StackPilot 背后的默认门禁** — 这些能力由 StackPilot 自动触发或按需触发：

| 内部 route | StackPilot 何时使用 |
|------------|---------------------|
| `stackpilot-methodology` | 功能需求进入宿主无关的探索 → 设计 → spec/criteria → plan → 执行 → 审查 → 收尾流程 |
| `stackpilot-planning` | 已批准 spec/design/明确需求需要精确 implementation tasks |
| `stackpilot-workspace` | 非平凡实现需要隔离环境、setup、clean baseline verification |
| `stackpilot-plan-execution` | 既有 plan 需要逐 task 执行并由主控验证 |
| `stackpilot-parallel-agents` | 独立任务、失败域、调研域或 review domain 可安全并行 |
| `stackpilot-review-response` | 人类或外部 review feedback 需要先技术验证再修复 |
| `stackpilot-completion-verification` | 完成、merge、PR 或成功声明前需要新鲜证据 |
| `tdd-development` | 生产代码改动需要 RED/GREEN/REFACTOR 纪律 |
| `qa-12-dimensions` | QA 或 review 需要场景覆盖和对抗式审查 |
| `architecture-review` | 共享结构或多文件设计需要基于代码库的架构决策 |
| `systematic-debugging` | bug、失败测试、集成异常需要根因调查 |

**宿主适配器** 用不同 host 的原生工具实现同一套方法论。Claude Code adapter
目前是完整自主 sprint adapter：

| 入口 | 功能 |
|------|------|
| `/stackpilot` | Claude Code 的主要用户入口：tidy→resume→设计→spec→plan→自主编码→QA→上线。通过 Claude Code 原生 `Agent` 工具调度 `sp-*` subagents。 |
| `/stackpilot-compete` | 专家按需模式：以竞品重度用户视角做差距分析 |
| `/stackpilot-research` | 专家按需模式：横纵分析法深度研报 |
| `/stackpilot-sync` | 维护者模式：追踪和同步外部 skill references |
| `stackpilot-skill-authoring` | 维护者内部 gate：修改 StackPilot skills 时使用 |

## 自动路由

以 Claude Code plugin 安装时，Stackpilot 会通过 session bootstrap hook 让
StackPilot 成为非平凡 coding work 的默认 route。自然语言功能需求会在实现前进入
内部 `stackpilot-methodology` gate；在 Claude Code 中，这个 gate 可以把执行交给
`/stackpilot` 宿主适配器。bug 会走 `systematic-debugging`，生产代码改动会走
`tdd-development`，完成声明前必须有新鲜验证证据。`PreToolUse` gate 会机械阻断
未激活 StackPilot process 就先读文件、执行命令或创建任务的 feature、bug、
production-code 工具调用。用户和项目显式指令仍然优先；如果用户要求跳过规划或自己验证，就按用户指令执行。

## 演示

```
> /stackpilot

━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
  无活跃 sprint
━━━━━━━━━━━━━━━━━━━━━━━━━

你想构建什么功能？

> 增加用户搜索，支持模糊匹配

Node 1: 探索代码库...
Node 2: 设计方案已在终端列出。跳过浏览器视图：这里文字更清楚。
Node 3: 写入 spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
        写入 criteria → .stackpilot/specs/2026-04-05-user-search-criteria.md ✓
        终端评审：approve / changes: <text> / reverify
Node 4: 写入 plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓
        跳过实时 Dashboard：单个直接 wave

计划就绪，开始编码？(Y/n)

  ✅ TASK-001  设计搜索 API       架构审查 → 开发 → QA 通过  (1/3)
  ✅ TASK-002  实现搜索接口       开发 → QA 通过              (2/3)
  ✅ TASK-003  集成测试           开发 → QA 通过              (3/3)

Sprint 完成，所有测试通过。
Sprint evals 已写入：.stackpilot/runs/2026-04-05-user-search-plan/sprint-evals.md
Feedback inbox：没有未解决的 HIGH/CRITICAL 项
Dev server 运行中：http://localhost:3000

A. 合并到 main  B. 推送并创建 PR  C. 暂时保留  D. 丢弃
```

## 安装

StackPilot 作为一个包安装，内部有两层：

- **方法论门禁** — StackPilot route 使用的 portable Agent Skills，可在支持
  Agent Skills 标准的宿主中复用。
- **宿主适配器** — 用宿主原生工具实现同一套门禁；Claude Code 目前是完整自主
  sprint adapter。

| 宿主 | 当前支持 |
|------|----------|
| Claude Code | 完整 adapter + `.claude-plugin/` SessionStart 自动路由 |
| Cursor | StackPilot routing bootstrap + `.cursor-plugin/` portable internal gates |
| OpenAI Codex | StackPilot package metadata + `.codex-plugin/` portable internal gates |
| Gemini CLI | StackPilot routing context + `gemini-extension.json` / `GEMINI.md` portable internal gates |

Claude Code 一键安装：

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

或手动安装：

```bash
git clone https://github.com/9aoyang/stackpilot.git ~/Documents/github/stackpilot
bash ~/Documents/github/stackpilot/scripts/restore.sh
```

完整自主 sprint adapter 需要 git 和 Claude Code。方法论门禁可在 Agent Skills
兼容宿主中使用；新增宿主适配器应该暴露一个 StackPilot 入口，并复用同一套 core
gates，而不是 fork 一套流程。如果你使用 skillshare，应让 skillshare 成为共享
skills 的唯一同步源。

Skills 自动更新：`/stackpilot` 每天自动检查上游更新并拉取新 skills。

## 配置

`stackpilot.config.yml` 在首次运行 `/stackpilot` 时**自动生成**，会自动探测测试框架。

```yaml
# stackpilot.config.yml（自动生成）
qa:
  coverage_threshold: 80
  test_command: npm test    # 根据项目文件自动探测
```

自动探测支持：Node.js、Python、Go、Rust、Ruby、Java/Kotlin、Elixir、PHP、.NET。

## 架构文档

完整系统设计见 [docs/architecture.zh.md](docs/architecture.zh.md)。
Superpowers workflow 覆盖审计见 [docs/superpowers-gap-audit.md](docs/superpowers-gap-audit.md)；
它是 gap audit，不是要求 StackPilot 镜像 Superpowers 的 skill 数量或形态。

核心设计：
- **一个 StackPilot 入口** — 用户从 StackPilot 开始；内部门禁自动触发或按需触发
- **方法论核心优先** — StackPilot 是通用方法论，不是单一宿主脚本
- **宿主适配器** — Claude Code adapter 用 Agent tool + `isolation: "worktree"` 实现并行开发
- **Agent Skills 标准** — core methodology skills 可在 30+ agent 产品中使用
- **渐进式展开** — SKILL.md 精简（<500 行），重内容放 `references/`
- **Plan/handoff 即持久层** — 运行时用 TaskCreate，跨会话用 plan、handoff、state、event 文件恢复
- **数据层 handoff** — `handoff.json` 记录 phase/status/next action，保证恢复可靠
- **Sprint evals** — `sprint-evals.md` 汇总 retry、plateau/stuck 信号、criteria 状态和建议
- **Feedback inbox** — `.stackpilot/feedback/open|resolved` 让外部 audit feedback 贯穿 Finish

## [贡献指南](CONTRIBUTING.md) | [许可证](LICENSE)
