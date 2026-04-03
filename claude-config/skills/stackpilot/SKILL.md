---
name: stackpilot
description: Use when starting, resuming, or checking on autonomous development work. Acts as a project standup — always shows current status first, then guides next action.
---

# Stackpilot

## Step 1: 展示当前状态（每次必做）

```bash
[ -d tasks ] && echo "initialized" || echo "NOT_INITIALIZED"
cat tasks/backlog.yml 2>/dev/null || echo "NO_BACKLOG"
cat tasks/NEEDS_REVIEW.md 2>/dev/null
cat tasks/in-progress.yml 2>/dev/null
ls docs/specs/*.md 2>/dev/null || echo "NO_SPECS"
```

按以下格式展示状态面板：

```
━━━━━━━━━━━━━━━━━━━━━━━━━
  Stackpilot Sprint 状态
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TASK-001  实现登录页       done
🔄 TASK-002  接入支付 API     in-progress
⏳ TASK-003  写单元测试       pending
❌ TASK-004  dashboard 布局   failed
❓ TASK-005  多用户方案        blocked
━━━━━━━━━━━━━━━━━━━━━━━━━
待回复问题：1 条
```

图例：✅ done  🔄 in-progress  ⏳ pending  ❌ failed  ❓ blocked

## Step 2: 根据状态给出选项

### 未初始化
```bash
bash ~/Documents/github/stackpilot/scripts/init.sh
```
提示用户编辑 `stackpilot.config.yml` 设置 `qa.test_command`，然后回到 Step 1。

### Sprint 干净（无任务 或 全部 done）
询问用户想做什么新功能，然后**根据功能规模选择路径**：

**轻量功能**（用户明确说"简单改动" / 描述 < 2 句 / 单一明确需求）：
1. 跳过 brainstorming 和 autoresearch:predict
2. 直接调用 `superpowers:writing-plans` 生成轻量 spec
3. 自动创建 feature 分支 → 提交 spec → 运行 Coordinator

**标准功能**（多模块、需求模糊、涉及架构决策）：
1. 调用 `superpowers:brainstorming` 探索意图
2. brainstorming 结束后判断是否涉及 UI → 涉及则调用 `ui`（设计模式）
3. 调用 `superpowers:writing-plans` 生成 spec
4. 自动创建 feature 分支 → 提交 spec → 运行 Coordinator

### Sprint 进行中（有 pending / in-progress 任务）
展示选项：
```
A. 继续当前 Sprint（运行 Coordinator 推进任务）
B. 新增一个功能到当前 Sprint
C. 查看某个任务的详细情况
```
- A → 运行 Coordinator
- B → brainstorming / writing-plans → 提交新 spec → 运行 Coordinator
- C → 读取 `tasks/done/TASK-ID.md` 或 `tasks/arch-review/TASK-ID.md`

### 有 blocked 任务 / NEEDS_REVIEW 有内容（优先处理）
展示问题，帮助分析选项，引导用户决策。
用户决定后在 `tasks/NEEDS_REVIEW.md` 末尾追加：
```
REPLY: <决定>
```
然后运行 Coordinator 解除阻塞。

### 有 failed 任务
展示失败原因，询问用户：
- 重试 → 将 backlog.yml 中该任务改回 `pending`，运行 Coordinator
- 跳过 → 手动标记处理方式
- 人工介入 → 帮用户分析问题

## 运行 Coordinator

直接在当前会话中按 coordinator-agent 的 5 步 Entry Checklist 执行（不需要切换分支）：

1. 处理 `tasks/NEEDS_REVIEW.md`：有 REPLY → 解除阻塞；无 REPLY 但有内容 → 告知用户并停止
2. 处理 `soft-blocked` 任务：attempt_count < 3 → 自动重调度；≥ 3 → 转 hard-blocked
3. 检查超时任务 → 标记 failed
4. 调度 pending 任务，按 `complexity` 字段路由：
   - `light`: dev-agent → qa-agent（跳过 architect 和 docs）
   - `standard`: architect-agent → dev-agent → qa-agent → docs-agent
5. 若无 pending / in-progress / soft-blocked → Sprint 完成：
   - 有 UI 改动 → 调用 `ui`（polish 模式）
   - 调用 `superpowers:finishing-a-development-branch`
