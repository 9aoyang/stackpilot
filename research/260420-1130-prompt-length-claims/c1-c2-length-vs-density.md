# C1+C2: 长度 vs 信息密度

## 裁决
**部分支持** — 核心直觉（信号密度 > 原始长度）与 Anthropic 官方立场和一批学术证据高度吻合，但文章把"背景故事/推理过程/礼貌用语"一刀切地定义为"零贡献噪音"是过度简化：few-shot 示例、CoT、受众/目标等"非直接任务/约束"的内容在大量实证中仍有显著正贡献，只是边际收益在变小。

---

## 证据（按来源分类）

### Anthropic 官方

- [Effective context engineering for AI agents (Anthropic Engineering)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 官方定义："find the _smallest possible_ set of high-signal tokens that maximize the likelihood of some desired outcome"；并提出 **"context rot"**：as tokens increase, 模型准确召回能力下降；模型有 **"attention budget"**，每增加一个 token 都在消耗这个预算。**这几乎是文章论断 C1 的官方翻译版本**，而且还给出了具体反例："don't stuff a laundry list of edge cases into a prompt" —— 与文章反对"重复确认/稀释约束"一致。

- [Best Practices for Claude Code (code.claude.com)](https://code.claude.com/docs/en/best-practices) — 直接原文："Claude's context window fills up fast, and **performance degrades as it fills**"；针对 CLAUDE.md："If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise. Fix: Ruthlessly prune. If Claude already does something correctly without the instruction, delete it". 标题为 "**The over-specified CLAUDE.md**" 的反模式章节直接印证 C2 中"稀释约束"的机制。

- [Prompting best practices (platform.claude.com)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — Opus 4.7 新增的 "Response length and verbosity" 章节提供了官方降冗提示模板："Provide concise, focused responses. Skip non-essential context, and keep examples minimal." —— 说明 Anthropic 自己也在引导用户切掉非必要内容。但同一文档同时强调 few-shot examples、XML 结构、明确受众/输出格式是必备的，**这是对 C2 "只留任务/约束/期望结果三类" 的反向约束**：示例属于"期望结果"的扩展，但受众描述、结构化标签等并不在文章定义的三类中，却被官方列为关键技巧。

- [6 Techniques for Effective Prompt Engineering (Anthropic PDF)](https://www-cdn.anthropic.com/62df988c101af71291b06843b63d39bbd600bed8.pdf) — Anthropic 推荐的 prompt 结构包括：**task + audience + goal/output format**。"audience"（受众/面向谁）严格讲是"背景信息"，不是文章定义的三类之一，但被列为核心技巧之一。

### 学术研究

- [Lost in the Middle: How Language Models Use Long Contexts — Liu et al. 2023 (arXiv:2307.03172, TACL 2024)](https://arxiv.org/abs/2307.03172) — 一手论文，实证：信息处于 context 中间时性能显著下降；context 越长，即便是"专门为长上下文设计"的模型也整体退化。支持 C1：长度本身是风险。

- [Large Language Models Can Be Easily Distracted by Irrelevant Context — Shi et al. 2023 (arXiv:2302.00093, ICML 2023)](https://arxiv.org/abs/2302.00093) — 一手论文，提出 GSM-IC benchmark（在数学题里掺入与解题无关的句子），结论："model problem-solving accuracy can be **dramatically decreased** when irrelevant information is included"，而且显式加一句 "ignore the irrelevant information" 能部分缓解。**这是对 C2 最硬核的实证支撑**：无关背景对输出质量的贡献不是"基本是零"，而是"显著为负"。

- [How Is LLM Reasoning Distracted by Irrelevant Context? — 2025 (arXiv:2505.18761)](https://arxiv.org/abs/2505.18761) — 一手论文，GSM-DC benchmark，结论：LLM 对无关上下文敏感，错误率随 distractor 数量按幂律增长，且指数随推理深度增加而增大。时效更新的二次验证。

- [Context Length Alone Hurts LLM Performance Despite Perfect Retrieval — 2025 (arXiv:2510.05381)](https://arxiv.org/abs/2510.05381) — 一手论文，在 5 个开源/闭源模型上，**即使把无关 token 替换为空白、或强制 attention 只看相关内容**，长度增加仍使性能下降 **13.9%–85%**。这条比 C1 更激进：长度本身就是毒性，与噪音内容无关。

- [Chain-of-Thought Prompting Elicits Reasoning in LLMs — Wei et al. 2022 (arXiv:2201.11903, NeurIPS 2022)](https://arxiv.org/abs/2201.11903) — **反向证据**：让模型/被 prompt 展示"推理过程"能显著提高算术/常识/符号推理任务的表现（在 PaLM 540B 上 GSM8K 达 SOTA）。文章把"推理过程"归为零贡献噪音，在经典 CoT 实证下不成立。

- [Prompting Science Report 2: The Decreasing Value of Chain of Thought — 2025 (arXiv:2506.07142)](https://arxiv.org/abs/2506.07142) — **细微修正**：CoT 在新一代模型上收益大幅下降，"only marginal gains"，且增加 token 成本和输出方差。这说明文章的直觉在最新 Claude/GPT 上比在老模型上更成立，但仍不是"基本是零"。

- [Mind Your Tone: Investigating How Prompt Politeness Affects LLM Accuracy — 2025 (arXiv:2510.04950)](https://arxiv.org/abs/2510.04950) 与 [Should We Respect LLMs? — 2024 (arXiv:2402.14531, ACL SICon)](https://arxiv.org/abs/2402.14531) — 两篇一手论文关于礼貌用语：结果**矛盾且幅度不大**。2024 年那篇说"过度礼貌不保证更好、粗鲁会更差"；2025 年那篇反而发现粗鲁略优（84.8% vs 80.8%），但聚合到多领域后效应消失。**裁决**：礼貌用语对质量的影响小且不稳定，支持 C2 "贡献基本是零"的部分，但并非"稀释约束"的元凶。

### 社区实践

- [Karpathy on "context engineering" (X, 2025)](https://x.com/karpathy/status/1937902205765607626) — 原文：**"context engineering is the delicate art and science of filling the context window with just the right information for the next step"**。Karpathy 用 CPU/RAM 比喻：你的工作像操作系统，往工作内存里装"正好够用"的信息。**与文章 C1 "有效信息密度" 几乎同构**。

- [Simon Willison — Changes in the system prompt between Claude Opus 4.6 and 4.7 (simonwillison.net, 2026-04-18)](https://simonwillison.net/2026/apr/18/opus-system-prompt/) — 直接引用 Anthropic 在 Opus 4.7 系统提示里加入的段落："Claude keeps its responses focused and concise... Even if an answer has disclaimers or caveats, Claude discloses them briefly." 反向印证：Anthropic 自己正在产品层面打击"冗长/过度礼貌/客套式免责声明"。

- [The Impact of Prompt Bloat on LLM Output Quality — MLOps Community](https://mlops.community/the-impact-of-prompt-bloat-on-llm-output-quality/) — 社区综述，核心观点与文章一致：prompt bloat 导致幻觉率上升、attention 稀释。属二手综述，作为风向标使用。

- [Disadvantage of Long Prompt for LLM — PromptLayer Blog](https://blog.promptlayer.com/disadvantage-of-long-prompt-for-llm/) — 举了一个可验证数据点："a well-structured 16K-token prompt with RAG outperformed a monolithic 128K-token prompt in both accuracy and relevance"。属综合性博客，非一手研究。**循环互引注意**：此类 blog 大量互相引用 Lost-in-the-Middle 和 GSM-IC，不能作为独立证据，只能作为学术结论的传播力指标。

- [Hamel Husain — Prompt Engineering notes (hamel.dev)](https://hamel.dev/notes/prompt-eng/) — 观点："when you write a prompt, you are forced to clarify your assumptions and externalize your requirements—good writing is good thinking." Hamel 的主线是 evals 驱动，但他强调明确任务/约束/期望输出比花哨 prompt 更重要，**间接支持 C1**。

### 反对/质疑声音

- [CoT Prompting (Wei et al.)](https://arxiv.org/abs/2201.11903) — 最强反例：让模型在 prompt 中展示"推理过程"能让准确率从约 18% 跳到 56%（GSM8K, PaLM 540B）。文章"推理过程贡献基本是零"的说法在这里被直接推翻。

- [Few-Shot Prompting Guide](https://www.promptingguide.ai/techniques/fewshot) + [The Few-Shot Dilemma (arXiv:2509.13196)](https://arxiv.org/html/2509.13196v1) — few-shot 示例（本质上是"背景/先例"）在大量任务上是净正，但"示例太多"也会反噬。这说明 C2 "背景故事 = 噪音"的粗粒度分类有问题：**示范性背景（例子）与装饰性背景（用户的个人故事/情感铺垫）应该分开对待**。

- [Karpathy 的定义](https://x.com/karpathy/status/1937902205765607626) — Karpathy 同时说了 **"Too little context (or the wrong kind) and the model will lack the information to perform optimally"**。这不完全反对 C1，但拒绝"越短越好"的朴素解读。

---

## 分析

**证据指向的一致结论**：prompt 的质量由"高信号 token / 总 token"的比值决定，而不是总 token 绝对数。这一点有 Anthropic 官方表述（"smallest set of high-signal tokens"、"context rot"、"attention budget"）、Karpathy 的定义、以及多篇一手论文（Lost-in-the-Middle、GSM-IC、GSM-DC、Context Length Alone Hurts）联合支撑。作者 C1 的直觉与主流共识同构，**基本成立**。

**文章过度简化的部分**：C2 把"背景故事/推理过程/重复确认/礼貌用语"一刀切为零贡献是误导性的。证据上有三层反驳：(1) **推理过程**——CoT 的原始论文证明它能带来数量级的准确率提升，虽然在新模型上边际递减，但远未到"基本是零"；(2) **背景/示例**——Anthropic 官方模板里 audience、few-shot examples 都是推荐项，属于文章定义之外的"有效信息"；(3) **礼貌用语**——实证结果在正负之间小幅波动，影响"小到可以忽略"是对的，但说它"稀释真正有价值的约束"缺乏证据，因为那几个 token 对 attention budget 的占用可忽略。文章把"低效的冗余"和"真正稀释信号"混为一谈。

**更精确的表述应该是**：prompt 的有效性取决于信号密度而非长度；但"信号"的定义比"任务+约束+期望结果"宽——它包括**模型不知道的事实、与任务相关的示例、明确的输出受众和格式、必要的推理脚手架**。文章作者的个人实验（"删掉 80%"）可能在他自己的高冗余基线上成立，但把结论推广为"除三类外都是零贡献"会让读者在写 prompt 时切掉必要的示例和结构说明，反而降低输出质量。

---

## 主 Agent 可用的一句话结论

核心直觉（prompt 质量取决于信号密度而非长度）与 Anthropic 官方立场和多篇一手学术论文一致，但"除任务/约束/期望结果外都是零贡献噪音"的三分法过度简化——CoT、few-shot 示例、受众说明在实证中仍有正贡献，文章把"低效冗余"和"稀释信号"混为一谈。
