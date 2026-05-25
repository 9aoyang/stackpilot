# Spec — Stackpilot Skill Tighten

## 目标

把 insights 报告（2026-05-25 / 283 sessions / 325 commits）揭示的跨项目 5 大稳定 friction 嵌进 stackpilot 的 5-node pipeline。范围采用 Option B：SKILL.md 4 处 sub-step 内嵌补丁 + sp-architect / sp-dev / sp-qa 三个 sub-agent 边界声明。

5 大 friction 与覆盖位置：

| Friction | 频次 | 覆盖位置 |
|---|---|---|
| 改错组件（wrong_approach） | 34 | Node 1 Scope Lock + sp-architect file-scope output |
| sister-file 漏改 | 多次（OnboardingView 第二个表单、KP↔article） | Node 4 plan `shared_field_grep` + sp-dev ack + sp-qa Stage 4 sync audit |
| spec/handbook 过度工程 | 2 项目至少各 2 轮砍 | Node 3 默认最小 |
| 一次性 migrate 脚本残留 | 全局 + skill_quest 都点名 | Node 5 pre-merge 扫描 |
| 完成前没 verify | stale type cache、datalist 不本地化 | Node 5 显式三件套（typecheck + lint + test） |

## 范围（Will-touch）

| 文件 | 改动 |
|---|---|
| `claude-config/skills/stackpilot/SKILL.md` | Node 1/3/4/5 各加 1 sub-step；sub-step 总长 ≤ 50 行 |
| `claude-config/agents/sp-architect.md` | Implementation Blueprint 段加 `Will NOT touch` 行 |
| `claude-config/agents/sp-dev.md` | Required behaviors 加 sister-file ack 一条；Completion Output 加 `## Sister-File Sync` 段 |
| `claude-config/agents/sp-qa.md` | Consistency Audit 加 audit #4 sister-file sync grep |
| `CHANGELOG.md` | 写入 v2.0.x 条目 |
| `.stackpilot/ARCHITECTURE.md` | Key Design Decisions 加 1 条记录本次决策（含 why / how to apply） |

## 不动的（Will-NOT-touch）

| 文件 / 概念 | 理由 |
|---|---|
| 5-node 命名 | 已在 v2.0.0 决定不再拆碎为 Phase X.Y |
| Light task mini-mode 协议 | 已经强制 30s 设计检查 |
| Dual-track（data layer / view layer） | v2.0.0 已立 |
| Explicit-invocation 原则 | 不按复杂度自动 route |
| `sp-qa never writes ARCHITECTURE.md` 原则 | Option C 已驳回 |
| `sp-docs.md` | 与 sister-file sync 无关 |
| `references/run-sprint.md` 协议正文 | sub-agent 接力即可表达，不需改协议 |
| `references/12-qa-matrix.md` | 12 维度本身不变；sister-file 检查走 sp-qa Stage 4 |
| HTML 视图 templates | 数据层改动，view 层无需变 |

## 改动 1：Node 1 Scope Lock 子步骤

位置：`SKILL.md` Node 1 — Exploration `Exploration rigor rules` 节末尾，在"Two-push rule"之后加新规则。

文案（中文，对齐现有节风格）：

> - **Scope Lock（多文件改动前必须做）**：当请求触及共享 identifier / shared field / 同一概念的多个组件时，先全仓 grep，列出 will-touch / will-NOT-touch 文件清单（按推断 sister-file 关系），等用户确认后再进入 Node 2 / Node 4。歧义组件名（"ConfigPanel" 这种可能多处存在）必须先问再改。

## 改动 2：Node 3 默认最小

位置：`SKILL.md` Node 3 — Spec & Criteria § 3.1 Write spec 加引导句。

文案：

> - **默认最小有效版本**：spec 先出最小可执行版本（目标 / 范围 / 验收 / Canonical Refs）。Comparison framework / decision matrix / "send to X" framing / 多 audience 切片这类扩展只在用户明确要求时加。≥300 字下限不是要求"凑长度"，是要求"覆盖必要语义"。

## 改动 3：Node 4 plan task `shared_field_grep`

位置：`SKILL.md` Node 4 § 4.1 Write plan 的 task schema 描述。

变更：在 task 必填字段（`title`/`description`/`type`/`complexity`/`depends_on`/`relevant_files`）后加：

> - `sister_files`（可选）：当 task 触及 shared identifier / shared component / shared field 时，列出必须同步改动的姊妹文件路径（如 `[OnboardingView-A.tsx, OnboardingView-B.tsx]`）。
> - `shared_field_grep`（可选）：当 task 是 rename / shared field 改动时，列出 grep 模式（如 `["yumi_id", "ageRange"]`），sp-dev 启动前会跑这些 grep 验证范围。

§ 4.2 plan auto-verify 加一行：

```bash
# 任何 rename/shared field 任务必须有 shared_field_grep
grep -B2 -A6 "type:.*\(rename\|shared_field\|migrate\)" .stackpilot/plans/*.md | grep -c "shared_field_grep:" 2>/dev/null
```

(自动 verify 失败时由 main agent 自修一次，仍失败则 escalate。)

## 改动 4：Node 5 pre-merge 残留扫描

位置：`SKILL.md` Node 5 — Finish § 1 Pre-merge gate 末尾。

文案：

> 扫描一次性脚本残留：
>
> ```bash
> BASE=$(git merge-base main HEAD 2>/dev/null || echo HEAD~10)
> git diff --name-only "$BASE"..HEAD | grep -E '^scripts/(migrate|audit|debug|oneshot)-.+\.(ts|js|sh|py)$' || echo "no one-shot scripts"
> ```
>
> 命中即报告给用户："以下一次性脚本是否应在合并前删除？" — 默认建议删（按全局 CLAUDE.md `## 多文件同步律` 的"一次性脚本即用即删"）。auto mode 下保留并记录到 finish-report。

同时把 pre-merge gate 现有"type check, lint, qa.test_command"明确化成可枚举三件套（已经在描述里，加项目检测兜底）：

> 项目无显式 `qa.test_command` 时，按存在性兜底跑：`tsc --noEmit` / `npm run lint` / `npm test` 中所有可解析的脚本；都不存在记录 `N/A`。

## 改动 5：sp-architect file-scope output

位置：`claude-config/agents/sp-architect.md` `## Output Format` 中 `## Implementation Blueprint` 段。

变更：在 `Modified files` 之后加：

> - **Will NOT touch:** `path/to/keep-out.ts` — reason (out of task scope, sibling concern, etc.)

理由段加一句：

> 当任务触及 shared identifier 或 shared field 时，`Will NOT touch` 必须包含 sp-architect 在 grep 时见到但确认无关的命中点（让 sp-dev 知道哪些 grep 命中是 false-positive，避免误改）。

## 改动 6：sp-dev sister-file ack

位置：`claude-config/agents/sp-dev.md`。

变更 1：`## Required behaviors` 加：

> - **Sister-file ack (启动前)**：plan task 含 `shared_field_grep` 时，先跑这些 grep，把命中文件列在 Completion Output `## Sister-File Sync` 段；plan 含 `sister_files` 时，确认这些文件都在本任务的修改范围内或在 sp-architect 的 `Will NOT touch` 列表里 — 否则 escalate。两个字段独立处理（grep 验证范围 / sister_files 验证完整性）；同时存在时两步都跑。

变更 2：`## Completion Output` schema 加段：

```
## Sister-File Sync
- Plan declared sister_files: <list or "none">
- Plan declared shared_field_grep: <list or "none">
- Grep command: <exact command>
- Hits found: <list of file:line, or "none">
- All hits modified: Yes / No (if No, reference to sp-architect's Will NOT touch)
```

## 改动 7：sp-qa Stage 4 sister-file sync audit

位置：`claude-config/agents/sp-qa.md` `### Consistency Audit` 段。

变更：加 audit #4 在现有 3 个 audit 之后：

```bash
# 4. Sister-file sync audit — every shared_field_grep pattern's hit must be modified
# Inputs: plan's shared_field_grep list, dev's Sister-File Sync report
# For each pattern: grep -rn '<pattern>' --include='*.ts' --include='*.md' --include='*.sh'
# Hits not in dev's modified files AND not in sp-architect's Will NOT touch → [CRITICAL].
```

`## Adversarial Angles Tried` 默认列表加 `sister-file sync` 一项。

## 验收方式

见 `2026-05-25-stackpilot-skill-tighten-criteria.md`。所有 criteria 必须 grep / file-existence / sub-string 检查可机械验证，无主观判断。

## Canonical Refs

- `/Users/gaoyang/.claude/usage-data/report-2026-05-25-111633.html` — insights 报告原文（5 大 friction 出处）
- `/Users/gaoyang/.claude/CLAUDE.md`（→ `dotfiles/claude/CLAUDE.md`）— 全局工作纪律新加的 `## 多文件同步律` + `## 改动纪律`
- `/Users/gaoyang/Documents/github/skill_quest/CLAUDE.md` — migrate 脚本约定原型
- `.stackpilot/ARCHITECTURE.md` — Key Design Decisions（"Don't re-teach Claude"、"sp-qa never writes ARCH.md"、"explicit-invocation only" 三条原则必须遵守）
- `claude-config/skills/stackpilot/SKILL.md` — 5-node 现状
- `claude-config/agents/sp-{architect,dev,qa}.md` — agent 契约现状
