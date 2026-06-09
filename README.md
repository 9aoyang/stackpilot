# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io)

**English** | [中文](#中文文档)

Sprint orchestration for Claude Code. Write a spec, get production-ready code — with TDD, code review, and 12-dimension test coverage.

```
 Feature request → Design → Spec → Plan → sp-architect → sp-dev → sp-qa → Delivery
```

## Two Layers

**Portable methodology skills** — work in any [Agent Skills](https://agentskills.io)-compatible product (Cursor, VS Code Copilot, Gemini CLI, Codex, JetBrains Junie, and 25+ more):

| Skill | What it does |
|-------|-------------|
| `/tdd-development` | TDD cycle (RED-GREEN-REFACTOR) + verify/fix loop + rationalization blockers |
| `/qa-12-dimensions` | Two-stage code review + 12-dimension scenario test coverage |
| `/architecture-review` | Codebase pattern analysis → decisive architecture choice → implementation blueprint |
| `/systematic-debugging` | 4-phase root cause investigation (observe→trace→hypothesize→fix) + red flag detection |

**Stackpilot orchestration** — Claude Code-only dispatch:

| Skill | What it does |
|-------|-------------|
| `/stackpilot` | Full sprint: tidy → resume → design → spec → plan → autonomous coding → QA → ship. Dispatches `sp-*` subagents via Claude Code's native `Agent` tool. |
| `/stackpilot-compete` | Competitive gap analysis from power-user persona |
| `/stackpilot-research` | Deep research reports using cross-longitudinal analysis (横纵分析法) |
| `/stackpilot-sync` | Track and sync external skills inlined into agents |

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
Node 2: Design proposal ready — open http://localhost:51234/sprints/.../design-options.html or approve in terminal? (Y/n)
Node 3: Writing spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
        Writing criteria → .stackpilot/specs/2026-04-05-user-search-criteria.md ✓
        Spec review open at http://localhost:51234/sprints/.../spec-review.html
Node 4: Writing plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓
        Live dashboard: http://localhost:51234/sprints/.../dashboard.html

Plan is ready. Proceed with coding? (Y/n)

  ✅ TASK-001  design search API       arch → dev → QA passed   (1/3)
  ✅ TASK-002  implement endpoint      dev → QA passed           (2/3)
  ✅ TASK-003  integration tests       dev → QA passed           (3/3)

Sprint complete. All tests passing.
Dev server running at: http://localhost:3000

A. Merge into main  B. Push and create PR  C. Leave as-is  D. Discard
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/9aoyang/stackpilot.git ~/Documents/github/stackpilot
bash ~/Documents/github/stackpilot/scripts/restore.sh
```

Requires git and Claude Code. If you use skillshare, make it the single
synchronization source for shared skills.

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

Key design decisions:
- **Claude Code-native orchestration** — Agent tool with `isolation: "worktree"` for parallel development
- **Agent Skills standard** — portable methodology skills work across 30+ agent products
- **Progressive disclosure** — SKILL.md stays lean (<500 lines), heavy content in `references/`
- **Plan as persistence** — TaskCreate for runtime, plan files for cross-session recovery

## [Contributing](CONTRIBUTING.md) | [License](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io)

**[English](#stackpilot)** | 中文

面向 Claude Code 的 Sprint 编排层。写设计文档，交付生产级代码 — 含 TDD、代码审查和 12 维测试覆盖。

```
 功能需求 → 设计讨论 → Spec → Plan → sp-architect → sp-dev → sp-qa → 交付
```

## 两层架构

**便携式方法论 Skills** — 在任何 [Agent Skills](https://agentskills.io) 兼容产品中可用（Cursor、VS Code Copilot、Gemini CLI、Codex、JetBrains Junie 等 25+）：

| Skill | 功能 |
|-------|------|
| `/tdd-development` | TDD 循环（RED-GREEN-REFACTOR）+ verify/fix 循环 + 合理化阻断 |
| `/qa-12-dimensions` | 两阶段代码审查 + 12 维场景测试覆盖 |
| `/architecture-review` | 代码库模式分析 → 唯一架构决策 → 实现蓝图 |
| `/systematic-debugging` | 4 阶段根因调查（观察→追溯→假设→修复）+ 红旗检测 |

**Stackpilot 编排** — Claude Code-only 调度：

| Skill | 功能 |
|-------|------|
| `/stackpilot` | 完整 sprint：tidy→resume→设计→spec→plan→自主编码→QA→上线。通过 Claude Code 原生 `Agent` 工具调度 `sp-*` subagents。 |
| `/stackpilot-compete` | 以竞品重度用户视角做差距分析 |
| `/stackpilot-research` | 横纵分析法深度研报（纵向发展史 + 横向竞品切面） |
| `/stackpilot-sync` | 追踪和同步内联到 agent 的外部 skill |

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
Node 2: 设计方案就绪 — 浏览器打开 http://localhost:51234/sprints/.../design-options.html 或终端确认？(Y/n)
Node 3: 写入 spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
        写入 criteria → .stackpilot/specs/2026-04-05-user-search-criteria.md ✓
        Spec 评审视图：http://localhost:51234/sprints/.../spec-review.html
Node 4: 写入 plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓
        实时 Dashboard：http://localhost:51234/sprints/.../dashboard.html

计划就绪，开始编码？(Y/n)

  ✅ TASK-001  设计搜索 API       架构审查 → 开发 → QA 通过  (1/3)
  ✅ TASK-002  实现搜索接口       开发 → QA 通过              (2/3)
  ✅ TASK-003  集成测试           开发 → QA 通过              (3/3)

Sprint 完成，所有测试通过。
Dev server 运行中：http://localhost:3000

A. 合并到 main  B. 推送并创建 PR  C. 暂时保留  D. 丢弃
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

或手动安装：

```bash
git clone https://github.com/9aoyang/stackpilot.git ~/Documents/github/stackpilot
bash ~/Documents/github/stackpilot/scripts/restore.sh
```

需要 git 和 Claude Code。如果你使用 skillshare，应让 skillshare 成为共享
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

核心设计：
- **Claude Code 原生编排** — Agent tool + `isolation: "worktree"` 实现并行开发
- **Agent Skills 标准** — 便携式方法论 Skills 可在 30+ agent 产品中使用
- **渐进式展开** — SKILL.md 精简（<500 行），重内容放 `references/`
- **Plan 即持久层** — 运行时用 TaskCreate，跨会话用 plan 文件恢复

## [贡献指南](CONTRIBUTING.md) | [许可证](LICENSE)
