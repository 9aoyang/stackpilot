# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**English** | [中文](#中文文档)

Autonomous AI development team framework for Claude Code. Give it an idea; it delivers production-ready code.

---

## How It Works

Stackpilot runs a five-layer pipeline inside Claude Code:

```
You write a spec ──► PM Agent decomposes tasks ──► Coordinator dispatches agents
                                                         │
                                     ┌──────────┬────────┼────────┬──────────┐
                                 Architect    Dev Agent  QA Agent  Docs Agent
                                 (review)    (implement) (test)   (document)
                                                         │
                                                    Delivery ──► You review
```

1. **Idea** — Write a feature spec in `docs/specs/` and commit it.
2. **PM Agent** — Triggered by `post-commit` hook, decomposes the spec into atomic tasks in `tasks/backlog.yml`.
3. **Coordinator** — Triggered by `post-checkout` hook on branch switch; dispatches specialist agents and tracks progress.
4. **Specialist Agents** — Dev, QA, Architect, and Docs agents each handle one task at a time, escalating to `tasks/NEEDS_REVIEW.md` when blocked.
5. **Delivery** — Completed summaries land in `tasks/done/`, docs are updated, and you receive a desktop notification.

## Dependencies

### Required

| Dependency | Type | Description |
|-----------|------|-------------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | CLI tool | `claude` command must be in PATH |
| [gstack](https://github.com/garrytan/gstack) | Claude Code skill | 28 professional skills by Garry Tan (plan, ship, review, QA, etc.) |
| [superpowers](https://github.com/anthropics/claude-code-plugins) | Claude Code plugin | Official plugin — brainstorming, writing-plans, finishing-a-development-branch |
| git | CLI tool | Version control |

### Optional

| Dependency | Type | Description |
|-----------|------|-------------|
| [autoresearch](https://github.com/uditgoenka/autoresearch) | Claude Code skill | Used for `autoresearch:predict` in standard feature analysis |
| [ui](https://github.com/anthropics/claude-code-plugins) | Claude Code plugin | UI design skill — called when feature involves frontend |

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` command in PATH)
- git

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

This automatically installs Stackpilot and all dependencies:
- Stackpilot agents + skills → `~/.claude/`
- [gstack](https://github.com/garrytan/gstack) — 28 professional Claude Code skills by Garry Tan
- [autoresearch](https://github.com/uditgoenka/autoresearch) — autonomous iteration skill
- [superpowers](https://github.com/anthropics/claude-code-plugins) + [frontend-design](https://github.com/anthropics/claude-code-plugins) plugins (prompted if not installed)

## Quick Start

### Initialize a project

```bash
cd /your/project
bash ~/.stackpilot/scripts/init.sh
```

This creates:
- `tasks/` directory (backlog, in-progress, escalation files)
- `stackpilot.config.yml` (project config)
- Git hooks (`post-commit`, `post-checkout`)

### Edit your project config

```yaml
# stackpilot.config.yml
qa:
  coverage_threshold: 80
  test_command: npm test       # or: pytest / go test ./... / cargo test
coordinator:
  worktree_limit: 3
  timeout_hours: 2
```

### Start building

**Option A: Use the `/stackpilot` slash command (recommended)**

Type `/stackpilot` in Claude Code. It shows a status dashboard and guides you through the workflow.

**Option B: Manual git workflow**

```bash
# 1. Write a feature spec
mkdir -p docs/specs
cat > docs/specs/2026-04-01-login-page.md << 'EOF'
# Login Page
Build a login page with email/password authentication.
## Requirements
- Email validation
- Password strength indicator
- Error handling for invalid credentials
EOF

# 2. Commit the spec → PM Agent auto-decomposes tasks
git add docs/specs/
git commit -m "feat: add login page spec"

# 3. Switch to feature branch → Coordinator auto-starts
git checkout -b feat/login-page
```

### Monitor progress

```bash
# Check task status
cat tasks/backlog.yml

# Check agent logs
cat tasks/coordinator.log
cat tasks/pm-agent.log

# Check escalations
cat tasks/NEEDS_REVIEW.md
```

### Handle escalations

When an agent is blocked, it writes to `tasks/NEEDS_REVIEW.md`. You'll receive a desktop notification.

```bash
# Read the question
cat tasks/NEEDS_REVIEW.md

# Reply by appending
echo "REPLY: Option B" >> tasks/NEEDS_REVIEW.md

# Re-trigger Coordinator
git checkout feat/login-page
```

## Agent Team

| Agent | Role | Tools | Triggered by |
|-------|------|-------|-------------|
| PM Agent | Decomposes specs into `tasks/backlog.yml` | Read, Write, Glob | `post-commit` (new spec detected) |
| Architect Agent | Reviews tech decisions, flags risks | Read, Write, Glob, Grep, WebSearch | Coordinator (standard tasks) |
| Dev Agent | Implements features | Read, Edit, Write, Bash, Glob, Grep | Coordinator |
| QA Agent | Writes & runs tests, scoped bug fixes | Read, Edit, Write, Bash, Glob, Grep | Coordinator |
| Docs Agent | Updates README and API docs | Read, Edit, Write, Glob | Coordinator |
| Coordinator | Orchestrates the sprint | Read, Write, Bash, Glob | `post-checkout` / `/stackpilot` |

### Task routing

Tasks are routed by `complexity` field:

- **light** (simple changes, ≤3 files): Dev → QA (skips Architect and Docs)
- **standard** (multi-module, architectural): Architect → Dev → QA → Docs

### Error handling

- Agents retry up to 3 times before marking a task `soft-blocked`
- Coordinator converts `soft-blocked` → `blocked` after 3 total attempts
- Blocked tasks are escalated to `tasks/NEEDS_REVIEW.md` for human review
- Timed-out tasks (exceeding `timeout_hours`) are marked `failed`
- Circular dependencies are detected and escalated

## Keeping gstack Up to Date

```bash
# Add to crontab (weekly, Monday 3 AM)
echo "0 3 * * 1 bash ~/stackpilot/scripts/update-gstack.sh" | crontab -

# Or manually in Claude Code
/update-gstack
```

The updater verifies required skills after each pull and auto-rolls back on failure.

## Restore on a New Machine

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Running it again safely updates to the latest version.

## Repository Structure

```
claude-config/
  agents/          # Agent definitions (*.md) → ~/.claude/agents/
  skills/
    stackpilot/    # Slash-command skills → ~/.claude/skills/stackpilot/
scripts/
  init.sh          # Initialize Stackpilot in a target project
  restore.sh       # Copy agents + skills to ~/.claude/
  update-gstack.sh # Auto-update gstack with rollback
  hooks/
    post-commit.sh   # Triggers PM Agent on spec commit
    post-checkout.sh # Triggers Coordinator on branch switch
templates/
  backlog.yml           # Task backlog structure
  in-progress.yml       # Active task tracking
  stackpilot.config.yml # Default project config
  NEEDS_REVIEW.md       # Escalation template
tests/
  test-init.sh    # Init script validation
  test-hooks.sh   # Hook trigger logic tests
  test-e2e.sh     # Structural verification
docs/
  specs/           # Feature specifications
  workflow.png     # Architecture diagram
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hook doesn't trigger | Run `ls -la .git/hooks/post-commit` — check it exists and is executable |
| `claude: command not found` | Install Claude Code CLI and ensure it's in PATH |
| PM Agent doesn't run on commit | Check that `tasks/` directory exists (run `init.sh` first) |
| Coordinator doesn't start | Verify branch checkout (not file checkout); check `tasks/coordinator.log` |
| No desktop notification | macOS: ensure notification permissions. Linux: install `notify-send` |
| gstack update fails | Check internet connection; run `bash scripts/update-gstack.sh` manually |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

**[English](#stackpilot)** | 中文

自治 AI 开发团队框架，基于 Claude Code。给它一个想法，它交付生产级代码。

## 工作原理

Stackpilot 在 Claude Code 内运行五层流水线：

```
你写设计文档 ──► PM Agent 拆解任务 ──► Coordinator 调度 Agent
                                              │
                                ┌──────────┬───┼───┬──────────┐
                            架构师       开发      测试      文档
                           (审查)      (实现)    (测试)    (文档)
                                              │
                                         交付 ──► 你来验收
```

1. **创意** — 在 `docs/specs/` 中写设计文档并 commit。
2. **PM Agent** — `post-commit` hook 触发，将设计文档拆解为原子任务写入 `tasks/backlog.yml`。
3. **Coordinator** — 切换分支时 `post-checkout` hook 触发，按依赖顺序调度 Agent。
4. **专业 Agent** — Dev、QA、Architect、Docs 各司其职，遇到阻塞时上报到 `tasks/NEEDS_REVIEW.md`。
5. **交付** — 完成报告写入 `tasks/done/`，文档自动更新，桌面通知提醒你。

## 依赖项

### 必需

| 依赖 | 类型 | 说明 |
|------|------|------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | CLI 工具 | `claude` 命令需在 PATH 中 |
| [gstack](https://github.com/garrytan/gstack) | Claude Code skill | Garry Tan 开源的 28 个专业 skill（plan、ship、review、QA 等） |
| [superpowers](https://github.com/anthropics/claude-code-plugins) | Claude Code 插件 | 官方插件 — brainstorming、writing-plans、finishing-a-development-branch |
| git | CLI 工具 | 版本控制 |

### 可选

| 依赖 | 类型 | 说明 |
|------|------|------|
| [autoresearch](https://github.com/uditgoenka/autoresearch) | Claude Code skill | 用于标准功能的 `autoresearch:predict` 多视角分析 |
| [ui](https://github.com/anthropics/claude-code-plugins) | Claude Code 插件 | UI 设计 skill，涉及前端时自动调用 |

## 安装

### 前置条件

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)（终端可用 `claude` 命令）
- git

### 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

自动安装 Stackpilot 及所有依赖：
- Stackpilot agents + skills → `~/.claude/`
- [gstack](https://github.com/garrytan/gstack) — Garry Tan 开源的 28 个专业 Claude Code skill
- [autoresearch](https://github.com/uditgoenka/autoresearch) — 自治迭代 skill
- [superpowers](https://github.com/anthropics/claude-code-plugins) + [frontend-design](https://github.com/anthropics/claude-code-plugins) 插件（未安装时提示）

## 快速开始

### 初始化项目

```bash
cd /your/project
bash ~/.stackpilot/scripts/init.sh
```

会创建：
- `tasks/` 目录（backlog、in-progress、上报文件）
- `stackpilot.config.yml`（项目配置）
- Git hooks（`post-commit`、`post-checkout`）

### 编辑项目配置

```yaml
# stackpilot.config.yml
qa:
  coverage_threshold: 80
  test_command: npm test       # 或: pytest / go test ./... / cargo test
coordinator:
  worktree_limit: 3
  timeout_hours: 2
```

### 开始开发

**方式 A：使用 `/stackpilot` 命令（推荐）**

在 Claude Code 中输入 `/stackpilot`，会显示状态面板并引导工作流。

**方式 B：手动 git 工作流**

```bash
# 1. 写设计文档
mkdir -p docs/specs
cat > docs/specs/2026-04-01-login-page.md << 'EOF'
# 登录页面
实现邮箱密码登录。
## 需求
- 邮箱格式校验
- 密码强度提示
- 登录失败错误处理
EOF

# 2. 提交设计文档 → PM Agent 自动拆解任务
git add docs/specs/
git commit -m "feat: add login page spec"

# 3. 切换 feature 分支 → Coordinator 自动启动
git checkout -b feat/login-page
```

### 监控进度

```bash
# 查看任务状态
cat tasks/backlog.yml

# 查看 Agent 日志
cat tasks/coordinator.log
cat tasks/pm-agent.log

# 查看上报问题
cat tasks/NEEDS_REVIEW.md
```

### 处理上报

Agent 遇到阻塞时会写入 `tasks/NEEDS_REVIEW.md`，你会收到桌面通知。

```bash
# 查看问题
cat tasks/NEEDS_REVIEW.md

# 回复
echo "REPLY: 方案 B" >> tasks/NEEDS_REVIEW.md

# 重新触发 Coordinator
git checkout feat/login-page
```

## Agent 团队

| Agent | 职责 | 工具 | 触发方式 |
|-------|------|------|---------|
| PM Agent | 拆解设计文档为 `tasks/backlog.yml` | Read, Write, Glob | `post-commit`（检测到新 spec） |
| Architect Agent | 技术评审，风险标记 | Read, Write, Glob, Grep, WebSearch | Coordinator（standard 任务） |
| Dev Agent | 功能实现 | Read, Edit, Write, Bash, Glob, Grep | Coordinator |
| QA Agent | 写测试、跑测试、局部修复 | Read, Edit, Write, Bash, Glob, Grep | Coordinator |
| Docs Agent | 更新 README 和 API 文档 | Read, Edit, Write, Glob | Coordinator |
| Coordinator | 编排整个 Sprint | Read, Write, Bash, Glob | `post-checkout` / `/stackpilot` |

### 任务路由

按 `complexity` 字段路由：

- **light**（简单改动，≤3 文件）：Dev → QA（跳过 Architect 和 Docs）
- **standard**（多模块、架构决策）：Architect → Dev → QA → Docs

### 错误处理

- Agent 最多重试 3 次，然后标记 `soft-blocked`
- Coordinator 在累计 3 次失败后将 `soft-blocked` 转为 `blocked`
- 阻塞任务上报到 `tasks/NEEDS_REVIEW.md` 等待人工决策
- 超时任务（超过 `timeout_hours`）标记为 `failed`
- 循环依赖自动检测并上报

## 保持 gstack 更新

```bash
# 添加 crontab（每周一凌晨 3 点）
echo "0 3 * * 1 bash ~/stackpilot/scripts/update-gstack.sh" | crontab -

# 或在 Claude Code 中手动运行
/update-gstack
```

更新器在每次 pull 后验证必需 skill，失败则自动回滚。

## 在新机器上恢复

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

重复执行会安全地更新到最新版本。

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| Hook 没触发 | 运行 `ls -la .git/hooks/post-commit` 确认存在且可执行 |
| `claude: command not found` | 安装 Claude Code CLI 并确保在 PATH 中 |
| PM Agent 没有运行 | 确认 `tasks/` 目录存在（先运行 `init.sh`） |
| Coordinator 没启动 | 确认是分支切换（非文件 checkout）；查看 `tasks/coordinator.log` |
| 没收到桌面通知 | macOS：检查通知权限。Linux：安装 `notify-send` |
| gstack 更新失败 | 检查网络；手动运行 `bash scripts/update-gstack.sh` |

## 贡献

参见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
