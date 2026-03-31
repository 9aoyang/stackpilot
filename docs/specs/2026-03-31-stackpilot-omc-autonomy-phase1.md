# Stackpilot OMC Autonomy Phase 1 Design

## Goal

在不推翻 Stackpilot 现有控制平面的前提下，引入 OMC 作为任务执行引擎，显著减少人工介入频次。目标状态是：默认持续推进，只有命中少数高风险红线时才写入 `tasks/NEEDS_REVIEW.md` 并等待人工决策。

## Problem

当前 Stackpilot 的问题不是缺少状态管理，而是自主推进能力不足。

现状：
- `tasks/backlog.yml`、`tasks/in-progress.yml`、`tasks/NEEDS_REVIEW.md` 定义了清晰状态机
- PM Agent 和 Coordinator 已能完成任务拆解与调度
- Dev Agent、QA Agent、Architect Agent 的默认策略偏保守，遇到歧义、失败、局部冲突时容易升级给人

后果：
- 实现中的小歧义会打断 sprint
- 测试失败或覆盖率不足容易演变成等待人工处理
- QA 与 Dev 之间的闭环较弱，任务常停在“发现问题但未自愈”

## User Intent

用户希望系统具备激进自治能力：
- 默认持续推进，不因低风险问题频繁中断
- 允许在仓库边界内自主修改代码、测试、文档、脚本，并自动提交收尾
- 不允许默认触碰 CI、部署配置、外部服务配置、重大依赖升级等高风险边界

## Options Considered

### Option A: Keep Stackpilot As-Is, Only Relax Escalation Rules

做法：
- 不引入 OMC
- 仅调整各 agent 的 prompt，减少升级条件

优点：
- 改动最小
- 与现有状态机完全兼容

缺点：
- 只能减少“停下来问”的频率，不能显著提升单任务执行力
- 缺少 OMC 的并行、验证、修复、自主换路能力

### Option B: Replace Stackpilot Coordinator With OMC

做法：
- 用 OMC 的 `team` / `autopilot` 接管任务拆解、调度、验证和修复

优点：
- 自主感最强
- 编排能力集中在一个系统内

缺点：
- 与 `tasks/backlog.yml` / `NEEDS_REVIEW.md` / `in-progress.yml` 冲突
- 失去 Stackpilot 当前最有价值的显式状态治理
- 双系统迁移成本高，失败时难以审计

### Option C: Keep Stackpilot Control Plane, Add OMC As Execution Layer

做法：
- 保留 PM Agent、Coordinator、backlog 协议、review 协议
- 让 OMC 接管单任务实现、自主重试、verify/fix loop
- 只在命中红线时升级给人工

优点：
- 同时保留可控性和自主推进能力
- 改造面集中在 `dev-agent`、`qa-agent`、`architect-agent`、`coordinator-agent`
- 可以先从单任务执行层验证收益，再决定是否扩大范围

缺点：
- 需要明确 OMC 的任务边界和回写协议
- 需要新增 attempt / soft-blocked / hard-blocked 等治理语义

## Decision

选择 Option C。

最终架构：
- Stackpilot 继续作为 control plane，负责任务拆解、状态落盘、依赖调度、失败治理
- OMC 作为 execution layer，负责单任务的自主实现、自主重试、验证与修复
- 人工只作为 escalation gate，处理真正需要拍板的问题

## Non-Goals

本阶段不做以下事情：
- 不替换 PM Agent
- 不替换 Coordinator 的顶层控制权
- 不引入对 CI/CD、部署平台、外部服务配置的自动修改
- 不尝试一次性改造所有 agent
- 不在本阶段引入新的 backlog 文件格式

## Phase 1 Scope

本阶段只改造以下 3 个核心点：

1. `dev-agent`
2. `qa-agent`
3. `coordinator-agent`

`architect-agent` 仅在 Phase 1 中调整策略，不作为首轮实现重点。

## Detailed Design

### 1. Control Plane vs Execution Layer

职责边界必须明确：

Stackpilot control plane 负责：
- 读取和维护 `tasks/backlog.yml`
- 维护 `tasks/in-progress.yml`
- 管理任务依赖、并发上限、超时和最终收尾
- 维护 `tasks/NEEDS_REVIEW.md` 作为唯一人工升级入口

OMC execution layer 负责：
- 实现单个 `dev` 任务
- 对单个 `qa` 任务执行测试、局部修复和回归
- 在单任务内部进行多轮尝试、换方案和验证

任何 OMC 子流程都不得成为新的任务系统。它必须消费 Stackpilot 任务，并把结果回写到 Stackpilot 的显式状态文件中。

### 2. Autonomy Policy

默认策略从“保守升级”改为“激进自治”。

允许 agent 默认直接做的事：
- 修改仓库内代码、测试、文档、脚本
- 运行本地验证命令
- 在当前任务边界内做 2 到 3 轮自主重试
- 在同一任务内做 verify/fix loop
- 自动提交任务完成后的仓库内收尾工作

默认禁止的事：
- 修改 CI/CD 配置
- 修改部署配置
- 修改外部服务配置
- 引入新依赖或大版本升级依赖
- 超出任务边界的跨模块重构

### 3. Escalation Model

新增两种阻塞语义：

- `soft-blocked`
  - 当前尝试失败，但存在明确替代路径
  - 不写入 `tasks/NEEDS_REVIEW.md`
  - 由 Coordinator 或当前 agent 自动重试

- `hard-blocked`
  - 命中高风险边界，或多轮尝试后仍无法收敛
  - 必须写入 `tasks/NEEDS_REVIEW.md`
  - 停止进一步自动推进，等待人工决策

### 4. Hard Escalation Red Lines

只有以下场景允许升级给人工：
- 需要引入新依赖
- 存在两个及以上影响明显不同、且都合理的需求解释
- 需要超出任务范围的大规模跨模块重构
- 连续 3 轮自治失败仍无法收敛
- 需要改动仓库外系统边界

除以上情况外，默认继续推进。

### 5. Dev Agent Redesign

`dev-agent` 从“遇到模糊点就停”的实现器，升级为“结果导向的自治执行器”。

新行为：
- 先读 `CLAUDE.md`、任务定义、可选的 arch review
- 在任务边界内自行收敛模糊点，优先采用仓库内已有模式
- 默认由 OMC 执行单任务实现
- 在单任务内允许多轮实现、验证、换方案
- 只有命中 hard escalation 红线才写 `tasks/NEEDS_REVIEW.md`

新回写要求：
- 成功时更新 `tasks/backlog.yml`
- 写 `tasks/done/TASK-ID.md`
- 在完成报告中写清楚实际采用的方案、验证命令、是否发生重试

失败策略：
- 第 1 次失败，记录尝试摘要，自动重试
- 第 2 次失败，明确切换实现路径后再试
- 第 3 次失败，标记 `hard-blocked`，写入 `tasks/NEEDS_REVIEW.md`

### 6. QA Agent Redesign

`qa-agent` 从“只能写测试，发现生产问题就上报”的守门员，升级为“任务内验证与自愈执行器”。

新行为：
- 继续以测试为主
- 允许在当前任务边界内做局部生产代码修复
- 允许执行 verify/fix loop，直到通过或命中红线

局部修复的边界：
- 只允许修复本任务直接影响的行为
- 不允许借 QA 名义做新的功能扩展
- 不允许引入新依赖
- 不允许跨任务边界做结构性重构

完成标准：
- 测试通过
- 覆盖率达到阈值，或已明确记录为什么无法达到
- 如发生局部修复，完成报告必须列出修复原因和验证结果

### 7. Coordinator Redesign

`coordinator-agent` 仍然掌握调度权，但不再把“失败”直接等价为“需要人”。

新增职责：
- 跟踪每个任务的 `attempt_count`
- 区分 `soft-blocked` 与 `hard-blocked`
- 自动重试可恢复失败
- 仅在 `hard-blocked` 时触发桌面通知和人工升级

建议状态语义：
- `pending`
- `in-progress`
- `soft-blocked`
- `hard-blocked`
- `done`
- `failed`

建议行为调整：
- `soft-blocked` 任务自动回到 `pending`
- 若 `attempt_count < 3`，继续调度下一轮
- 若 `attempt_count >= 3`，转为 `hard-blocked`
- `NEEDS_REVIEW.md` 只承载 `hard-blocked` 问题

### 8. Data Model Changes

`tasks/backlog.yml` 的单任务结构增加以下字段：
- `attempt_count`
- `last_error_summary`
- `autonomy_mode`, 固定为 `aggressive` 或未来可扩展
- `block_reason`, 仅在 blocked 时存在

`tasks/done/TASK-ID.md` 增加以下信息：
- 最终采用方案
- 重试次数
- 是否发生 QA 局部修复

`tasks/NEEDS_REVIEW.md` 改为只记录：
- `hard-blocked` 问题
- 推荐选项
- agent 已尝试过的路径摘要

### 9. Architect Agent Policy Adjustment

Phase 1 不强制重写 `architect-agent`，但要调整其评审风格：
- 从“发现模糊就拦截”改为“尽量收敛并给执行建议”
- 优先输出可执行方案，而不是问题列表
- 只有命中 hard escalation 红线时才要求人工拍板

## Success Criteria

Phase 1 达标标准：
- 同等复杂度任务下，人工介入次数明显下降
- 普通实现歧义不再直接写入 `tasks/NEEDS_REVIEW.md`
- QA 能在任务边界内完成至少一轮自动修复和回归
- Coordinator 能自动处理前两轮失败，不要求人工介入
- 所有自动推进过程仍可通过 backlog / done / NEEDS_REVIEW 文件审计

## Risks

### Risk 1: OMC 自治过强，偏离任务边界

缓解：
- 在 agent prompt 中显式定义“允许修改范围”
- Coordinator 校验输出是否仍在任务边界内

### Risk 2: QA Agent 借“局部修复”扩大职责

缓解：
- 明确只允许修复当前任务直接影响的行为
- 完成报告必须记录 QA 修复动作

### Risk 3: 状态模型变复杂，反而难维护

缓解：
- Phase 1 只新增最少字段
- 不在本阶段改动 PM Agent 和 spec 入口

## Rollout Plan

Phase 1 的推荐顺序：

1. 先改 `dev-agent.md`
2. 再改 `qa-agent.md`
3. 再改 `coordinator-agent.md`
4. 最后补 `README.md` 和模板文档

## Open Questions Resolved

以下问题在本设计中已定案，不再阻塞实现：
- 自治等级：激进自治
- 放权边界：仓库内代码、测试、文档、脚本可自动修改
- 顶层控制权：保留在 Stackpilot，不交给 OMC
- 第一阶段重点：`dev-agent`、`qa-agent`、`coordinator-agent`

