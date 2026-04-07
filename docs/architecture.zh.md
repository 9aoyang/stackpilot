# Stackpilot 架构文档

> 最后更新：2026-04-07

Stackpilot 是一个由 git hook 驱动的多 Agent Sprint 编排框架。它将一份设计文档转化为可运行的代码，通过自动调度 AI Agent 流水线完成，无需任何人工交接。

---

## 核心模型

```
用户写 spec → 提交 → Agent 自动运行 → 代码出现
```

用户唯一的操作界面是 git 和 `stackpilot` skill，其余全部自动化。

---

## 目录结构

```
stackpilot/                        ← 框架安装目录
├── claude-config/
│   ├── agents/                    ← Agent 系统提示词（sp-*.md）
│   │   ├── sp-coordinator.md
│   │   ├── sp-pm.md
│   │   ├── sp-architect.md
│   │   ├── sp-dev.md
│   │   ├── sp-qa.md
│   │   └── sp-docs.md
│   └── skills/
│       ├── stackpilot/
│       │   ├── SKILL.md           ← /stackpilot 主入口
│       │   └── coordinator.md     ← coordinator 意图摘要（支持文件）
│       ├── stackpilot-auto/
│       │   └── SKILL.md           ← /stackpilot:auto 全自动模式
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot:compete 竞品差距分析
│       └── stackpilot-sync/
│           └── SKILL.md           ← /stackpilot:sync 外部 skill 同步
├── scripts/
│   ├── init.sh                    ← 项目初始化
│   ├── dispatch.sh                ← 与 AI provider 无关的 Agent 启动器
│   ├── restore.sh                 ← 重置运行时状态
│   ├── lib/config.sh              ← YAML 配置读取工具
│   ├── lib/version.sh             ← 自动升级，保留用户自定义
│   └── hooks/
│       ├── pre-commit.sh          ← 提交前校验 spec/plan 格式
│       ├── post-commit.sh         ← 新 spec/plan 提交时触发 sp-pm
│       └── post-checkout.sh       ← 切换分支时触发 sp-coordinator
├── templates/
│   ├── stackpilot.config.yml      ← 项目配置模板
│   ├── backlog.yml                ← 任务列表模板
│   ├── in-progress.yml            ← 进行中任务跟踪模板
│   └── NEEDS_REVIEW.md            ← 人工审阅收件箱模板
└── tests/

<项目根目录>/                      ← 用户的项目
├── stackpilot.config.yml          ← provider、qa、coordinator 配置
└── .stackpilot/                   ← 运行时状态（可选择加入 gitignore）
    ├── path                       ← stackpilot 安装路径
    ├── specs/                     ← 设计文档
    ├── plans/                     ← 实现计划
    └── tasks/
        ├── backlog.yml            ← 所有任务及其状态
        ├── in-progress.yml        ← 当前运行中任务 + 开始时间
        ├── NEEDS_REVIEW.md        ← 人工审阅收件箱（用户读这里）
        ├── done/                  ← 完成报告（TASK-ID.md）
        ├── arch-review/           ← 架构审查输出（TASK-ID.md）
        ├── .locks/                ← 并发 agent 文件锁
        └── .worktrees/            ← 后台 agent 的 git worktree 隔离
```

---

## Agent 流水线

### 标准任务（多模块、涉及架构决策）

```
sp-pm → sp-architect → sp-dev → sp-qa → sp-docs
```

### 轻量任务（单文件、需求明确）

```
sp-pm → sp-dev → sp-qa
```

轻量任务跳过 sp-architect 和 sp-docs，节省约 60% 的 Agent 开销。

> sp-qa 在每个 sp-dev 完成后立即调度（即时 review，非批量）。

---

## Agent 职责

| Agent | 职责 | 核心协议 |
|-------|------|---------|
| **sp-pm** | 读取 `.stackpilot/` 中的 spec/plan，写入任务到 `backlog.yml` | 自检（ID 唯一、depends_on 完整性、循环依赖检测）；5 字段任务描述（What/Where/How/Test hint/Verify）；追加写入；为每个任务设置 `complexity: light\|standard`；完成前验证 |
| **sp-architect** | 对照代码库审查任务；输出 `arch-review/TASK-ID.md` | 先分析现有代码模式；给出唯一的架构决策；完整实现蓝图；HIGH 风险任务额外进行 Security/Performance/Reliability 三角色对抗分析 |
| **sp-dev** | 实现任务 | 强制 TDD（RED-GREEN-REFACTOR）；4 阶段根因调查（观察→复现→追溯→假设）；开始前读 `git log` 避免重蹈失败路径；定位入口点+追踪调用链；原子变更 verify/fix 循环（含卡住检测）；3 轮失败后进入 soft-blocked；失败后回滚未提交变更 |
| **sp-qa** | 审查代码变更、编写并运行测试 | 两阶段代码审查（spec 合规 + 代码质量）；收到反馈时技术评估不盲从；基于 `git diff` 做代码审查（置信度 ≥ 80 才上报）；12 维场景测试矩阵；verify/fix 循环最多 3 轮；允许有限范围的生产代码修复 |
| **sp-docs** | 更新 README、内联注释、API 文档 | 在 QA 通过后运行；只更新文档，不改任何逻辑；完成前验证 |
| **sp-coordinator** | 编排整个流水线 | 每 task 即时 review（dev→qa 串联，非批量）；完整 soft-blocked 重试逻辑；读取 NEEDS_REVIEW → 处理超时 → 重试 soft-blocked → 调度 pending 任务 → 检查 Sprint 完成 |

---

## 事件流

### `git commit` — 新 spec 或 plan 被提交

```
post-commit.sh
  └─ 检测到 .stackpilot/specs/*.md 或 .stackpilot/plans/*.md 新增
       └─ dispatch.sh --agent sp-pm（后台运行）
            └─ sp-pm 读取 spec/plan → 写入任务到 backlog.yml
```

### `git checkout` — 切换分支

```
post-checkout.sh
  └─ dispatch.sh --agent sp-coordinator（后台运行）
       └─ sp-coordinator 入口检查清单：
            1. 处理 NEEDS_REVIEW.md
            2. 处理超时任务
            3. 重试 soft-blocked 任务（attempt_count < 3）
            4. 检测循环依赖
            5. 调度 pending 任务 → sp-architect / sp-dev / sp-qa / sp-docs
            6. Sprint 完成检查 → 清理 → 收尾工作流
```

### 用户主动触发（通过 `stackpilot` skill）

```
/stackpilot
  └─ 展示 Sprint 状态面板
       └─ 按状态路由：
            未初始化      → 运行 init.sh
            Sprint 干净   → 功能流程（轻量或标准路径）
            进行中         → A/B/C 选项
            有阻塞         → 展示升级问题，引导用户回复
            有失败         → 重试 / 跳过 / 分析
```

---

## 任务生命周期

```
pending → in-progress → done
                     ↘ soft-blocked（attempt_count++）→ pending（重试 ≤ 3 次）→ blocked
                     ↘ failed（超时）
```

- `soft-blocked`：Agent 自报失败（verify/fix 循环耗尽）；自动重试最多 3 次
- `blocked`：硬升级，需要用户通过 `NEEDS_REVIEW.md` 做决策
- `failed`：coordinator 侧超时（超过 `coordinator.timeout_hours`）

**NEEDS_REVIEW.md 协议：**
- Agent 或 coordinator 追加一个升级块（选项 A/B/C）
- 用户在底部追加 `REPLY: <决定>`
- 下一次 coordinator 运行读取回复、解除阻塞、清空文件

---

## Dispatch 层

`scripts/dispatch.sh` 与 AI provider 无关，执行流程：

1. 从 `stackpilot.config.yml` 读取 `provider.name`
2. Per-provider model routing：通过 `models.<provider>.<agent>` 三层配置键选择模型
3. 从 `claude-config/agents/<name>.md` 加载 Agent 系统提示词
4. 去除 frontmatter；追加任务相关 prompt
5. 构建对应 provider 的 CLI 命令：
   - `claude` — `claude -p <prompt> --allowedTools ...`
   - `codex` — `codex --approval-mode full-auto <prompt>`
   - `gemini` — `gemini -p <prompt>`
   - `custom` — `<provider.command> <prompt>`
6. 后台 agent 的 git worktree 隔离（自动创建、自动清理）
7. 超时强制执行（timeout/gtimeout 包裹）
8. 文件锁（locked_write，flock + mkdir 回退）
9. 后台运行（hooks）或前台运行（交互式使用）
10. PID 跟踪

每个 Agent 在 frontmatter 中声明工具列表（`tools: Read, Write, Bash, Glob`），Claude provider 下作为 `--allowedTools` 传入。

CLI 缺失时自动写入 `NEEDS_REVIEW.md`，提示用户安装对应 provider CLI。

---

## 配置

`stackpilot.config.yml`（项目根目录）：

```yaml
provider:
  name: claude

qa:
  coverage_threshold: 80
  test_command: npm test    # init.sh 自动探测

coordinator:
  worktree_limit: 3
  timeout_hours: 2

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
    sp-architect: gemini-2.5-pro
```

---

## Skill 入口

| Slash Command | 目录 | 用途 |
|--------------|------|------|
| `/stackpilot` | `stackpilot/` | 主入口：状态面板 + 功能流程 + coordinator 运行 |
| `/stackpilot:auto` | `stackpilot-auto/` | 全自动模式：跳过所有确认，代码停在 feature branch |
| `/stackpilot:compete` | `stackpilot-compete/` | 以竞品重度用户视角做差距分析 |
| `/stackpilot:sync add` | `stackpilot-sync/` | 新增并提炼一个外部 skill |
| `/stackpilot:sync check` | `stackpilot-sync/` | 检查已跟踪 skill 是否有更新 |

---

## 关键设计决策

**无常驻进程。** coordinator 在 git 事件（commit、checkout）时运行，无需管理任何后台进程。

**状态存为纯文本文件。** `backlog.yml`、`in-progress.yml`、`NEEDS_REVIEW.md` 均人类可读，可按需加入 git 跟踪。

**`.stackpilot/` 是否进 gitignore 由用户决定。** 运行时状态默认本地私有。需要团队共享 Sprint 状态的，移除 gitignore 条目即可。

**零外部 skill 依赖。** 所有 Agent 协议均内联在 `claude-config/` 文件中，无需安装任何外部插件即可工作。

**任务粒度的复杂度路由。** 每个任务携带 `complexity: light | standard`，coordinator 据此路由——轻量任务跳过 architect 和 docs Agent，简单改动节省约 60% 的 Agent 开销。

**Soft-blocked 重试循环。** Agent 自报失败（`soft-blocked`），而非立即升级。coordinator 最多自动重试 3 次后才需要人工介入，避免瞬态失败（构建抖动、上下文问题）打断用户。

**Git 即记忆。** sp-dev 每次开始任务前读取 `git log --oneline -20`，从提交历史中识别已失败的修复路径，不重复尝试无效方案。Optimize Sprint 将此原则显式化——每次迭代以 `experiment(<scope>):` 前缀提交，历史记录清晰可读。

**原子变更原则。** sp-dev verify/fix 循环和 Optimize Sprint 中，每次修复只做一个逻辑变更（一句话能描述清楚）。因果关系清晰，便于回滚，也让卡住信号变得明确（同样的错误出现两次 = 换思路）。

**测试驱动开发。** sp-dev 强制 RED-GREEN-REFACTOR，先写测试再写实现代码。

**根因调查优先于修复。** sp-dev 在修复前执行 4 阶段调查（观察→复现→追溯→假设），防止治标不治本。

**按 Provider 路由模型。** 配置支持 `models.<provider>.<agent>`，同一项目可同时用 Claude 和 Codex，每个 agent 独立配置模型。

**Git worktree 隔离。** 后台 agent 在独立 worktree 中运行，防止并行 agent 互相干扰。

**安全版本升级。** version.sh 升级前 diff 检测，用户自定义的 agent/skill 自动备份为 `.pre-upgrade.bak`。

**自动探测项目配置。** init.sh 自动识别项目语言、测试框架和可用 CLI。支持 Node.js、Python、Go、Rust、Ruby、Java/Kotlin、Elixir、PHP、.NET。

**Optimize Sprint。** 专为可量化改进目标设计的 Sprint 类型（性能、错误率、包体积等）。开工前需定义 Goal + Scope + Metric + Verify 四参数。自主迭代循环，TSV 格式记录每轮结果，回归时自动 `git revert`。灵感来源：autoresearch（uditgoenka/autoresearch）。

---

## 演进记录

| 日期 | 变更 |
|------|------|
| 2026-04-07 | init.sh 自动探测项目栈；sp-dev 强制 TDD + 根因调查；coordinator 每 task 即时 review；sp-qa 两阶段代码审查；per-provider model routing（models.\<provider\>.\<agent\>）；dispatch git worktree 隔离；pre-commit hook 校验 spec 格式；文件锁（flock/mkdir）；超时强制执行；安全版本升级（.bak 保留）；coding 阶段自动执行 + 每 task 进度简报 |
| 2026-04-07 | Standard Feature：澄清问题改为逐个深入（不再一次性批量提问）；新增 Phase 1.5 Visual Companion（来自 superpowers brainstorming 的浏览器 mockup/图表服务器）；compete skill 升级为 12 维度迭代探索循环 + 5 角色辩论共识机制（含 Devil's Advocate 少数意见保留） |
| 2026-04-04 | 集成 autoresearch 核心模式：sp-dev 增加 git 即记忆 + 原子变更 + 卡住检测；sp-qa 增加 12 维场景测试矩阵；sp-architect 增加 HIGH 风险多角色对抗分析；SKILL.md 新增 Optimize Sprint 模式；新增 docs/sync.md |
| 2026-04-04 | 所有 Agent 重命名为 `sp-*` 前缀；运行时状态迁移到 `.stackpilot/`；移除所有外部 skill 依赖；内联 brainstorming、writing-plans、finishing、code-architect、code-explorer、code-reviewer 协议 |
| 2026-04-01 | 新增复杂度路由（light/standard）、sp-dev verify/fix 循环、coordinator soft-blocked 重试机制 |
| 2026-03-29 | 初始实现：coordinator + pm + architect + dev + qa + docs Agent |
