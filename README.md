# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**English** | [中文](#中文文档)

Autonomous AI development team. Write a spec, get production-ready code — with tests, docs, and code review. Works with Claude Code, Codex, Gemini CLI, or any LLM CLI.

```
Spec ──► PM Agent ──► Architect ──► Dev ──► QA ──► Docs ──► Delivery
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Installs Stackpilot and all dependencies. Requires git and at least one AI CLI (Claude Code, Codex, Gemini CLI, or a custom tool).

## Usage

**Claude Code:** Type `/stackpilot` — it handles init, brainstorming, planning, and delivery.

**Other providers:** Run `bash scripts/init.sh` in your project, then set the provider in `stackpilot.config.yml`.

## Config

```yaml
# stackpilot.config.yml
provider:
  name: claude             # claude | codex | gemini | custom
  # model: ~               # Override model (optional)
  # command: ~             # Required when name=custom

qa:
  coverage_threshold: 80
  test_command: npm test    # pytest / go test ./... / cargo test
coordinator:
  timeout_hours: 2
```

### Supported Providers

| Provider | CLI | Notes |
|----------|-----|-------|
| `claude` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Default. Full feature support (tool restrictions, skills, plugins) |
| `codex` | [Codex CLI](https://github.com/openai/codex) | Uses `--full-auto` mode |
| `gemini` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Uses `-p` prompt mode |
| `custom` | Any CLI | Set `provider.command` to your tool's invocation |

## Dependencies

| Dependency | Required | Provider | Description |
|-----------|----------|----------|-------------|
| [superpowers](https://github.com/anthropics/claude-code-plugins) | Claude only | claude | Official plugin (brainstorming, writing-plans) |
| [autoresearch](https://github.com/uditgoenka/autoresearch) | No | claude | Multi-perspective analysis |
| [frontend-design](https://github.com/anthropics/claude-code-plugins) | No | claude | UI design skill |

Claude Code dependencies are auto-installed by `install.sh`. Other providers need only git and the provider CLI.

## [Contributing](CONTRIBUTING.md) | [License](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

**[English](#stackpilot)** | 中文

自治 AI 开发团队。写设计文档，交付生产级代码 — 含测试、文档和代码审查。支持 Claude Code、Codex、Gemini CLI 或任意 LLM CLI。

```
设计文档 ──► PM ──► 架构师 ──► 开发 ──► 测试 ──► 文档 ──► 交付
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

自动安装 Stackpilot 及所有依赖。需要 git 和至少一个 AI CLI（Claude Code、Codex、Gemini CLI 或自定义工具）。

## 使用

**Claude Code:** 输入 `/stackpilot`，从初始化到交付，全程自动引导。

**其他 Provider:** 在项目中运行 `bash scripts/init.sh`，然后在 `stackpilot.config.yml` 中设置 provider。

## 配置

```yaml
# stackpilot.config.yml
provider:
  name: claude             # claude | codex | gemini | custom
  # model: ~               # 覆盖模型（可选）
  # command: ~             # name=custom 时必填

qa:
  coverage_threshold: 80
  test_command: npm test    # pytest / go test ./... / cargo test
coordinator:
  timeout_hours: 2
```

### 支持的 Provider

| Provider | CLI | 说明 |
|----------|-----|------|
| `claude` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | 默认。完整功能支持（工具限制、技能、插件） |
| `codex` | [Codex CLI](https://github.com/openai/codex) | 使用 `--full-auto` 模式 |
| `gemini` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | 使用 `-p` 提示模式 |
| `custom` | 任意 CLI | 设置 `provider.command` 为你的工具命令 |

## 依赖

| 依赖 | 必需 | Provider | 说明 |
|------|------|----------|------|
| [superpowers](https://github.com/anthropics/claude-code-plugins) | Claude 专用 | claude | 官方插件（brainstorming、writing-plans） |
| [autoresearch](https://github.com/uditgoenka/autoresearch) | 否 | claude | 多视角分析 |
| [frontend-design](https://github.com/anthropics/claude-code-plugins) | 否 | claude | UI 设计 |

Claude Code 依赖由 `install.sh` 自动安装。其他 provider 只需 git 和对应 CLI。

## [贡献指南](CONTRIBUTING.md) | [许可证](LICENSE)
