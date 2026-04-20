# C3: 4 档任务-长度映射

## 裁决

- **分档方向性**（任务越简单越短、越复杂越长）：**部分支持** — 方向性被官方与学术文献普遍认同，但文献全部停留在「simple / complex」的定性二分或三分，没人用「单点操作/功能实现/模块设计/架构决策」这种四档切法。
- **具体字数范围**（20-40/80-150/150-250/100-180）：**存疑至反驳** — 没有任何一手来源给出过与之相近的字数带。最接近的第三方数字（mediatech.group 的 50-100 / 150-300 / 300-500 words）是英文 words，不同数量级，且自述为经验指引非实证研究。作者的字数带属主观锚定。

## 证据

### Anthropic 官方

1. **Claude Code Best Practices** — 官方通篇只谈「specificity / context window management / concise CLAUDE.md (<300 行)」，在 prompt 长度上明确的唯一建议是**「具体 > 模糊」**，用的是 before/after 示例对比而非字数范围。对「小改动」（typo、log line、rename）明确建议「skip planning, do directly」，但并未给字数。
   https://code.claude.com/docs/en/best-practices

2. **Prompting best practices (Claude 4.6/4.7)** — 官方反而指出 **Claude Opus 4.7 会根据任务复杂度自行 calibrate 响应长度**，暗示「长度匹配复杂度」是模型内部行为而非 prompt 端硬规则。对输入端也没给任务 × 字数表。
   https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

3. **Prompt engineering overview** — 官方入口页只列出技巧清单（clarity / examples / XML / CoT / chaining），全程无字数建议。
   https://platform.claude.com/docs/en/docs/build-with-claude/prompt-engineering/overview

4. **Chain of Thought docs** — 官方关于 CoT 触发器的定性分三层（zero-shot CoT、guided CoT、structured CoT），并未把它与特定字数档位绑定。作者"第 4 档加 CoT 触发器"的主张方向上和官方一致，但"100-180 字"这个数字官方未出处。
   https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/chain-of-thought

### 学术研究

5. **"Effects of Prompt Length on Domain-specific Tasks for LLMs" (arXiv 2502.14255, 2025)** — 实证结论：长 prompt（>=200% default tokens）在 domain-specific 任务上普遍优于短 prompt（F1 +0.07 ~ +0.08）；但论文**明确不给字数推荐**，因为 optimal length 随 task/dataset/model 变动。这反而是对"固定字数档"的反证。
   https://arxiv.org/html/2502.14255v1

6. **"Same Task, More Tokens" 系列研究（被 Grit Daily、mlops.community 等多处引用）** — 核心发现：LLM 推理性能在 ~3000 tokens 输入时就开始衰减，远低于技术上限。这支持"更长 ≠ 更好"，但同样不给 task-tier 字数表。
   https://gritdaily.com/impact-prompt-length-llm-performance/
   https://mlops.community/the-impact-of-prompt-bloat-on-llm-output-quality/

7. **"Why Prompt Design Matters: A Complexity Analysis of Prompt Search Space" (ACL 2025)** — 强调 prompt 作为 selector 的作用，优化后的 prompt 在推理任务上提升 50%+；但作用机制关乎**选择器精度**，不是长度分档。
   https://aclanthology.org/2025.acl-long.1562/

### 社区实践

8. **mediatech.group "Impact of Prompt Length: Data-Driven Study"** — 文中给出"simple 50-100 words / moderate 150-300 / complex 300-500 words"的三档建议。这是**最接近作者分档结构**的公开来源，但：①是英文 words 而非中文字，数量级差 1.5-2 倍；②三档不是四档；③作者自述为经验指南而非严格实证。
   https://mediatech.group/prompt-engineering/the-impact-of-prompt-length-on-llm-performance-a-data-driven-study/

9. **Anthropic 官方 "be clear and direct" + Claude 4.7 docs** — 明确写「upfront specify task, intent, constraints 有助于最大化 autonomy & intelligence，并 minimize extra token usage」。这支持方向性（复杂任务需更详细 upfront 说明），但全程没有字数带。
   https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/be-clear-and-direct

10. **Reddit/vellum/xda 等社区经验** — 共识是「clarity > length, context > complex prompts, iterative > one-shot」。没有任何社区 thread 以"字数按任务分档"作为核心建议。
    https://www.vellum.ai/blog/prompt-engineering-tips-for-claude
    https://www.xda-developers.com/dont-need-complex-prompts-to-get-value-from-claude/

### 反对声音

11. **arXiv 2502.14255（同上）** — "longer prompts generally enhance model performance, while shorter prompts can be detrimental"。这直接反驳了作者第 1 档"单点操作 20-40 字就够"的隐含假设：即便是简单分类任务，把 prompt 从短改长也能 +0.07 F1。换言之，任务再简单，也可能受益于更详细的 prompt——字数上限不是硬约束。
    https://arxiv.org/html/2502.14255v1

12. **"Are Longer Prompts Always Better?" (arXiv 2412.14454, 推荐系统场景)** — 与 #11 形成张力：在特定任务下较长 prompt **不一定**更好。结论是"取决于任务和模型"，不支持任何固定的字数档。
    https://arxiv.org/html/2412.14454v1

## 分析

### 分档方向性是否成立

**部分成立，且粒度比作者讲得粗。** 官方和学术界反复说的是「复杂任务给更多上下文」的**定性**方向，但细分只做到「simple vs complex」或「simple / moderate / complex」三档。把编程任务切成"单点操作/功能实现/模块设计/架构决策"四档，是作者自己的领域映射，没见过别人这么分。方向性没问题，分档粒度属原创，未经验证。

### 具体字数范围是否有实证支撑

**基本没有。** 作者的数字（20-40、80-150、150-250、100-180 中文字）：

- Anthropic 官方、arXiv 两篇直接相关论文、Claude Code docs 都**没出现过**类似字数带。
- 唯一在结构上可比的 mediatech.group 给了 50-100 / 150-300 / 300-500 **英文 words**，和中文字数量级不直接可比（1 英文 word ≈ 2-4 中文字时，作者字数档明显偏低）。
- 学术界的一致态度是「optimal length 依赖 task、dataset、model」，**拒绝**给固定数字。

作者的具体数字属于主观锚点，对读者有"psychological anchor"作用但没有实证背书。

### 第 4 档 < 第 3 档的反直觉性是否合理

**勉强可解释，但论证方式不透明。** 作者的解释是"架构决策靠 CoT 触发器让模型展开，无需用户把所有细节写进 prompt"。官方 CoT 文档确实支持"让模型自己想"的方向——Claude 4.7 的 adaptive thinking 会根据复杂度自动延展推理。但：

- 官方从未说过"架构决策 prompt 就该更短"。
- 作者把"加 CoT 触发器"和"字数更短"绑定成因果，是**他自己的方法论组合**而非业界共识。
- 合理替代解释：架构决策更依赖**模型内部知识调度**（已训练过大量架构案例），用户无需像"模块设计"那样把所有 CRUD 字段写清；但这也可以反过来论证**架构决策需要更多**上下文（包括现有系统约束、团队偏好、非功能需求）。两种论证都自洽。

这条反直觉说法是作者的叙事选择，不是被验证的规律。

## 一句话结论

分档方向性（复杂→更长）被证据支持，但这套具体的"4 档 × 中文字数带"是作者基于非正式自测的主观编排，既无 Anthropic 官方来源、也无学术论文支撑，最相近的公开数字（mediatech 三档英文 words）数量级也不匹配——把它当启发式可以，当"最优"是夸大。
