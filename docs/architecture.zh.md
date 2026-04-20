# Stackpilot 架构文档

> 最后更新：2026-04-20

Stackpilot 是一个面向 Claude Code 和 Codex 的方法论驱动 Sprint 编排层。它将设计文档转化为可运行代码，通过驱动宿主 agent 原生的计划和委派能力完成，无需自建服务基础设施。

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
│       ├── stackpilot-compete/
│       │   └── SKILL.md           ← /stackpilot-compete 竞品差距分析
│       ├── stackpilot-research/
│       │   └── SKILL.md           ← /stackpilot-research 深度研究（横纵分析法）
│       ├── stackpilot-sync/
│       │   └── SKILL.md           ← /stackpilot-sync 外部 skill 同步
│       └── systematic-debugging/
│           └── SKILL.md           ← /systematic-debugging（便携式）
├── codex-config/
│   └── agents/                    ← Codex 原生 sp-* prompts
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
│       ├── start-server.sh        ← 可视化设计伴侣服务器
│       └── stop-server.sh
└── templates/
    ├── stackpilot.config.yml      ← 配置模板（仅 qa 部分）
    └── stackpilot-inner-gitignore

<项目根目录>/                      ← 用户的项目
├── stackpilot.config.yml          ← qa 配置（test_command, coverage_threshold）
└── .stackpilot/                   ← specs 和 plans 受 git 跟踪
    ├── specs/                     ← 设计文档（当前 sprint）
    └── plans/                     ← 实现计划（当前 sprint）
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
| **sp-architect** | 对照代码库审查任务；返回架构决策 | 每次 review 都用 extended thinking（不限 HIGH）；定风险前先列 ≥2 个具体失败模式；Risk 评级必须配一行说理（blast radius / rollback cost）；读取 `.stackpilot/ARCHITECTURE.md § Key Design Decisions`；唯一架构决策 + 完整蓝图；HIGH 跑 3 personas，LOW/MEDIUM 至少 1 个；输出 `## Decision Candidates`；新依赖/结构冲突返回 `[ESCALATION]` |
| **sp-dev** | 实现任务 | 读 `git log` 避免重复失败路径；追踪入口点+调用链；强制 TDD（RED-GREEN-REFACTOR）；4 阶段根因调查；verify/fix 循环含卡住检测；失败后回滚；3 轮后返回 `[SOFT-BLOCKED]` |
| **sp-qa** | 审查代码、编写测试 | Stage 1-3 语义审查（spec 合规 + 代码质量 + 对抗性）；Stage 4 确定性 grep 审计（absolute-claim / scope-completeness / dead-reference，HIGH 风险强制）；读取 `.stackpilot/ARCHITECTURE.md` 获取 Review Patterns 和 Conventions；输出 `## Pattern Candidates`（从不直接写）；Layer 2 全新上下文 Deep Review（HIGH 风险默认开）；置信度 ≥ 80。**只在 standard 复杂度下 dispatch** — 轻量任务靠 sp-dev 的 TDD 兜。 |
| **sp-docs** | 更新 README、注释、API 文档 | **使用 haiku 4.5**（机械任务）；QA 通过后运行；只改文档不改逻辑。 |

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

### Codex

Codex 版 `/stackpilot` 使用 skillshare 同步的同一个共享 skill。它通过
`references/codex-dispatch.md` 做可见任务跟踪，并通过 Codex subagents
调度同一套方法论：

| Stackpilot role | Codex dispatch |
|---|---|
| `sp-architect` | 如有命名 role 就用命名 role，否则用 `explorer` + `codex-config/agents/sp-architect.md` |
| `sp-dev` | 如有命名 role 就用命名 role，否则用 `worker` + 明确文件 ownership |
| `sp-qa` | 如有命名 role 就用命名 role，否则用 `worker` + QA-only ownership |
| `sp-docs` | 如有命名 role 就用命名 role，否则用 `worker` + docs-only ownership |

这样 skillshare 是共享 skills 的唯一同步源，同时不把 Codex 伪装成
Claude Code 的 `subagent_type` 注册表。

Codex 运行必须留下可审计的阶段证据：`architect.md`、`dev-report.md`
和 `qa-report.md`，并且 QA 必须检查最终 diff。这样 `/stackpilot` 在
Codex 中不会退化成“风格提示”；如果调用方无法验证这些证据，则该次运行
标记为 `orchestration_invalid`。

`/stackpilot-bench` 的合同测试是闭卷的：测试文件不再放进
`sandbox/`，而是放在 workload 的 `evaluator/` 目录。runner 在模型执行
完成并捕获实现 diff 之后，才把它复制为
`bench-sandbox/.stackpilot-hidden-evaluator/` 并运行 verification command。
这样 zero 和 stackpilot 都不能提前读取或修改答案。闭卷不等于答案钥匙：
隐藏测试应优先通过公开 API 和可观察状态评分；必要的静态断言也必须是语义级、
路径无关的，除非 prompt 明确声明了某个公开契约名称。

---

## 事件流

### 用户主动触发（通过 `/stackpilot` skill）

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

**Standard Feature — 人工介入点：**

```
Phase 1: 逐个澄清问题（深度理解后再问下一个）
Phase 1.5: 可视化伴侣（浏览器端 mockup，仅在视觉表达更优时使用）
Phase 2: 设计方案（分段展示，用户逐段确认）
Phase 3: spec 自动验证循环（自修复，仅 3 次失败才升级）
Phase 3.5: spec 12-QA（12 维度场景覆盖审查）
Phase 4: plan 自动验证循环（自修复，仅 3 次失败才升级）
Phase 4.5: plan 追溯检查（spec→task 正向追溯 + task→spec 反向追溯；不再重跑 12 维度）
Pre-coding: 确认开始
Coding: 自动执行 + 每 task 进度简报
Sprint finish: squash merge（main 上仅一个 commit）/ PR / 保留 / 丢弃
  ↳ pre-merge-commit hook 硬性拒绝非 squash 的 merge
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
| `/stackpilot` | 主入口：tidy + resume + 状态 + 自动/交互模式 + Sprint 执行。Claude 和 Codex 共享同一个 skill；Codex 调度见 `references/codex-dispatch.md`。 |
| `/stackpilot-compete` | 以竞品重度用户视角做差距分析 |
| `/stackpilot-research` | 横纵分析法深度研报（纵向发展史 + 横向竞品切面） |
| `/stackpilot-sync` | 外部 skill 追踪和同步（开发者维护） |
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
| `stackpilot` | 完整 sprint：tidy→resume→设计→spec→plan→编码→QA→上线。内置自动模式（跳过确认）和工作区清理。 |

**渐进式展开** — SKILL.md 控制在 500 行以内，重内容（visual companion、optimize sprint、sprint finish）放在 `references/` 按需加载。

---

## 关键设计决策

**Claude Code 原生编排（v2）。** Agent 通过 Claude Code 的 Agent tool 调度，带 `isolation: "worktree"`。无自建 bash dispatcher、无手动 worktree 管理、无文件锁。Claude Code 处理所有基础设施。

**Prompt 级 Agent 间通信。** Agent 输出直接作为 prompt 上下文传递给下游 Agent。无中间文件（arch-review/、done/）。主会话即 coordinator。

**Plan 即持久层。** 任务在会话内通过 TaskCreate 跟踪。Plan 文件是持久化的 source of truth。resume 流程从 plan + git log 重建状态。

**零外部依赖。** 所有 Agent 协议内联，无需安装任何外部插件。

**任务粒度的复杂度路由。** `complexity: light | standard`，轻量跳过 architect，省约 60% Agent 开销。

**Soft-blocked 重试。** Agent 返回 `[SOFT-BLOCKED]`，主会话重试最多 3 次才需人工。

**Git 即记忆。** sp-dev 每次任务前读 `git log --oneline -20`，不重复已失败的方案。

**显式 subagent_type 调度。** SKILL.md 的 `Agent()` 调用显式传 `subagent_type="sp-architect"` / `"sp-dev"` / `"sp-qa"` / `"sp-docs"`，让 Claude Code 路由到注册好的 agent（含 frontmatter 里的 model 和 tool 限制），不退化到 `general-purpose`。要求：agent 必须在 `~/.claude/agents/` 或已安装的 plugin 里。Claude Code 启动时缓存注册表——装完必须重启。sp-docs 按 task.type 路由：`type: docs` → sp-docs（haiku），其他 → sp-dev（sonnet）。

**不和 Claude 抢活。** Agent 方法论文件只规定 stackpilot 的编排契约——输入格式、完成报告格式、升级信号、跨 sprint 记忆挂钩。**不**写"怎么做 TDD / 怎么做 code review / 怎么调试"这些通用工程方法论，因为 Claude 4.7 本来就会。2026-04-17 的重构按这条原则砍了 sp-dev 和 sp-qa 方法论 ~47%。

**Sprint Finish 自验证。** Step 2 启动 dev server 后，主 agent 在交给用户前自动 curl 一次 preview URL 并报 HTTP 状态。非 2xx/3xx 或连接失败会打出 server log 尾 20 行——抓住"进程起来了但应用 500"这类回归，零 per-task 开销。

**单文件项目记忆。** `.stackpilot/ARCHITECTURE.md` 是项目级记忆的唯一落点，固定章节：What This Project Is / Stack / Key Directories / Data Flow / Key Design Decisions / Conventions & Gotchas / Review Patterns。只有主 agent 在 Sprint Finish Step 4a 写它；子 agent 全部只读——`sp-architect` 读 `§ Key Design Decisions` 作为历史决策参考，HIGH 风险时通过完成报告里的 `## Decision Candidates` 块上交新决策；`sp-qa` 读 `§ Review Patterns` 与 `§ Conventions & Gotchas`，发现新模式时通过 `## Pattern Candidates` 块上交。主 agent 在 Sprint Finish 决定是否合入。写操作串行在 feature branch 上，规避 worktree 并发写冲突。

**强制 TDD。** RED-GREEN-REFACTOR，先写测试再写实现。

**根因调查优先。** 4 阶段调查（观察→复现→追溯→假设）后才修复。

---

## 演进记录

| 日期 | 变更 |
|------|------|
| 2026-04-20 | **行为导向的闭卷 evaluator**：regional ledger 隐藏测试改为验证公开 API 行为和通用 ledger/reconciliation 语义，不再要求固定私有文件名或 helper 函数名。workload fixture 同时改用显式 `.ts` imports，避免 benchmark 测到 Node ESM 解析清理，而不是 billing migration 能力。 |
| 2026-04-20 | **闭卷 benchmark evaluator**：将 regional ledger 合同测试从可见 sandbox 移到 `workloads/<id>/evaluator/`。Codex bench runner 只在模型执行结束后注入 `.stackpilot-hidden-evaluator/` 并执行 verification command，避免 zero-shot 和 stackpilot 腿提前读取或修改答案。 |
| 2026-04-20 | **Codex Stackpilot 执行契约**：Codex `/stackpilot` 对 standard 及以上任务要求产出可审计的 `architect.md`、`dev-report.md`、`qa-report.md` 阶段产物。`/stackpilot-bench` 会验证 stackpilot 腿的这些产物，将 `.stackpilot-bench/**` 排除出实现 diff 评分，执行 workload verification command，缺少阶段证据时标记 `orchestration_invalid` 并给质量分 0。 |
| 2026-04-20 | **单一究极 workload + 双腿 bench**：移除当前 3 个 native-enough workload，改为单个 `01-regional-billing-ledger-cutover` 高区分度场景，只比较 `zero` 与 `stackpilot`，不再跑 `savvy`。历史 bench 数据重置，避免旧 workload 污染后续判断。 |
| 2026-04-20 | **Codex bench runner**：新增 `run-codex-bench.sh` 与 `run-leg-codex.sh`，让 `/stackpilot-bench` 可以通过 `codex exec --json --ephemeral` 测 Codex 侧的 native zero / stackpilot 两条腿。输出沿用同一份 `history.csv` 与人可读 `scorecard.md`；runner 解析 Codex usage 字段，并在 diff 前执行 `git add -N`，确保新建未跟踪文件也进入评分。 |
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
