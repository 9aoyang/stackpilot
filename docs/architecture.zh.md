# Stackpilot 架构文档

> 最后更新：2026-06-10

StackPilot 是面向 coding agents 的通用方法论。它把需求推进为经过验证的软件：
探索、设计、spec、criteria、plan、执行、审查、收尾都属于核心流程。不同宿主通过
adapter 用自己的原生工具实现同一套门禁；Claude Code adapter 目前是最完整实现。

---

## 核心模型

```
用户描述功能 → StackPilot 入口 → 内部门禁路由 → 宿主适配器执行 → 证据门禁 → 收尾
```

用户入口是 StackPilot，不是一张 process skills 清单。在 Claude Code 中，可见入口是
`/stackpilot`，或者由 `stackpilot-bootstrap` 路由的自然语言需求。
`stackpilot-methodology` 和更小的 portable skills 是保持跨宿主门禁严格的内部 gate；
`/stackpilot` 命令是 Claude Code 宿主适配器，用来执行自主 sprint。

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
│       ├── stackpilot-methodology/
│       │   └── SKILL.md           ← 内部便携式方法论核心
│       ├── stackpilot-planning/
│       │   └── SKILL.md           ← 内部 implementation planning gate
│       ├── stackpilot-workspace/
│       │   └── SKILL.md           ← 内部 workspace 隔离 / setup / baseline gate
│       ├── stackpilot-plan-execution/
│       │   └── SKILL.md           ← 内部逐 task 执行 gate
│       ├── stackpilot-parallel-agents/
│       │   └── SKILL.md           ← 内部独立并行分派 gate
│       ├── stackpilot-review-response/
│       │   └── SKILL.md           ← 内部 review feedback 处理 gate
│       ├── stackpilot-completion-verification/
│       │   └── SKILL.md           ← 内部 evidence-before-claims 完成门
│       ├── stackpilot-skill-authoring/
│       │   └── SKILL.md           ← 维护者专用 skill 创建/更新 gate
│       ├── stackpilot/
│       │   ├── SKILL.md           ← /stackpilot 主入口
│       │   └── references/
│       │       ├── run-sprint.md
│       │       ├── sprint-finish.md
│       │       ├── 12-qa-matrix.md
│       │       └── views/         ← 可选浏览器视图模板
│       │           ├── design-options.html
│       │           ├── dashboard.html
│       │           ├── spec-review.html
│       │           ├── finish-report.html
│       │           └── architecture.html
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot-compete 竞品差距分析
│       ├── stackpilot-research/
│       │   └── SKILL.md           ← /stackpilot-research 深度研究（横纵分析法）
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync 外部 skill 同步
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging（便携式）
├── scripts/
│   ├── init.sh                    ← 项目初始化（精简：目录 + 测试命令检测）
│   ├── lib/
│   │   └── config.sh              ← YAML 配置读取工具
│   ├── sync-skills.sh             ← 非 skillshare 安装下的幂等 Claude skill 同步
│   ├── hooks/
│   │   ├── post-commit            ← commit 后自动同步新 skill
│   │   ├── pre-merge-commit       ← 阻止非 squash merge 到 main/master
│   │   └── README.md
│   └── preview/
│       ├── start-server.sh        ← sprint/可视化服务器（v2: HTML 视图宿主 + WS 状态推送）
│       ├── stop-server.sh
│       ├── server.cjs             ← 扩展了 /sprints/<slug>、/api/action、/api/state
│       └── helper.js              ← WS 客户端 + window.sp.{action,state} sprint API
├── hooks/
│   ├── hooks.json                 ← Claude plugin SessionStart hook manifest
│   ├── hooks-cursor.json          ← Cursor plugin sessionStart hook manifest
│   ├── session-start              ← 会话开始时注入 stackpilot-bootstrap
│   └── pre-tool-use               ← process skill 激活前阻断 feature/bug/code 工具调用
├── .claude-plugin/
│   └── plugin.json                ← Claude Code plugin metadata
├── .cursor-plugin/
│   └── plugin.json                ← Cursor StackPilot routing/package metadata
├── .codex-plugin/
│   └── plugin.json                ← Codex StackPilot package metadata
├── gemini-extension.json          ← Gemini extension metadata
├── GEMINI.md                      ← Gemini 路由 + tool mapping 上下文
└── templates/
    ├── stackpilot.config.yml      ← 配置模板（仅 qa 部分）
    └── stackpilot-inner-gitignore

<项目根目录>/                      ← 用户的项目
├── stackpilot.config.yml          ← qa 配置（test_command, coverage_threshold）
└── .stackpilot/
    ├── ARCHITECTURE.md            ← 项目记忆（数据层）
    ├── specs/                     ← 设计文档 + 验收标准（数据层）
    ├── plans/                     ← 实现计划（数据层）
    ├── feedback/                  ← 外部 audit inbox（数据层）
    │   ├── open/*.md              ← 未解决的人类/外部 feedback
    │   └── resolved/*.md          ← 已处理且包含 # Resolution 的 feedback
    ├── runs/<sprint>/TASK-*/state.json   ← 每任务 phase 状态（数据层）
    ├── runs/<sprint>/events.jsonl        ← 持久化 dispatch / verification / decision 事件日志
    ├── runs/<sprint>/handoff.json        ← 精简 phase/status/next-action 恢复契约
    ├── runs/<sprint>/sprint-evals.md     ← 基于 events/state/criteria 的收尾复盘
    └── views/                     ← 可选生成的浏览器视图（视图层，gitignore）
        └── <sprint>/{design-options,dashboard,spec-review,finish-report}.html
```

---

## Agent 流水线

### 标准任务（多模块、涉及架构决策）

```
sp-architect → sp-dev → sp-qa
```

### 轻量任务（单文件、需求明确）

```
sp-dev
```

轻量任务跳过 sp-architect 和 sp-qa dispatch，简单改动节省约 60% Agent 开销；
主会话仍运行便宜的确定性一致性检查。

> sp-qa 在每个 sp-dev 完成后立即调度（即时 review，非批量）。

---

## Agent 职责

| Agent | 职责 | 核心协议 |
|-------|------|---------|
| **sp-architect** | 对照代码库审查任务；返回架构决策 | 每次 review 都用 extended thinking（不限 HIGH）；定风险前先列 ≥2 个具体失败模式；Risk 评级必须配一行说理（blast radius / rollback cost）；读取 `.stackpilot/ARCHITECTURE.md § Key Design Decisions`；唯一架构决策 + 完整蓝图；HIGH 跑 3 personas，LOW/MEDIUM 至少 1 个；输出 `## Decision Candidates`；新依赖/结构冲突返回 `[ESCALATION]` |
| **sp-dev** | 实现任务 | 读 `git log` 避免重复失败路径；追踪入口点+调用链；强制 TDD（RED-GREEN-REFACTOR）；4 阶段根因调查；verify/fix 循环含卡住检测；失败后回滚；3 轮后返回 `[SOFT-BLOCKED]` |
| **sp-qa** | 审查代码、编写测试 | Stage 1-3 语义审查（spec 合规 + 代码质量 + 对抗性）；Stage 4 确定性 grep 审计（absolute-claim / scope-completeness / dead-reference，HIGH 风险强制）；读取 `.stackpilot/ARCHITECTURE.md` 获取 Review Patterns 和 Conventions；输出 `## Pattern Candidates`（从不直接写）；Layer 2 全新上下文 Deep Review（HIGH 风险默认开）；置信度 ≥ 80。**只在 standard 复杂度下 dispatch** — 轻量任务靠 sp-dev 的 TDD 兜。 |
| **sp-docs** | 更新 README、注释、API 文档 | 机械文档任务使用 haiku 模型层；QA 通过后运行；只改文档不改逻辑。 |

---

## Agent 调度方式

### Claude Code

Claude 版 `/stackpilot` skill 使用 Claude Code 原生工具编排 agent：

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

### 用户主动触发（通过 StackPilot 入口）

```
/stackpilot [功能描述]
  └─ 展示 Sprint 状态 + 扫描工作区
       └─ 按状态路由：
            未初始化        → 运行 init.sh
            工作区有残留    → tidy（清理工作流文件、修剪分支/worktree）
            Sprint 中断     → resume（匹配 plan 任务与 git log，提供继续/重新开始）
            Sprint 干净     → 询问需求 → 选择自动/交互模式 → 功能流程
            进行中           → 继续 sprint
```

**Standard Feature — 5 个 Node（终端优先，浏览器按需）：**

```
Node 1 — Exploration: 先 scout 代码（grep + 读 2-5 个文件）→ 逐个澄清问题 → spec 中记录 canonical refs
Node 2 — Design: 终端列出 2-3 个方案；只有视觉布局、交互或非平凡图示能降低歧义时才生成 design-options.html
Node 3 — Spec & Criteria: 写 spec → auto-verify（grep 检查）→ 12-QA 矩阵 → 派生验收 criteria → 终端 review；可编辑/视觉扫描更高效时才生成 spec-review.html
Node 4 — Plan & Run Sprint: 写 plan → auto-verify → traceability trace → 建分支 → 初始化 handoff.json/state.json/events.jsonl → 多 wave/密集进度时可选 dashboard.html → 按 wave 并行调度 sub-agent → 每个边界更新 handoff
Node 5 — Finish: pre-merge gate（typecheck/lint/tests）→ sprint-evals.md + feedback inbox gate → closure gate（criteria 全绿 / CHANGELOG / patterns 浮现 / critical feedback 已处理）→ 终端 A/B/C/D；密集时间线/报告审阅时才生成 finish-report.html
  ↳ pre-merge-commit hook 硬性拒绝非 squash 的 merge
```

行内验证（grep / 12-QA / traceability）是 node 内的子步骤，不再是独立 phase。浏览器
视图在 Node 2/3/4/5 按需产出；数据层 source-of-truth（spec / plan / criteria /
handoff.json / state.json / events.jsonl / sprint-evals.md / feedback inbox）
保持 markdown/JSON 供 sub-agent 消费。

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
- 持久化：plan 文件（git 跟踪）、每任务 `state.json`、sprint 级 `events.jsonl`

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

## 入口层级

StackPilot 刻意只暴露一个常规用户入口。其他 skill 文件存在，是为了让支持
Agent Skills 的宿主可以机械路由到严格门禁；它们是实现面，不是面向用户的命令分类。

| 层级 | 入口 | 用途 |
|------|------|------|
| 面向用户 | `/stackpilot` | **Claude Code 主入口** — tidy + resume + 状态 + 自动/交互模式 + Sprint 执行。自然语言 feature request 会在可能时由 bootstrap 路由到这里。 |
| 默认内部门禁 | `stackpilot-methodology` | 宿主无关 StackPilot 流程：探索 → 设计 → spec/criteria → plan → 执行 → 审查 → 收尾。 |
| 默认内部门禁 | `stackpilot-planning` | 从已批准 spec/design 生成可执行 implementation plan。 |
| 默认内部门禁 | `stackpilot-workspace` | 实现前的 workspace 隔离、setup、clean baseline verification。 |
| 默认内部门禁 | `stackpilot-plan-execution` | 按 task 执行既有 plan，包含 TDD、spec review、quality review、证据门禁。 |
| 默认内部门禁 | `stackpilot-parallel-agents` | 独立任务、失败域、review domain、调研目标的并行分派。 |
| 默认内部门禁 | `stackpilot-review-response` | 技术验证 review feedback，按 scope 修复。 |
| 默认内部门禁 | `stackpilot-completion-verification` | 完成、merge、PR、成功声明前的新鲜证据门。 |
| 默认内部门禁 | `tdd-development` | TDD + verify/fix + 合理化阻断。 |
| 默认内部门禁 | `qa-12-dimensions` | 12 维测试覆盖 + 代码审查。 |
| 默认内部门禁 | `architecture-review` | 代码库模式分析 + 实现蓝图。 |
| 默认内部门禁 | `systematic-debugging` | 4 阶段根因调查 + 红旗检测。 |
| Bootstrap only | `stackpilot-bootstrap` | SessionStart 路由纪律；不是面向用户的命令。 |
| 专家按需 | `/stackpilot-compete` | 以竞品重度用户视角做差距分析。 |
| 专家按需 | `/stackpilot-research` | 横纵分析法深度研报。 |
| 维护者专用 | `/stackpilot-sync` | 外部 skill 追踪和同步。 |
| 维护者专用 | `stackpilot-skill-authoring` | StackPilot skill 创建/更新，验证路由、文档、测试。 |

---

## Agent Skills 合规

Stackpilot 遵循 Anthropic 维护的 [Agent Skills 开放标准](https://agentskills.io)。

**方法论门禁** — StackPilot route 使用的 portable internals，可在任何 Agent
Skills 兼容产品中使用（Cursor、VS Code Copilot、Gemini CLI、Codex、JetBrains
Junie 等 25+）：

| Gate | 功能 | 暴露层级 |
|------|------|----------|
| `stackpilot-methodology` | 宿主无关 sprint 方法论与门禁 | 默认内部 |
| `stackpilot-planning` | spec/design 到可执行 implementation plan | 默认内部 |
| `stackpilot-workspace` | workspace 隔离、setup、baseline verification | 默认内部 |
| `stackpilot-plan-execution` | 既有 plan 执行、review、证据门禁 | 默认内部 |
| `stackpilot-parallel-agents` | 独立并行分派与主控整合验证 | 默认内部 |
| `stackpilot-review-response` | review feedback 技术验证与响应 workflow | 默认内部 |
| `stackpilot-completion-verification` | evidence-before-claims 完成门 | 默认内部 |
| `stackpilot-skill-authoring` | skill 创建/更新质量门 | 维护者专用 |
| `tdd-development` | TDD 循环 + verify/fix + 合理化阻断 | 默认内部 |
| `qa-12-dimensions` | 两阶段代码审查 + 12 维测试覆盖 | 默认内部 |
| `architecture-review` | 模式分析 + 唯一架构决策 + 蓝图 | 默认内部 |
| `systematic-debugging` | 4 阶段根因调查 + 红旗检测 | 默认内部 |

**Host Adapters** — 用宿主原生工具实现同一套 Methodology Core：

| Skill | 功能 |
|-------|------|
| `stackpilot` | Claude Code adapter：用 Agent、TaskCreate、worktree isolation、preview server、state、event log 执行完整 sprint。 |

**已打包的宿主入口**：

| 宿主 | 包入口 | 状态 |
|------|--------|------|
| Claude Code | `.claude-plugin/` + `hooks/hooks.json` | 完整自主 sprint adapter + SessionStart auto-route |
| Cursor | `.cursor-plugin/` + `hooks/hooks-cursor.json` | StackPilot routing bootstrap + portable internal gates |
| OpenAI Codex | `.codex-plugin/plugin.json` | StackPilot package metadata + portable internal gates；完整 sprint adapter 尚未实现 |
| Gemini CLI | `gemini-extension.json` + `GEMINI.md` | StackPilot routing context、tool mapping、portable internal gates |

**渐进式展开** — SKILL.md 控制在 500 行以内，重内容（visual companion、optimize sprint、sprint finish）放在 `references/` 按需加载。

**Superpowers gap audit** — `docs/superpowers-gap-audit.md` 把每类
Superpowers workflow 映射到 StackPilot 中覆盖同类产品行为的 gate 或 adapter。它不是
要求 StackPilot 匹配 Superpowers 的 skill 数量或公开命令形态。

---

## 关键设计决策

**一个 StackPilot 入口。** 常规产品体验是"使用 StackPilot"，由 bootstrap、hook 和
宿主适配器路由到默认门禁。更小的 portable skills 仍然是真实文件，用于 Agent
Skills 兼容、触发和测试，但它们不是公开产品形态。

**方法论核心优先。** StackPilot 是通用方法论，不是单一宿主脚本。核心定义门禁
和 artifact；adapter 决定具体工具。

**Host Adapter Contract。** adapter 必须保留核心门禁：实现前先设计、机械可验收
criteria、plan traceability、TDD 或说明豁免、spec-compliance review 先于 quality
review、推进 phase 前独立验证、完成前 fresh verification，以及破坏性/外部副作用
safety gate。

**Claude Code adapter（v2）。** Agent 通过 Claude Code 的 Agent tool 调度，带 `isolation: "worktree"`。无自建 bash dispatcher、无手动 worktree 管理、无文件锁。Claude Code 处理所有基础设施。

**Session bootstrap auto-route（v2.3）。** Claude plugin 安装
`hooks/session-start`，每个新会话都会注入 `stackpilot-bootstrap`。这替换旧的
explicit-only 姿态：用户仍可手动输入 `/stackpilot`，但自然语言 feature work 会在
读文件或实现前自动路由进去。用户和项目指令仍是最高优先级，所以"跳过规划"、
"只回答"、"我自己验证"这类显式要求会覆盖自动路由。

**PreToolUse 路由门。** 只靠 prompt routing 对所有模型都不够可靠。Claude/Cursor
包会安装 `hooks/pre-tool-use`，对自然 feature/bug/code work，在 StackPilot process
skill 激活前阻断实现或检查类工具。hook 无法读取 transcript 时 fail-open，并尊重用户显式 opt-out。

**Prompt 级 Agent 间通信。** Agent 输出直接作为 prompt 上下文传递给下游 Agent。无中间文件（arch-review/、done/）。主会话即 coordinator。

**Controller contract gates。** Agent 输出会进入下游 prompt，但主控不能信任
success report。每次推进 task phase 前，主控必须检查 Completion Output 必填段、
独立查看 git diff、复跑或核验报告中的命令证据，并确认 criteria Status 已写回数据层。

**Plan + handoff + state + event log 即持久层。** 任务在会话内通过 TaskCreate 跟踪。Plan 文件定义预期工作；`handoff.json` 记录主控 phase 和 next action；每任务 `state.json` 记录 phase 完成状态；sprint 级 `events.jsonl` 记录 dispatch、verification、safety、user/action decision。resume 先读 handoff，再读 state，只有 legacy sprint 缺失 state 时才回退 git history。

**数据层 handoff 作为恢复契约。** `.stackpilot/runs/<sprint>/handoff.json` 记录主控 phase、status、inputs/outputs、decisions 和 next action。它刻意保持精简：用它恢复 phase 边界，再读 `state.json` 与 `events.jsonl` 获取详细证据。

**Sprint evals 来自 events/state/criteria。** Sprint Finish 会从 `events.jsonl`、每任务 `state.json` 和 acceptance criteria 写出 `.stackpilot/runs/<sprint>/sprint-evals.md`。内容包括任务总数、retry 与 verify/fix 轮次、常见失败 gate、plateau/stuck 信号，以及 stop/continue/change-strategy 建议。这样保留 eval loop 的价值，但不恢复已删除的 `/stackpilot-bench` runner。

**Feedback inbox audit loop。** `.stackpilot/feedback/open/*.md` 存放人类或外部 audit feedback，直到 Sprint Finish 处理。未解决的 HIGH/CRITICAL feedback 会在 merge 决策前暴露；处理后的条目只有在追加 `# Resolution` 记录证据与处置后，才移动到 `.stackpilot/feedback/resolved/`。

**零外部依赖。** 所有 Agent 协议内联，无需安装任何外部插件。

**任务粒度的复杂度路由。** `complexity: light | standard`，轻量跳过 architect，省约 60% Agent 开销。

**Soft-blocked 重试。** Agent 返回 `[SOFT-BLOCKED]`，主会话重试最多 3 次才需人工。

**Git 即记忆。** sp-dev 每次任务前读 `git log --oneline -20`，不重复已失败的方案。

**显式 subagent_type 调度。** SKILL.md 的 `Agent()` 调用显式传 `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"` / `"sp-docs"`，让 Claude Code 路由到注册好的 agent（含 frontmatter 里的 model 和 tool 限制），不退化到 `general-purpose`。要求：agent 必须在 `~/.claude/agents/` 或已安装的 plugin 里。Claude Code 启动时缓存注册表——装完必须重启。sp-docs 按 task.type 路由：`type: docs` → sp-docs（haiku tier），其他 → sp-dev（sonnet tier）。

**不和 frontier coding model 抢活。** Agent 方法论文件只规定 stackpilot 的编排契约——输入格式、完成报告格式、升级信号、安全门、事件日志、跨 sprint 记忆挂钩。**不**写"怎么做 TDD / 怎么做 code review / 怎么调试"这些通用工程方法论。2026-04-17 的重构按这条原则砍了 sp-dev 和 sp-qa 方法论 ~47%，对更新的 Claude Code 与 OpenAI Codex 模型族仍然适用。

**Sprint Finish 自验证。** Step 2 启动 dev server 后，主 agent 在交给用户前自动 curl 一次 preview URL 并报 HTTP 状态。非 2xx/3xx 或连接失败会打出 server log 尾 20 行——抓住"进程起来了但应用 500"这类回归，零 per-task 开销。

**Action Safety Gate 不被 auto mode 绕过。** Auto mode 可以跳过常规用户确认，但不能绕过破坏性或外部副作用边界。force push、remote delete、production database 改动、credential 移动、公开上传 repo 数据、部署、破坏性 MCP/app action、关闭验证门禁都必须显式问用户并记录到 `events.jsonl`。

**前端任务必须验证渲染态。** 只要任务改了用户可见 UI，criteria 至少包含一个 rendered-page check：browser/devtools smoke、screenshot 或 DOM 断言、responsive overflow check、或项目原生 Playwright/Cypress route test。Node 5 的 curl 只能证明服务有响应，不能证明视觉状态正确。

**OpenAI Codex 边界。** Methodology Core 与 OpenAI Codex 的 Agent Skills 发现模型
兼容。Codex adapter 应该用 Codex 原生 skills、subagents、workspaces、
browser/app verification、PR 机制实现 Host Adapter Contract，而不是复制
Claude Code-specific Agent 调用。

**单文件项目记忆。** `.stackpilot/ARCHITECTURE.md` 是项目级记忆的唯一落点，固定章节：What This Project Is / Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns。只有主 agent 在 Sprint Finish Step 4a 写它；子 agent 全部只读——`sp-architect` 读 `§ Key Design Decisions` 作为历史决策参考，HIGH 风险时通过完成报告里的 `## Decision Candidates` 块上交新决策；`sp-qa` 读 `§ Review Patterns` 与 `§ Conventions & Gotchas`，发现新模式时通过 `## Pattern Candidates` 块上交。主 agent 在 Sprint Finish 决定是否合入。写操作串行在 feature branch 上，规避 worktree 并发写冲突。

**强制 TDD。** RED-GREEN-REFACTOR，先写测试再写实现。

**根因调查优先。** 4 阶段调查（观察→复现→追溯→假设）后才修复。

---

## 演进记录

| 日期 | 变更 |
|------|------|
| 2026-06-16 | **外部方法刷新：handoff、evals、feedback inbox。** 重新检查 autoresearch 与 LLM Wiki 风格仓库后，只吸收持久数据层能力：`handoff.json` 用于 phase 恢复，`sprint-evals.md` 用于 plateau/retry/gate 复盘，`.stackpilot/feedback/open|resolved` 用于外部 audit feedback。刻意不恢复 `/stackpilot-bench`，也不新增 runtime runner。 |
| 2026-06-10 | **单一 StackPilot 入口模型。** 将 portable `stackpilot-*` skills 重新定义为默认内部门禁和 adapter primitives，而不是用户可见 skill catalog。用户从 `/stackpilot` 或自然语言 StackPilot routing 开始；bootstrap/hooks/host adapters 决定何时触发 planning、workspace、execution、parallel、review-response、completion、TDD、QA、architecture、debugging gates。Superpowers 对比保持为 workflow 覆盖审计，不作为 skill 数量对齐目标。 |
| 2026-06-10 | **Methodology Core + Host Adapters 产品重定位。** 新增便携式 `stackpilot-methodology` 作为宿主无关核心，把 `/stackpilot` 重新定义为 Claude Code adapter。StackPilot 的产品边界变成方法论与门禁，而不是单一宿主实现。后续 Codex/Gemini/Cursor adapter 必须实现 Host Adapter Contract，而不是 fork 一套流程。 |
| 2026-06-07 | **v2.2.0**：官方一线进度刷新。移除 live prompt 中过期的 Claude/Opus 点版本锚点；同步 SKILL.md 与 run-sprint 的架构审查触发条件（`standard` task，而不是 HIGH risk）；用 `find` 替换 zsh 下不安全的 `.claude/plans/*.md` glob；在 SKILL / Run Sprint / Finish 加 Action Safety Gate；新增 sprint 级 `events.jsonl` 作为 dispatch / verification / decision 的持久证据；前端任务要求 rendered UI verification；明确 portable skills 可用于 OpenAI Codex，但完整自主 sprint adapter 仍是 Claude Code-specific。 |
| 2026-05-25 | **v2.1.0**: Skill Tighten — 通过 sub-agent 契约做 sister-file sync。 Node 1 加 Scope Lock（多文件 refactor 前列 will-touch / will-NOT-touch）；Node 3 § 3.1 加"默认最小有效版本"引导；Node 4 plan task schema 加可选 `sister_files` / `shared_field_grep`，§ 4.2 加对应 grep verify；Node 5 pre-merge 显式三件套（typecheck/lint/test）+ 残留脚本扫描（`scripts/(migrate\|audit\|debug\|oneshot)-*` 命中提示是否合并前删除）。Sub-agent 接力：sp-architect Implementation Blueprint 加 `Will NOT touch`；sp-dev Required behaviors 加 Sister-file ack + Completion Output 加 `## Sister-File Sync` 段；sp-qa Consistency Audit 加第 4 条 sister-file sync audit + Adversarial Angles 加 `sister-file sync`。原因：insights 报告（2026-05-25 / 283 sessions / 4520 messages）跨项目 5 大稳定 friction 中 wrong_approach（34 次）和 sister-file 漏改占主要比重，需要从 SKILL.md 一次性检查升级为 plan→dev→qa 接力 enforce。 |
| 2026-05-22 | **qa-12-dimensions 加固（skill v1.0.1 → v1.1.0；随 v2.0.0 一并发布）**。43 天没动，已 drift 到上游（Anthropic feature-dev v2 code-reviewer）和 stackpilot 内部 sp-qa 之后。三处定向 backport：(1) Reporting Rules 改为 5 档置信度量表（0/25/50/75/100），跟上游 feature-dev v2 对齐；(2) Stage 1 改名 "Spec & Project Guidelines Compliance"，把读 `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` / `.cursorrules` 当首要 review 角度，违反指南是 first-class finding；(3) 新增 "Adversarial Angles Tried" 必填字段（源自 sp-qa）——只有当 angle 列表非空、内容扎实时 "no findings" 才可信，防止"静默通过"失败模式。Sub-agent 专属特性（输出 schema、Consistency Audit grep 三件套、WTF ratio、硬上限）刻意 **不** backport——受众不同。 |
| 2026-05-20 | **移除 `/stackpilot-bench` skill 与 `codex-config/` Codex 支持**。bench harness（3 个 workload、history.csv、scoring/verdict 脚本、run-codex-bench.sh、references/headless-mode.md）、`codex-config/agents/` 的 Codex 原生 sp-* prompts、`claude-config/skills/stackpilot/references/codex-dispatch.md`、`docs/bench-implementation.md` 全部删除；只为 `stackpilot-serial` bench leg 存在的 `qa.disable_criteria_gate` 与 `qa.disable_state_json` 两个 config flag 从 SKILL.md / run-sprint.md 一并移除。原因：bench v2 的 schema/runner/workload 三方不一致跑不起来；Codex 编排不再维护。 |
| 2026-05-18 | **v1.11.0**：Run Sprint 改为并行波次执行（qa.max_parallel 默认 3），通过 `depends_on` 拓扑排序计算波次；每个任务在 `.stackpilot/runs/<sprint>/TASK-NNN/state.json` 持久化（替代仅 in-memory 的 TaskCreate，Sprint Interrupted 恢复不再依赖 git log 启发式）；Phase 3.6 派生可机械验证的 `acceptance-criteria.md`，sp-qa 在审查时更新 Status，sprint-finish Step 0.5 三道门禁（criteria 全绿 / CHANGELOG 覆盖 sprint scope / Pattern Candidates 已浮现）拦截 merge；Light Feature 加 mandatory mini-brainstorm + Standard 加 Phase 3.7 User Reviews Spec Gate（superpowers:brainstorming 5.1.0 重新同步，docs/sync.md 已更新）；SKILL.md Run Sprint 段瘦身 ~100→28 行（详细协议下沉到 `references/run-sprint.md`）。 |
| 2026-04-17 | **v1.10.0**：Opus 4.7 管线适配：`stackpilot.config.yml` 新增 per-phase effort advisory（architect/dev/qa/docs）；4 个 agent 加 effort posture 一行；跨 sprint 记忆——`.stackpilot/sprint-metrics.md`（sprint-finish 追加）和 `.stackpilot/decisions.md`（sp-architect 在 HIGH 风险时追加）；Sprint Clean 读取最近 3 次 sprint 趋势并提示；auto-verify 循环从 3 轮降到 2 轮；SKILL.md 12-QA 表格抽到 `references/12-qa-matrix.md`。 |
| 2026-04-16 | **v1.9.1**：移除 sp-qa 的 codex-plugin-cc 跨模型审查集成。HIGH 风险任务改为可选调用 Claude Code `/ultrareview`（需 Opus 4.7+）。工具链单一来源，对齐 Claude Code 原生定位。 |
| 2026-04-16 | **v1.9.0**：借鉴 gstack 强化 sprint 管线：sp-qa WTF 自监控启发式（revert/fix 比率、硬上限 15 次修复），Phase 1 探索阶段反谄媚与强迫性追问，sprint-finish 新增 Step 0 合并前门禁（type check + lint + tests），systematic-debugging 3-strike 上报规则，sync-skills `--quick` 标志。 |
| 2026-04-13 | **v1.8.0**：Skill 自动同步（`sync-skills.sh --auto-update`），post-commit hook 自动检测新 skill，`/stackpilot` Step 0 版本自检，修复 `install.sh` 用 `cp -r` 保留 `references/` 子目录。 |
| 2026-04-13 | **v1.7.0**：新增 `/stackpilot-research` skill——横纵分析法深度研报（纵向发展史 + 横向竞品切面），3 波研究策略，叙事驱动输出，质量自检。仅显式调用触发。 |
| 2026-04-12 | **v1.6.1**：融入 Karpathy 编码准则优化 agent prompts（sp-dev、sp-architect、sp-qa、sp-docs）和 SKILL.md 规划门禁：正向可追溯性替代否定约束、假设外显、简洁度自检、计划反 scope creep。 |
| 2026-04-11 | **v1.6.0**：新增 `pre-merge-commit` git hook，强制 main/master 只允许 squash merge。由 `init.sh` 安装。可通过 `STACKPILOT_ALLOW_MERGE=1` 绕过。 |
| 2026-04-11 | **v1.5.3**：修复 12-QA 阶段被跳过的问题——将模糊的 `auto-proceed` 替换为显式阶段引用，防止 LLM 跳过 Phase 3.5/4.5。 |
| 2026-04-11 | **v1.5.2**：修复 `/release` skill，在 release commit 中包含架构文档以满足 pre-commit hook 检查。 |
| 2026-04-11 | **v1.5.1**：移除未使用的 `NEEDS_REVIEW.md` 机制。修复 zsh `no matches found` 报错——用 `find` 替代 glob 模式。 |
| 2026-04-11 | **v1.5.0**：在 spec（Phase 3.5）和 plan（Phase 4.5）后新增 12-QA 审查门禁——12 维度场景覆盖审查，维度 1-4 为硬性门禁。 |
| 2026-04-10 | **v2.1 整合**：将 stackpilot-auto、stackpilot-resume、stackpilot-tidy 合并到主 `/stackpilot` 作为状态路由流程（编排命令 6→3）。移除归档机制——plans/specs 直接删除（git history 可追溯）。新增工作区 tidy 流程（清理 .claude/plans/、.superpowers/、孤立 worktree、已合并分支）。用户描述需求后新增自动/交互模式选择。 |
| 2026-04-08 | **v2 架构**：dispatch.sh 替换为 Claude Code 原生 Agent tool；backlog.yml 替换为 TaskCreate；移除 sp-pm 和 sp-coordinator（内联到 skill）；移除 git hooks；配置精简为仅 qa 部分；新增 /stackpilot-resume；Agent 变为纯方法论提示词，无文件 I/O |
| 2026-04-07 | 收敛交互流程；Visual Companion 内联；自动探测项目栈；TDD + 根因调查；即时 review；per-provider model routing；worktree 隔离；pre-commit 校验；文件锁；超时；自动 coding + 进度简报 |
| 2026-04-07 | 逐个澄清问题；Visual Companion 浏览器服务器；compete 12 维度 + 5 角色辩论 |
| 2026-04-04 | 集成 autoresearch 模式；12 维测试；多角色对抗分析；Optimize Sprint；docs/sync.md |
| 2026-04-04 | sp-* 前缀；.stackpilot/ 运行时状态；内联所有外部 skill 协议 |
| 2026-04-01 | 复杂度路由、verify/fix 循环、soft-blocked 重试 |
| 2026-03-29 | 初始实现 |
