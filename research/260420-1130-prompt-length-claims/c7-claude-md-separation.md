# C7: 背景放 CLAUDE.md 而非 Prompt

## 裁决
**部分支持**（大方向符合官方推荐，但"prompt 里绝不重复背景"是过度简化）

原文声明实际包含两个子命题：
- **C7a**：项目背景应持久化到 CLAUDE.md — **强支持**，Anthropic 官方明确如此设计
- **C7b**：每次 prompt 里重复写背景是"自我安慰"、删掉也不影响质量 — **部分反驳**，官方同时鼓励在 prompt 里提供"具体上下文"（specific context），且存在"重复加深"（primacy + recency）这类有意设计

## 证据

### Anthropic 官方（关键）

**[1] Claude Code 官方 Memory 文档 / "How Claude remembers your project"**
URL: https://code.claude.com/docs/en/memory

原文直接定义了 CLAUDE.md 的职责：

> "CLAUDE.md files are markdown files that give Claude persistent instructions for a project, your personal workflow, or your entire organization."

> "Treat CLAUDE.md as the place you write down what you'd otherwise re-explain. Add to it when: Claude makes the same mistake a second time; ...You type the same correction or clarification into chat that you typed last session; A new teammate would need the same context to be productive."

这是对 C7 的直接官方背书：**"你本来要重复解释的东西"→ 写进 CLAUDE.md**。

同时官方也明确了 CLAUDE.md **不是**用来放"每次任务的具体指令"的：

> "Keep it to facts Claude should hold in every session: build commands, conventions, project layout, 'always do X' rules."

**[2] Best Practices for Claude Code 官方文档**
URL: https://code.claude.com/docs/en/best-practices

关键分工表格（原文）：

> "CLAUDE.md is loaded every session, so only include things that apply broadly. For domain knowledge or workflows that are only relevant sometimes, use skills instead."

原文给出的 "✅ Include / ❌ Exclude" 表格明确把"Architectural decisions specific to your project"列为 CLAUDE.md 应包含项，把"Information that changes frequently"列为排除项。

但同一页在"Provide specific context in your prompts"章节**又反向强调**：

> "Claude can infer intent, but it can't read your mind. Reference specific files, mention constraints, and point to example patterns."

且给了明确的 before/after 对比：
- Before: "fix the login bug"
- After: "users report that login fails after session timeout. check the auth flow in src/auth/, especially token refresh..."

**这说明官方立场是：通用背景放 CLAUDE.md，任务特定的上下文仍要在 prompt 里明确给出。** 这恰好与博客作者"prompt 里不要写背景"的强断言有张力。

**[3] Anthropic Help Center: Give Claude context — CLAUDE.md and better prompts**
URL: https://support.claude.com/en/articles/14553240-give-claude-context-claude-md-and-better-prompts

这篇官方 Help Center 文章本身的标题就把"CLAUDE.md"和"better prompts"并列——暗示两者是**互补**而非替代。文章建议 CLAUDE.md 包含：
- Commands（build/test/lint/run）
- Conventions（命名、错误处理、文件布局）
- Architecture（三句话概述主要模块及其通信方式）
- Hard constraints
- Known gotchas

对 prompt 的建议是："State the outcome, not the steps"——告诉 Claude *做什么*和*为什么*。这是职责分工的直接官方表述。

**[4] Anthropic 官方工程博客: Effective context engineering for AI agents**
URL: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

支持 C7 的核心论据，原文主张 just-in-time 检索而非前置堆上下文：

> "Rather than pre-processing all relevant data up front, agents built with the 'just in time' approach maintain lightweight identifiers...and use these references to dynamically load data into context at runtime using tools."

同时关于冗余信息：

> "One of the safest lightest touch forms of compaction is tool result clearing—once a tool has been called deep in the message history, why would the agent need to see the raw result again?"

这为"重复写背景是浪费"提供了理论支撑。

### 学术研究

**[5] "Position is Power: System Prompts as a Mechanism of Bias in LLMs"（arXiv 2505.21091, 2025）**
URL: https://arxiv.org/abs/2505.21091

论文发现同一段信息放在 system prompt 还是 user prompt 中**会产生不同的模型行为**：

> "Significant biases, manifesting in differences in user representation and decision-making scenarios...raising fundamental questions about how information position shapes model outputs."

对 C7 的含义：**位置确实重要**，但论文更多在指出"位置带来偏见/不透明性"这一风险面，并非直接证明"CLAUDE.md 优于 prompt"。注意：Claude Code 官方明确说过 CLAUDE.md 内容"以 user message 形式注入"而非 system prompt（见证据 1 troubleshooting 段落：*"CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself"*），所以这篇论文的"系统 vs 用户"对比不能直接映射到 CLAUDE.md vs 手写 prompt 的对比。

### 社区实践

**[6] Armin Ronacher: Agentic Coding Recommendations**
URL: https://lucumr.pocoo.org/2025/6/12/agentic-coding/

Armin 的做法印证 C7a：把"运行时事实"（如"调试模式下邮件被记录到日志"）写进 CLAUDE.md，让 agent 自动获取并行动：

> "It knows that emails are being logged thanks to a CLAUDE.md instruction and it automatically consults the log for the necessary link to click."

但他**没有**主张"prompt 里不要写背景"——他的核心建议是让工具和日志输出成为 agent 的主要信息来源。

**[7] alexop.dev: Stop Bloating Your CLAUDE.md — Progressive Disclosure**
URL: https://alexop.dev/posts/stop-bloating-your-claude-md-progressive-disclosure-ai-coding-tools/

**部分反对 C7 的强形式**。作者主张 CLAUDE.md 应极简（作者自己 50 行，HumanLayer 推荐 <60 行）：

> "Half your context budget is gone before any work begins."

分配策略是 progressive disclosure：
- CLAUDE.md 只留项目概述、基本命令、技术栈、文件结构
- 项目特定陷阱放 `/docs`，工具可执行的规则放 ESLint/Prettier
- 用一句 "IMPORTANT: Read relevant docs below before starting" 让 Claude 按需加载

这意味着"背景"本身应该被**进一步分层**，不是简单搬到 CLAUDE.md 就完事。

**[8] MindStudio: Context Rot in Claude Code**
URL: https://www.mindstudio.ai/blog/what-is-context-rot-claude-code

> "A bloated CLAUDE.md is a constant tax on every session...Keep CLAUDE.md under 500 words and focused on what Claude actually needs."

### 反对声音 / 反直觉证据

**[9] 关于"有意在 prompt 里重复背景"的证据**
来自 Claude Code 逆向工程分析（证据来源之一: indiehackers 反向工程文章、prompting best practices 讨论）：

> "Claude Code's security declaration appears at both the start and end of the prompt, not because the engineers were forgetful — because they understand the U-shaped attention curve. As conversations grow longer, the model's adherence to system prompt instructions degrades (noticeable at 80K+ tokens). Injecting reminders mid-conversation refreshes the rules via recency bias."

这是对博客作者"重复写等于自我安慰"的**直接反驳**：在某些场景下（长会话、强 safety 约束、边缘情况），在 prompt 中重申关键约束是**有意为之**的 primacy + recency 设计。

**[10] GitHub Issue #29971 — Claude Code Context Bloat**
URL: https://github.com/anthropics/claude-code/issues/29971

CLAUDE.md 本身存在**已知工程问题**：在某些版本中被重复注入（每次 tool call 都注入一遍，50 次调用 × 10KB = 500KB 浪费），迫使用户人为保持 CLAUDE.md < 5KB。这说明"把东西搬到 CLAUDE.md 就一劳永逸"是简化叙事——CLAUDE.md 也有 stale context、重复注入、污染长会话 的风险。

**[11] Claude Code 官方 memory 文档关于 stale 和 compaction 的陷阱**
URL: https://code.claude.com/docs/en/memory

> "Files over 200 lines consume more context and may reduce adherence."

> "CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself. Claude reads it and tries to follow it, but there's no guarantee of strict compliance, especially for vague or conflicting instructions."

官方亲自承认 CLAUDE.md **不是硬性配置**，只是 context；过长会降低依从。这与博客"放进 CLAUDE.md 就解决了"的隐含假设相悖。

## 分析

### 职责分离是否被官方明确推荐？
**是。** 证据 [1][2][3] 三份官方文档用不同表述反复强调：CLAUDE.md = "你本来要重复解释的东西"，prompt = "当前任务的具体目标"。博客作者说的方向正确。

### "Prompt 里写背景等于浪费"这个强断言是否过度简化？
**是。** 至少四种情况下 prompt 里仍然该（或必须）带背景：

1. **任务特定的子背景**：官方 best-practice 原话 *"Reference specific files, mention constraints, and point to example patterns"*。CLAUDE.md 装不下所有可能的局部背景。
2. **长会话中的关键约束**：primacy + recency 效应是真实的，安全/风格关键点在长会话中需要 mid-conversation 重申（证据 [9]）。
3. **CLAUDE.md 未覆盖或已过期的点**：当 prompt 涉及 CLAUDE.md 未写、或 CLAUDE.md 已滞后于代码库真实状态时，prompt 中重申比依赖过期 memory 更安全。
4. **与 CLAUDE.md 冲突或需要覆盖的场景**：如一次性例外、实验性任务。

作者说"删掉 prompt 里背景，输出质量没变"是一个 **n=1 的主观观察**，未做对照实验，也未排除"他的任务对背景不敏感"这一可能。

### CLAUDE.md 自身的陷阱被文章忽略
博客作者只谈了"搬过去就好"，没有谈到：

- **Bloat**：CLAUDE.md 过长反而降低依从性（证据 [2][8][11]）；官方建议 <200 行
- **Stale**：CLAUDE.md 不会自动同步代码变化，可能变成陷阱
- **重复注入 Bug**：历史版本存在 O(N) 增长问题（证据 [10]）
- **硬度不足**：官方承认 CLAUDE.md 是 context 而非 enforced config，"picks one arbitrarily when conflicting"（证据 [1]）；关键约束要靠 hooks，不能只靠 CLAUDE.md
- **弱依从性**：作为 user message 注入，长会话里会被稀释

健康实践是 **三层分离**：
- CLAUDE.md / rules：高频复用的项目常识
- Skills / docs：按需加载的领域知识
- Prompt：当前任务的具体目标 + 局部上下文 + 需要重申的关键约束

单纯说"全搬 CLAUDE.md、prompt 别写背景"是过度简化。

## 一句话结论
**"项目通用背景应放 CLAUDE.md"被 Anthropic 官方直接推荐并背书；但"每次 prompt 里重复写背景等于自我安慰"是过度简化——任务特定上下文、长会话中的关键约束重申、覆盖过期 memory 等场景下，prompt 带背景是有意设计而非浪费。**
