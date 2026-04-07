# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)

**English** | [中文](#中文文档)

Autonomous AI development team. Write a spec, get production-ready code — with tests, docs, and code review. Works with Claude Code, Codex, Gemini CLI, or any LLM CLI.

```
 Spec → sp-pm → sp-architect → sp-dev → sp-qa → sp-docs → Delivery
```

## Why Stackpilot

Without Stackpilot, shipping a feature with AI means:
- Manually prompt the model → copy output → create tasks by hand
- Run each step yourself → check results → re-prompt for fixes
- Context is lost between sessions; no one tracks what's done

With Stackpilot, just type `/stackpilot` in Claude Code and describe what you want:

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

Phase 1: Exploring codebase...
Phase 2: Design proposal ready — approve? (Y/n)
Phase 3: Writing spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
Phase 4: Writing plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓

━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ TASK-001  Design search API schema          pending
⏳ TASK-002  Implement /users/search endpoint  pending
⏳ TASK-003  Write integration tests           pending
⏳ TASK-004  Update API docs                   pending
━━━━━━━━━━━━━━━━━━━━━━━━━

Plan is ready. Proceed with coding? (Y/n)

  🔄 TASK-001 → sp-architect reviewing...  ✅ done
  🔄 TASK-002 → sp-dev implementing...     ✅ done
  🔄 TASK-003 → sp-qa writing tests...     ✅ done
  🔄 TASK-004 → sp-docs updating...        ✅ done

Sprint complete. All tests passing.
```

Use `/stackpilot:auto` to skip all confirmations and run fully unattended.

See [examples/specs/](examples/specs/) for real spec examples.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Installs Stackpilot and all dependencies. Requires git and at least one AI CLI (Claude Code, Codex, Gemini CLI, or a custom tool).

## Usage

**Claude Code:**

| Command | Description |
|---------|-------------|
| `/stackpilot` | Main entry point — init, brainstorming, planning, and delivery. Shows sprint status, guides next action. |
| `/stackpilot:auto` | Full-auto mode — same workflow but skips all confirmations. Ends with code on feature branch ready for review. |
| `/stackpilot:sync` | Manage external skill references inlined into agents. `add` to extract a new skill, `check` to detect updates. |
| `/stackpilot:compete` | Competitive gap analysis — assume persona of a competing product's power user and identify what would make them switch. |

**Other providers:** Run `bash ~/.stackpilot/scripts/init.sh` in your project — the provider and test command are auto-detected.

## Config

`stackpilot.config.yml` is **auto-generated** by `init.sh` — it detects your project's language, test framework, and available AI CLI. You only need to edit it if the defaults are wrong.

```yaml
# stackpilot.config.yml (auto-generated example for a Node.js project)
provider:
  name: claude             # auto-detected: claude | codex | gemini | custom
  # model: ~               # Override model (optional)
  # command: ~             # Required when name=custom

qa:
  coverage_threshold: 80
  test_command: npm test    # auto-detected from project files
coordinator:
  worktree_limit: 3        # max parallel agents
  timeout_hours: 2

# Per-agent model routing — grouped by provider
# Use multiple providers on the same project simultaneously
models:
  claude:
    default: sonnet
    sp-pm: haiku
    sp-architect: opus
  codex:
    default: o4-mini
    sp-architect: o3
  gemini:
    default: gemini-2.5-flash
```

Auto-detection supports: Node.js, Python, Go, Rust, Ruby, Java/Kotlin (Maven & Gradle), Elixir, PHP, and .NET.

### Supported Providers

| Provider | CLI | Notes |
|----------|-----|-------|
| `claude` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Default. Full feature support (tool restrictions, skills, plugins) |
| `codex` | [Codex CLI](https://github.com/openai/codex) | Uses `--full-auto` mode |
| `gemini` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Uses `-p` prompt mode |
| `custom` | Any CLI | Set `provider.command` to your tool's invocation |

## Architecture

See [docs/architecture.md](docs/architecture.md) for the full system design, agent pipeline, event flow, and task lifecycle.

## [Contributing](CONTRIBUTING.md) | [License](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/9aoyang/stackpilot)](https://github.com/9aoyang/stackpilot/releases)

**[English](#stackpilot)** | 中文

自治 AI 开发团队。写设计文档，交付生产级代码 — 含测试、文档和代码审查。支持 Claude Code、Codex、Gemini CLI 或任意 LLM CLI。

```
 设计文档 → sp-pm → sp-architect → sp-dev → sp-qa → sp-docs → 交付
```

## 为什么选 Stackpilot

没有 Stackpilot，用 AI 交付功能意味着：
- 手动提示模型 → 复制输出 → 手动拆任务
- 亲自跑每个步骤 → 看结果 → 再补充提示修复
- 会话间上下文丢失，没有人追踪进度

有了 Stackpilot，在 Claude Code 中输入 `/stackpilot` 并描述你想要的功能：

## 演示

```
> /stackpilot

━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
  No active sprint.
━━━━━━━━━━━━━━━━━━━━━━━━━

你想构建什么功能？

> 增加用户搜索，支持模糊匹配

Phase 1: 探索代码库...
Phase 2: 设计方案就绪 — 确认？(Y/n)
Phase 3: 写入 spec → .stackpilot/specs/2026-04-05-user-search-design.md ✓
Phase 4: 写入 plan → .stackpilot/plans/2026-04-05-user-search-plan.md ✓

━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint Status
━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ TASK-001  设计搜索 API schema          pending
⏳ TASK-002  实现 /users/search 接口       pending
⏳ TASK-003  编写集成测试                  pending
⏳ TASK-004  更新 API 文档                 pending
━━━━━━━━━━━━━━━━━━━━━━━━━

计划就绪，开始编码？(Y/n)

  🔄 TASK-001 → sp-architect 评审中...  ✅ 完成
  🔄 TASK-002 → sp-dev 实现中...        ✅ 完成
  🔄 TASK-003 → sp-qa 写测试中...       ✅ 完成
  🔄 TASK-004 → sp-docs 更新文档中...   ✅ 完成

Sprint 完成，所有测试通过。
```

使用 `/stackpilot:auto` 可跳过所有确认环节，全自动运行。

真实 spec 示例见 [examples/specs/](examples/specs/)。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

自动安装 Stackpilot 及所有依赖。需要 git 和至少一个 AI CLI（Claude Code、Codex、Gemini CLI 或自定义工具）。

## 使用

**Claude Code:**

| 命令 | 说明 |
|------|------|
| `/stackpilot` | 主入口 — 初始化、头脑风暴、规划、交付。显示 sprint 状态，引导下一步操作。 |
| `/stackpilot:auto` | 全自动模式 — 跳过所有确认环节，代码直接提交到功能分支等待审查。 |
| `/stackpilot:sync` | 管理外部技能引用。`add` 提取新技能，`check` 检测已引用技能的更新。 |
| `/stackpilot:compete` | 竞品差距分析 — 以竞品重度用户视角，找出让用户转向的关键因素。 |

**其他 Provider:** 在项目中运行 `bash ~/.stackpilot/scripts/init.sh`，provider 和测试命令会自动探测。

## 配置

`stackpilot.config.yml` 由 `init.sh` **自动生成** — 会探测项目语言、测试框架和可用的 AI CLI。只有默认值不对时才需要手动修改。

```yaml
# stackpilot.config.yml（自动生成示例，Node.js 项目）
provider:
  name: claude             # 自动探测：claude | codex | gemini | custom
  # model: ~               # 覆盖模型（可选）
  # command: ~             # name=custom 时必填

qa:
  coverage_threshold: 80
  test_command: npm test    # 根据项目文件自动探测
coordinator:
  worktree_limit: 3        # 最大并行 agent 数
  timeout_hours: 2

# 按 Provider 分组的 Agent 模型路由 — 同一项目可同时用多个 Provider
models:
  claude:
    default: sonnet
    sp-pm: haiku
    sp-architect: opus
  codex:
    default: o4-mini
    sp-architect: o3
  gemini:
    default: gemini-2.5-flash
```

自动探测支持：Node.js、Python、Go、Rust、Ruby、Java/Kotlin（Maven & Gradle）、Elixir、PHP、.NET。

### 支持的 Provider

| Provider | CLI | 说明 |
|----------|-----|------|
| `claude` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | 默认。完整功能支持（工具限制、技能、插件） |
| `codex` | [Codex CLI](https://github.com/openai/codex) | 使用 `--full-auto` 模式 |
| `gemini` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | 使用 `-p` 提示模式 |
| `custom` | 任意 CLI | 设置 `provider.command` 为你的工具命令 |

## 架构文档

完整的系统设计、Agent 流水线、事件流和任务生命周期，见 [docs/architecture.zh.md](docs/architecture.zh.md)。

## [贡献指南](CONTRIBUTING.md) | [许可证](LICENSE)
