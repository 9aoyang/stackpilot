# C5+C6: 约束数量与位置

> 调研日期：2026-04-20
> 目标：验证中文博客两条相邻论断——C5（约束 ≤ 5 条，否则后面的不被执行）、C6（最重要的约束放最前，位置越靠前注意力权重越高）

## 裁决
- **C5（≤5 条）**：**方向正确，具体数字无学术依据。** 多条 2024-2025 年实证研究确认「指令数量增加→执行率显著下降」，但下降是**连续曲线**而非「第 5 条突然断崖」。Claude Sonnet 4 在 100 条指令仍保持 94.4% 准确率，远高于「只执行前 4 条」的个人轶事。Anthropic 官方文档从未给出「≤5 条」这样的上限，仅主张「smallest possible set」原则。作者把个人经验（8 条→只执行 4）直接升级为规则「≤5」是过度一般化。
- **C6（位置靠前权重高）**：**现象为真，解释口径错误。** "Primacy effect" 在 LLM 中被多篇论文证实（LLMs 确实偏袒前部指令），但博客把它等同于"注意力权重越高"是混淆了三个不同机制：① **attention sink**（首 token 获得异常高的 attention 分数，但与语义无关）、② **serial position effect**（答案选择偏向前位选项）、③ **"Lost in the Middle"**（实际是 **U 形曲线，首尾都高、中间低**，不是单调递减）。作者的"位置越靠前注意力权重越高"描述是**单调递减**模型，与文献中的 U 形或 J 形曲线都不匹配。

## 证据

### Anthropic 官方
1. **Prompting best practices（Claude 4.x）** — 全文未给出任何"约束数量上限"。核心建议是「Be specific」「Provide instructions as sequential steps using numbered lists」。唯一与位置相关的是 "Put longform data at the top"（长文档放前面），不是"重要约束放前面"。https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices
2. **Effective context engineering for AI agents（Anthropic, 2025-09-29）** — 核心原则是 "the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome"，警告避免 "stuff a laundry list of edge cases into a prompt"。支持"少即是多"的方向，但没有具体数字。https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
3. **Claude Opus 4.7 指南（Anthropic）** — "specify the task, intent, and relevant constraints upfront in the first human turn"。这支持「重要内容前置」，但这里的"前置"指放在第一个人类消息里，不是"约束按重要性排序"。Anthropic 从未声明 Claude 对指令有 position decay。

### 学术研究（关键）

4. **Lost in the Middle（Liu et al., 2023, Stanford; TACL 2024）** — 核心论文。在 multi-document QA 和 key-value retrieval 上，GPT-3.5-Turbo、Claude-1.3、GPT-4、MPT-30B、LongChat-13B 等模型都呈现 **U 形曲线**：相关信息在 context 头部或尾部时性能最好，在中间时性能显著下降（GPT-3.5-Turbo 中间位置的表现甚至低于「闭卷」基线 56.1%）。这是 **retrieval accuracy** 问题，不是直接的 attention weight 测量。https://arxiv.org/abs/2307.03172 / https://aclanthology.org/2024.tacl-1.9/

5. **Primacy Effect of ChatGPT（Wang & Gao, EMNLP 2023）** — ChatGPT、GPT-3.5、GPT-4 和 Claude-instant-1.2 都有显著的 primacy bias：倾向于选择位于前部的候选答案。这是**答案选择偏差**，不是 attention 计算偏差。https://aclanthology.org/2023.emnlp-main.8/ / https://arxiv.org/abs/2310.13206

6. **How Many Instructions Can LLMs Follow at Once?（IFScale, Jaroslawicz et al., arxiv 2507.11538, 2025-07）** — 最直接验证 C5 的论文。IFScale 用 500 条关键词指令测试 20 个前沿模型。关键数据：
   - **Claude Sonnet 4**：100 条指令 94.4%，250 条 77.2%，500 条 42.9%（linear decay）
   - 三种衰减模式：threshold decay（推理模型如 o3、gemini-2.5-pro）、linear decay（gpt-4.1、claude-sonnet-4）、exponential decay（gpt-4o、llama-4-scout）
   - **Primacy effect 随密度变化**：低密度时几乎无 primacy bias，**peak 在 150-200 条指令**，极高密度时反而衰减。这意味着「把重要的放前面」只在**中等密度**有效，5 条以下场景 primacy 效应很弱。https://arxiv.org/abs/2507.11538

7. **Curse of Instructions（ManyIFEval, OpenReview R6q67CDBCH, 2025）** — 用 10 条可验证指令测试，发现**成功率按 Success_rate(1)^n 指数衰减**。原始数据：单条指令 GPT-4o ~85%、Claude 3.5 Sonnet ~90%；10 条齐执行 GPT-4o 跌到 15%、Claude 3.5 Sonnet 跌到 44%。论文建议：若追求 95% 完成率，最多放 ~2 条指令；90% 则 ~3-4 条；80% 则 ~5-7 条。**这是唯一接近"≤5"这个具体数字的学术证据。** https://openreview.net/forum?id=R6q67CDBCH

8. **Serial Position Effects of LLMs（arxiv 2406.15981）** — 系统测 104 个 model×task 组合。Primacy effect 是最常见（73/104），但曲线形状**高度依赖任务和模型**。某些 Llama2 配置在 GoEmotions 上出现"middle effect"（中间被 over-attend），这个现象连人类认知都没有。换言之，**位置效应不是单一单调曲线**，博客的"越前越重"是过简化。https://arxiv.org/html/2406.15981v1

9. **Context Rot（Chroma Research, 2025）** — 测试 18 个前沿模型（GPT-4.1、Claude Opus 4、Gemini 2.5、Qwen3），确认所有模型随 context 变长性能都下降，**Claude 系列表现相对保守但也同样衰减**。核心结论：context rot 是 transformer attention 架构属性（attention dilution + lost-in-the-middle + distractor interference 三个机制），训练无法完全解决。https://research.trychroma.com/context-rot

10. **Attention Sink 系列（arxiv 2309.17453, 2410.10781, 2504.02732）** — "首 token 获得异常高 attention 分数"是真实现象，但原因与语义无关，而是 softmax 归一化的数学性质（模型把首 token 当作「注意力池」以避免过度混合）。**这是最容易被误引用支持 C6 的现象，但它不意味着"语义上放前面就更被重视"**——attention sink 的 token 通常是无语义的开头符号。https://arxiv.org/abs/2309.17453 / https://arxiv.org/abs/2504.02732

### 社区实践

11. **Karpathy 对系统 prompt 的观察** — Claude 系统 prompt 约 17,000 词，OpenAI o4-mini 约 2,218 词。模型方并不避讳放大量约束；Karpathy 提出"system prompt learning"概念，暗示重点是 prompt 的组织方式而非数量硬上限。https://x.com/karpathy/status/1921368644069765486

12. **OpenAI Cookbook（GPT-5.x prompting guides）** — 推荐 "prefer small, explicit edits to clarify conflicting rules, remove redundant or contradictory lines, tighten vague guidance"。没有数量上限，强调质量。https://cookbook.openai.com/examples/gpt-5/gpt-5-1_prompting_guide

### 反对声音

13. **Claude 在长指令时保持能力**：IFScale 报告 Claude Sonnet 4 在 100 条指令仍有 94.4% 准确率，Claude Sonnet 4 在 10 条 ManyIFEval 全对比率达 58%（自修正后）。这些数字**直接否定**"超过 5 条就只执行前 4 条"的说法。
14. **Context Rot 发现**：Claude 在 150K+ tokens 仍能保持指令跟随，而 GPT-4o 在 100K 后明显退化——不同模型系列的"上限"差异很大，不存在一个通用的 N 条约束阈值。

## 分析

### C6：位置效应的准确描述是什么？

博客作者说"位置越靠前，注意力权重越高"，这是一个**单调递减**模型。实际文献显示三层现象叠加：

| 机制 | 描述 | 是"attention weight"吗？ |
|------|------|------|
| Attention Sink | 首 token 吸走大量 attention 分数 | 是，但与语义无关 |
| Primacy Effect | 答案选择偏向前位候选 | 否，是输出选择偏差 |
| Lost in the Middle | 检索准确率 U 形曲线（首尾高中间低） | 否，是任务完成率 |
| Recency Effect | 末位内容也被优先使用 | 否，是下一 token 条件概率偏置 |

作者把"primacy"和"attention weight"等同了。实际上 **primacy effect 是输出层面的选择偏差**，不是"前面的 token 在 attention 计算中获得更大权重"。并且 Lost in the Middle 明确指出**尾部也高**——博客没提 recency 效应，说明作者只记住了"前面重要"这半边。

正确的说法应该是：LLM 对 prompt 不同位置的 token 关注度不均匀，**首尾高、中间低**；实证上 primacy 往往比 recency 更强，但两者都存在。把约束放在 prompt 的首部或尾部都比塞中间好。

### C5："5 条"有实证依据吗？

**部分有，部分无**：
- **"约束数量增加→遵守率下降"**：100% 有证据（IFScale, Curse of Instructions, FollowBench, ComplexBench 全部确认）。
- **"不超过 5 条"这个具体数字**：没有直接实证支持。最接近的是 Curse of Instructions 按指数衰减公式推导出的「95% 目标 → 2 条；90% → 3-4 条；80% → 5-7 条」，这暗示 **"5 条" 只是大致对应 ~80% 可靠度的配额**，不是物理硬上限。
- **"后面的约束被稀释而不被执行"的机制描述**：**不准确**。IFScale 的 primacy 数据显示，在 5-10 条这样低密度下，模型对前后指令的遵守率差异很小；primacy bias 要到 150-200 条才显著。作者那次"8 条只执行了 4"更可能是**总完成率问题**（指数衰减导致 P(all 8 pass) 很低），而不是"前 4 条吃掉了全部注意力"。

把"约束数量 ≤ 5"当作启发式是合理的工程经验；但说"第 5 条之后就被稀释"混淆了 total success rate 和 positional attention 两个完全不同的机制。

## 一句话结论

**C5 方向对、数字无据：减少约束数量确实提高遵守率，但"≤5 条"是轶事而非定律；C6 现象对、解释错：LLM 确有位置偏差，但模式是首尾强、中间弱的 U 形，不是博客说的"越靠前权重越高"的单调曲线。**
