# C8: 架构决策 CoT 触发器

## 裁决
**部分支持（强时效性修正）**：CoT 触发器在 2022-2023 年的中等规模模型上被广泛证实有效，在当下（Claude Opus 4.6/4.7 + 自带 adaptive thinking）时代，这类"显式推理触发器"的增益已大幅下降，对"架构决策"这种**非数学/非符号推理**的开放型任务，证据指向增益微弱甚至可能引入不稳定性。作者的写法（"按以下顺序分析：1. X 2. Y 3. Z"）是 guided CoT 的一种，在**思考关闭**的模型上仍可能有增益；但 Anthropic 官方明确建议对 Claude 4.7 这类新模型"prefer general instructions over prescriptive steps"。

---

## 证据

### Anthropic 官方

1. **Anthropic 官方 Chain-of-Thought 文档**：仍然推荐 CoT，列出三种写法——basic（"think step-by-step"）、guided（给出具体步骤编号列表）、structured（用 `<thinking>` `<answer>` XML 标签）。适用场景为"a human would need to think through"的复杂任务。
   - https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought

2. **Anthropic 官方 Extended Thinking 文档**：Claude Opus 4.6/4.7 + Sonnet 4.6 使用 adaptive thinking（`thinking: {type: "adaptive"}`），模型自行判断何时/多深入推理；extended thinking 默认**不开启**，需要在 API 请求显式声明。CoT 和 extended thinking 被定位为"**complementary, not redundant**"。
   - https://platform.claude.com/docs/en/build-with-claude/extended-thinking

3. **Anthropic 官方 Prompting Best Practices（Claude 4.6/4.7）原文**："**Prefer general instructions over prescriptive steps.** A prompt like 'think thoroughly' often produces better reasoning than a hand-written step-by-step plan. Claude's reasoning frequently exceeds what a human would prescribe." 这是对作者手法的直接反驳。
   - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

4. **Anthropic 官方 Claude Opus 4.7 with Claude Code 博客**："Treat Claude more like a capable engineer you're delegating to than a pair programmer you're guiding line by line." 明确反对把推理路径写死在 prompt 里。
   - https://claude.com/blog/best-practices-for-using-claude-opus-4-7-with-claude-code

5. **Extended Thinking Tips（Claude 官方）**："Manual CoT as a fallback. When thinking is off, you can still encourage step-by-step reasoning" ——明确把 prompt 级 CoT 定位为 fallback，不是首选。
   - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/extended-thinking-tips

### 学术研究

6. **Wei et al. 2022（CoT 原始论文）**：首次提出 CoT，证明在 540B PaLM 上 few-shot CoT exemplars 可显著改善 GSM8K（算术/符号推理）。但原论文的"CoT"是"提供推理示例"（few-shot exemplars），不是"给出分析顺序"的 guided prompt。增益"naturally emerges in sufficiently large language models"。
   - https://arxiv.org/abs/2201.11903

7. **Kojima et al. 2022（Zero-Shot CoT）**："Let's think step by step" 作为 zero-shot trigger 在 GSM8K 上带来 +30.3pp 的绝对提升。但仍然局限于算术/符号推理任务。
   - https://arxiv.org/abs/2205.11916

8. **Sprague et al. 2024 "To CoT or not to CoT?"（ACL 2024 核心论文）**：对 20+ 任务的元分析显示 CoT 的增益"mainly on math and symbolic reasoning"——GSM8K +66.9pp、MATH +41.6pp，但 commonsense/reading comprehension/language understanding/general knowledge 上**"little to no separation"（差别 <1pp）**。MMLU 上 95% 的 CoT 增益来自包含 `=` 的数学题。结论："CoT is unnecessary for many problems where it is widely employed"。
   - https://arxiv.org/html/2409.12183

9. **Liu et al. 2024 "Mind Your Step (by Step)"（ICML 2025）**：在"人类思考反而越想越错"的任务（implicit statistical learning、visual recognition、exception-containing patterns）上，CoT 导致 o1-preview 相对 GPT-4o **下降 36.3pp**。CoT 不是免费午餐。
   - https://arxiv.org/abs/2410.21333

10. **Wharton GAIL Lab 2025 Technical Report "The Decreasing Value of Chain of Thought in Prompting"**：测试 Claude Sonnet 3.5 + GPT-4o + Gemini 2.0 Flash（非推理模型）和 o3-mini/o4-mini（推理模型）。非推理模型 CoT 带来 4.4%-13.5% 的增益，但**延迟增加 35%-600%**；推理模型几乎没有增益（2.9%-3.1%）甚至出现性能下降。Gemini Pro 1.5 在"易题"上因为 CoT **下降 17.2pp**（把本来能答对的搞错了）。
    - https://gail.wharton.upenn.edu/research-and-insights/tech-report-chain-of-thought/

### 社区实践

11. **Prompt Engineering Guide（promptingguide.ai）**：CoT 经典教材。区分 few-shot CoT（带示例）和 zero-shot CoT（"Let's think step by step"），但**未更新**现代模型上的饱和讨论。
    - https://www.promptingguide.ai/techniques/cot

12. **Anthropic Opus 4.7 社区观察**："At the default high effort setting, the model almost always thinks. At lower effort levels, it will skip thinking on trivial queries." ——现代 Claude 对大多数非平凡任务会自发推理，不需要外部触发。
    - https://allthings.how/claude-opus-4-7-adaptive-thinking-explained/

### 反对声音

13. **Anthropic 官方在 Opus 4.5/4.6/4.7 prompting guide 中明确提醒**："Claude Opus 4.5 is particularly sensitive to the word 'think' and its variants. Consider using alternatives like 'consider,' 'evaluate,' or 'reason through' in those cases." ——连触发词都需要小心，某些情况下 'think' 会过度触发推理。
    - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

14. **Liu et al. 2024 + Wharton 2025 共同结论**：CoT 在"简单题上引入错误"（introduces variability that causes errors on easy questions the model would otherwise answer correctly）——这是 CoT 的真实代价。

---

## 分析

### CoT 对推理任务的增益是否仍然显著？

**仅对数学和符号推理显著，对开放性任务微弱**。Sprague 2024 的元分析是目前最强证据：GSM8K 等算术题 CoT 增益 >40pp，但 commonsense reasoning、reading comprehension、general knowledge 类任务增益 <1pp。"架构决策"本质上属于后者——需要权衡、对比、综合判断，**不是符号推理**。所以"为架构任务加 CoT"理论上增益有限。

### 作者的 "按以下顺序分析：1. X 2. Y 3. Z" 手法属于哪种 CoT？

这属于 **guided CoT**（官方文档的中间级写法），比"let's think step by step"更强约束。相对关系：

- **基础 zero-shot CoT**（"think step by step"）：最轻，靠词触发推理模式
- **guided CoT**（作者手法）：指定**推理维度**——"先考虑 X，再考虑 Y，最后考虑 Z"
- **structured CoT**（XML 标签）：分离思考区与答案区

在**旧模型（GPT-3.5、Claude 2）**上，guided CoT 确实更强，因为它帮助模型定位分析框架。但在**现代强模型（Claude 4.x）**上，模型已经学会自发建立分析框架，人为指定顺序反而会：
1. 限制模型的自由度（跳过模型本应考虑的维度）
2. 引入作者自己的偏见（如果作者列的顺序是错的）
3. 在 adaptive thinking 下造成冗余——模型内部已经在做类似的事

但这不意味着 guided CoT 一无是处。当任务有**明确的领域框架**（如"ADR 模板：Context → Decision → Consequences"），给出结构约束仍然有助于**输出格式稳定性**，只是此时它的作用是"规范输出模板"，不是"激活推理"。

### Claude 自带 extended thinking 后，prompt 级 CoT 触发器是否冗余？

**接近冗余，但不完全**。分三种场景：

1. **extended/adaptive thinking 开启（Claude 4.5+）**：prompt 级 CoT 基本冗余。模型内部已经在做更深入、更完整的推理，人为注入步骤反而可能干扰。Anthropic 官方建议："prefer general instructions over prescriptive steps"。

2. **extended thinking 关闭 / 旧模型**：prompt 级 CoT 仍有价值。Anthropic 自己把它定位为 "Manual CoT as a fallback when thinking is off"。

3. **Claude Code / Cursor 等产品**：多数产品**没开启** extended thinking（成本/延迟考虑），所以在这些环境里 guided CoT 仍有效。这是作者博文可能成立的最大场景。

### 时效性修正

作者的建议如果成文于 2023-2024，那时 Claude 3、GPT-4 还没有大规模推理能力，guided CoT 确实有增益。到 2026 年 4 月（当前），Claude Opus 4.7 的 adaptive thinking 已经把"什么时候需要推理、推到多深"内化为模型决策。此时再往 prompt 里塞"按以下顺序分析"，最好的情况是无增益，最差情况是：
- 触发过度思考（Wharton 报告的"overthinking cost"）
- 限制模型考虑作者没列出的维度
- 在简单架构问题上引入错误（Liu 2024 的发现）

---

## 一句话结论

作者的 guided CoT 手法在旧模型和关闭 thinking 的场景下仍有效，但在现代 Claude（Opus 4.6/4.7 + 默认 adaptive thinking）上已被官方建议取代为"高层次指令 + 让模型自主决定推理深度"；对架构决策这种**非符号推理**任务，CoT 触发器本来增益就有限，"输出质量远高于直接问"的说法在 2026 年的强模型环境下属于过时经验。
