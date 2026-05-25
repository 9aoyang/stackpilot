# Plan — Stackpilot Skill Tighten

> Spec: `.stackpilot/specs/2026-05-25-stackpilot-skill-tighten-design.md`
> Criteria: `.stackpilot/specs/2026-05-25-stackpilot-skill-tighten-criteria.md`
> Branch: `feat/skill-tighten-2026-05-25`

5 个 task，markdown 文件改动，无 TDD（Pure config exempt）。

## Wave 1（并行 4 个，max_parallel=3 → 实际跑 3+1）

### TASK-001 — SKILL.md 4 处 sub-step

- type: skill-edit
- complexity: light
- depends_on: []
- relevant_files: `claude-config/skills/stackpilot/SKILL.md`
- sister_files: []
- shared_field_grep: []
- description: 在 Node 1 Exploration 的 `Exploration rigor rules` 末尾加 Scope Lock 子步骤；Node 3 § 3.1 加默认最小有效版本引导句；Node 4 § 4.1 task schema 加 sister_files / shared_field_grep 字段说明，§ 4.2 加 grep verify 检查行；Node 5 § 1 pre-merge gate 加一次性脚本残留扫描 + typecheck/lint/test 三件套兜底。具体文案见 spec 改动 1-4。改动总长 ≤ 50 行。
- verify: criteria C1 + C2 + C3 + C4 + C10 全 PASS

### TASK-002 — sp-architect.md Will NOT touch

- type: agent-edit
- complexity: light
- depends_on: []
- relevant_files: `claude-config/agents/sp-architect.md`
- sister_files: []
- shared_field_grep: []
- description: `## Implementation Blueprint` 段中 `Modified files` 之后加 `Will NOT touch` 行；理由段加一句"任务触及 shared identifier 或 shared field 时，Will NOT touch 必须包含 sp-architect 在 grep 时见到但确认无关的命中点"。文案见 spec 改动 5。
- verify: criteria C5 PASS

### TASK-003 — sp-dev.md sister-file ack

- type: agent-edit
- complexity: light
- depends_on: []
- relevant_files: `claude-config/agents/sp-dev.md`
- sister_files: []
- shared_field_grep: []
- description: `## Required behaviors` 加 Sister-file ack 一条（启动前跑 shared_field_grep，确认 sister_files 在范围或 Will NOT touch；两字段独立或同时存在）；`## Completion Output` schema 加 `## Sister-File Sync` 段。文案见 spec 改动 6。
- verify: criteria C6 PASS

### TASK-004 — sp-qa.md Stage 4 sister-file sync audit

- type: agent-edit
- complexity: light
- depends_on: []
- relevant_files: `claude-config/agents/sp-qa.md`
- sister_files: []
- shared_field_grep: []
- description: `### Consistency Audit` 段加第 4 条 audit "Sister-file sync audit"：grep plan task 的 shared_field_grep 命中点，对照 sp-dev 的 Sister-File Sync 报告，命中不在修改范围且不在 sp-architect Will NOT touch 列表 → [CRITICAL]。`## Adversarial Angles Tried` 默认列表加 sister-file sync 一项。文案见 spec 改动 7。
- verify: criteria C7 PASS

## Wave 2（依赖前 4 个）

### TASK-005 — ARCHITECTURE.md + CHANGELOG 收尾

- type: docs-update
- complexity: light
- depends_on: [TASK-001, TASK-002, TASK-003, TASK-004]
- relevant_files: `.stackpilot/ARCHITECTURE.md`, `CHANGELOG.md`
- sister_files: []
- shared_field_grep: []
- description: ARCHITECTURE.md `## Key Design Decisions` 加 1 条 "Skill Tighten — sister-file sync via sub-agent contract (2026-05-25)"，含 why（insights 5 大跨项目 friction 数据）+ how to apply（Node 4 plan task 触动 shared identifier 时填 sister_files / shared_field_grep；sp-architect 输出 Will NOT touch；sp-dev ack；sp-qa Stage 4 audit 拦截）+ Related files 列出本次改动。CHANGELOG.md 写入 `## [Unreleased]` 或新 v2.0.x 条目。
- verify: criteria C8 + C9 PASS

## Plan-level checks

- 全局 will-NOT-touch 验证：no task 列出 12-qa-matrix.md / run-sprint.md / sp-docs.md / references/views/* — 满足 C11
- 无新源文件：no task 创建 .ts/.js/.sh/.md（除 ARCHITECTURE/CHANGELOG 是已存在追加） — 满足 C12
