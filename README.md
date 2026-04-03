# Stackpilot

[![CI](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/9aoyang/stackpilot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**English** | [中文](#中文文档)

Autonomous AI development team for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Write a spec, get production-ready code — with tests, docs, and code review.

```
Spec ──► PM Agent ──► Architect ──► Dev ──► QA ──► Docs ──► Delivery
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

Installs Stackpilot and all dependencies ([gstack](https://github.com/garrytan/gstack), [autoresearch](https://github.com/uditgoenka/autoresearch), [superpowers](https://github.com/anthropics/claude-code-plugins) plugin). Requires [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) and git.

## Usage

### 1. Init your project

```bash
cd /your/project
bash ~/.stackpilot/scripts/init.sh
# Edit stackpilot.config.yml — set qa.test_command for your stack
```

### 2. Write a spec and commit

```bash
cat > docs/specs/2026-04-01-login.md << 'EOF'
# Login Page
- Email/password auth
- Input validation
- Error handling
EOF

git add docs/specs/ && git commit -m "feat: login spec"
# → PM Agent auto-decomposes into tasks
```

### 3. Switch branch — agents take over

```bash
git checkout -b feat/login
# → Coordinator dispatches Architect → Dev → QA → Docs
```

Or just type `/stackpilot` in Claude Code — it shows status and guides the workflow.

### 4. Handle escalations

Agents write to `tasks/NEEDS_REVIEW.md` when blocked (you get a desktop notification):

```bash
echo "REPLY: Option B" >> tasks/NEEDS_REVIEW.md
git checkout feat/login   # re-triggers Coordinator
```

## Config

```yaml
# stackpilot.config.yml
qa:
  coverage_threshold: 80
  test_command: npm test    # pytest / go test ./... / cargo test
coordinator:
  timeout_hours: 2
```

## Dependencies

| Dependency | Required | Description |
|-----------|----------|-------------|
| [gstack](https://github.com/garrytan/gstack) | Yes | 28 Claude Code skills by Garry Tan |
| [superpowers](https://github.com/anthropics/claude-code-plugins) | Yes | Official plugin (brainstorming, writing-plans) |
| [autoresearch](https://github.com/uditgoenka/autoresearch) | No | Multi-perspective analysis |
| [frontend-design](https://github.com/anthropics/claude-code-plugins) | No | UI design skill |

All auto-installed by `install.sh`.

## [Contributing](CONTRIBUTING.md) | [License](LICENSE)

---

<a id="中文文档"></a>

# 中文文档

**[English](#stackpilot)** | 中文

基于 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 的自治 AI 开发团队。写设计文档，交付生产级代码 — 含测试、文档和代码审查。

```
设计文档 ──► PM ──► 架构师 ──► 开发 ──► 测试 ──► 文档 ──► 交付
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/9aoyang/stackpilot/main/install.sh | bash
```

自动安装 Stackpilot 及所有依赖（[gstack](https://github.com/garrytan/gstack)、[autoresearch](https://github.com/uditgoenka/autoresearch)、[superpowers](https://github.com/anthropics/claude-code-plugins) 插件）。需要 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 和 git。

## 使用

### 1. 初始化项目

```bash
cd /your/project
bash ~/.stackpilot/scripts/init.sh
# 编辑 stackpilot.config.yml — 设置 qa.test_command
```

### 2. 写设计文档并提交

```bash
cat > docs/specs/2026-04-01-login.md << 'EOF'
# 登录页面
- 邮箱密码登录
- 输入校验
- 错误处理
EOF

git add docs/specs/ && git commit -m "feat: login spec"
# → PM Agent 自动拆解任务
```

### 3. 切换分支 — Agent 接管

```bash
git checkout -b feat/login
# → Coordinator 调度 架构师 → 开发 → 测试 → 文档
```

也可以在 Claude Code 中输入 `/stackpilot`，查看状态并引导工作流。

### 4. 处理上报

Agent 遇阻时写入 `tasks/NEEDS_REVIEW.md`（桌面通知提醒）：

```bash
echo "REPLY: 方案 B" >> tasks/NEEDS_REVIEW.md
git checkout feat/login   # 重新触发 Coordinator
```

## 配置

```yaml
# stackpilot.config.yml
qa:
  coverage_threshold: 80
  test_command: npm test    # pytest / go test ./... / cargo test
coordinator:
  timeout_hours: 2
```

## 依赖

| 依赖 | 必需 | 说明 |
|------|------|------|
| [gstack](https://github.com/garrytan/gstack) | 是 | Garry Tan 的 28 个 Claude Code skill |
| [superpowers](https://github.com/anthropics/claude-code-plugins) | 是 | 官方插件（brainstorming、writing-plans） |
| [autoresearch](https://github.com/uditgoenka/autoresearch) | 否 | 多视角分析 |
| [frontend-design](https://github.com/anthropics/claude-code-plugins) | 否 | UI 设计 |

全部由 `install.sh` 自动安装。

## [贡献指南](CONTRIBUTING.md) | [许可证](LICENSE)
