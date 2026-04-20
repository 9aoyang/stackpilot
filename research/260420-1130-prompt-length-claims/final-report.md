# 《Claude Code Prompt 长度实测：我删掉 80% 的字，输出反而更好》观点合理性核查

> 调研日期：2026-04-20
> 原文：https://mp.weixin.qq.com/s/atdZzRfbG4NJcfWDNU7d4w
> 方法：6 个并行子 Agent，覆盖 Anthropic 官方文档、一手学术论文、社区实践、反对声音四类来源，共收集 70+ 条带 URL 的独立证据。

## 逐论断裁决表

| 编号 | 论断 | 裁决 | 核心依据 |
|---|---|---|---|
| **C1** | Prompt 长度与输出质量相关性弱，有效信息密度才是强相关 | ✅ **支持** | Anthropic 官方"smallest set of high-signal tokens / context rot / attention budget"（effective-context-engineering blog）、Karpathy 的 context engineering 定义、Lost-in-the-Middle、GSM-IC、Context Length Alone Hurts 三篇一手论文共同支撑 |
| **C2** | 背景故事/推理过程/重复确认/礼貌用语全是零贡献噪音 | ⚠️ **部分支持** | 礼貌用语和重复确认确实影响小（两篇矛盾的实证论文均未显示强效应）；但"推理过程 = 零贡献"在 CoT 原始论文（+30~40pp）面前不成立；Anthropic 官方模板把 audience 和 few-shot examples 列为核心技巧，超出作者的"三分法"；文章把"低效冗余"和"真正稀释信号"混为一谈 |
| **C3** | 单点 20-40 字 / 功能 80-150 / 模块 150-250 / 架构 100-180 的四档字数表 | ❌ **存疑至反驳** | 分档方向性（简单→短、复杂→长）成立，但官方、学术、社区无任何来源给出过类似字数带；最接近的 mediatech 三档是英文 words，数量级不匹配；arXiv 2502.14255 实证显示连简单任务加长 prompt 也有 +0.07 F1 增益，反驳"上限"假设；四档纯属作者主观锚点 |
| **C4** | "不需要什么"约束比"需要什么"更重要 | ⚠️ **部分支持** | 前提成立——LLM 会 over-engineer（Anthropic 官方承认 Opus 4.5/4.6 该倾向；FeatBench 73.6% regression 实证）。但"负向 > 正向"被 Anthropic 官方第一原则直接反驳："Tell Claude what to do instead of what not to do"；Gadlet 可复现对照显示"always lowercase"优于"don't uppercase"；Cursor 实战显示模糊的全局负向约束会让模型拒绝合理任务；作者的经验实际只适用于"over-engineering 边界"这个特定场景 |
| **C5** | 约束不超过 5 条，超过后半段执行率被稀释 | ⚠️ **方向对、数字无据** | "约束↑→遵守率↓"有 IFScale、Curse of Instructions、FollowBench、ComplexBench 四项实证支持；但下降是连续曲线，不是"第 5 条断崖"：Claude Sonnet 4 在 100 条指令仍保持 94.4% 准确率。Curse of Instructions 的指数衰减公式推导出"5-7 条 ≈ 80% 可靠度"——这是"5 条"唯一能攀上的学术依据；作者的"8 条只执行 4"更可能是总完成率指数衰减，而非注意力稀释 |
| **C6** | 位置越靠前，注意力权重越高 | ❌ **现象对、解释错** | 三个不同机制被作者混成单调递减模型：① Attention sink（首 token 吸走 attention，但与语义无关）、② Primacy effect（是输出选择偏差，不是 attention 权重偏差）、③ Lost in the Middle（实际是 **U 形曲线：首尾都高、中间低**）。作者只记住了"前面"这半边，漏掉 recency；"注意力权重"一词被误用 |
| **C7** | 项目背景放 CLAUDE.md，Prompt 不再写背景 | ⚠️ **部分支持** | C7a（项目通用背景持久化到 CLAUDE.md）被 Claude Code 官方 memory 文档直接定义："你本来要重复解释的东西"。但 C7b（Prompt 里绝不写背景）过度简化：官方同一份 best-practices 同时强调 "Provide specific context in your prompts"；Claude Code 自身会在 prompt 首尾刻意重复关键约束（U 型注意力设计）；CLAUDE.md 也有 bloat/stale/重复注入 Bug 等已知陷阱 |
| **C8** | 架构决策需要 CoT 推理触发器（"按以下顺序分析：1…2…3…"） | ❌ **过时** | Sprague 2024 元分析：CoT 增益主要来自数学/符号推理（GSM8K +66.9pp），commonsense/reading 类任务 < 1pp，架构决策属于后者；Anthropic Opus 4.7 官方建议："prefer general instructions over prescriptive steps"——直接反驳 guided CoT 手法；Liu 2024 + Wharton 2025 证明 CoT 会在简单题上引入错误，o1-preview 上最多下降 36.3pp；Claude 4.x 自带 adaptive thinking 已让 prompt 级 CoT 冗余 |

**裁决分布**：1 条完全支持、4 条部分支持、3 条反驳或过时。

---

## 总评

这篇文章的**核心直觉正确**——Prompt 的质量由高信号 token 比例决定、LLM 会 over-engineer、长约束列表后段执行率会下降——这些都与 Anthropic 官方立场和多篇一手学术研究的结论同向。作者显然对 Claude Code 有真实使用经验，把这些经验以"能上手"的方式归纳成了一套规则。

但**从"直觉→规则"的过程中反复出现过度泛化与机制混淆**，把"在我的使用场景里有用的启发式"包装成了"Claude Code 的运作规律"，这是文章最大的质量瑕疵：

1. **把"低效冗余"混同于"稀释信号"**（C2）。礼貌用语几乎没影响却被指控成"稀释约束"；CoT/示例被一刀切为噪音，但它们在实证中带来显著增益。
2. **把个人锚点包装为客观规律**（C3、C5）。四档字数、"5 条约束上限"都是基于"非正式自测"的主观数字，没有任何一手来源给出类似参数；呈现方式却像硬性阈值。
3. **机制描述错误**（C6、C8）。"位置靠前权重高"漏掉了 recency，把 U 形曲线讲成了单调递减；"架构决策加 CoT 触发器"在 Claude 4.x + adaptive thinking 时代已被官方明确反对。
4. **强断言过度简化职责分离**（C7）。"Prompt 里不要写背景"与官方"Provide specific context"自相矛盾；忽略了 CLAUDE.md 自身的 bloat/stale 陷阱。
5. **时效性**（C8 尤为明显）。文章用的很多直觉更适合 Claude 3 / GPT-4 时代；Claude 4.6/4.7 自带 adaptive thinking 之后，prompt 级推理脚手架的价值在系统性下降。

---

## 可操作改写建议

如果把文章的核心建议修订成不会误导的版本，应该是：

- **C1/C2 → 保留方向，收敛范围**：prompt 质量取决于信号密度而非长度；但"信号"包括模型不知道的事实、与任务相关的示例、输出受众和格式、必要的推理脚手架，**不只是"任务+约束+期望结果"三类**。真正该删的是"用户自我解释"（我为什么、我想过哪些方案），而不是示例和结构。
- **C3 → 改成方向性而非字数**：简单任务用简短明确的指令，复杂任务需要更多上下文与约束；**不给具体字数带**，让读者根据任务反馈自行校准。
- **C4 → 限定场景**：对"模型会自作主张加 retry/cache/helper"这个特定现象，用**具体的作用域边界**（"本次任务不需要 X/Y/Z"）是有效的；但通用指令仍应优先用正向替代方案。
- **C5/C6 → 澄清机制**：约束越多，全部遵守的联合概率越低（成功率指数衰减），不是"第 5 条之后被稀释"；关键约束放在 prompt **首部或尾部**都比塞中间好，不是"越前越好"。
- **C7 → 加上边界**：通用项目背景（命令、约定、架构、硬约束）放 CLAUDE.md；任务特定的文件引用、具体约束、关键注意事项仍应写进 prompt；CLAUDE.md 本身要保持 <200 行以防 bloat。
- **C8 → 时效性声明**：Claude 4.6/4.7 已内置 adaptive thinking，对架构决策类任务**不需要 guided CoT**；直接描述问题、让模型自主推理更稳定；Claude 3 / 旧模型或 thinking 关闭时才考虑"按以下顺序分析"。

---

## 总体定位

| 维度 | 评价 |
|------|------|
| 问题意识 | ⭐⭐⭐⭐ 指出的问题（prompt 冗余、模型 over-engineer、约束过多）都真实存在 |
| 方向感 | ⭐⭐⭐⭐ 主张"信号密度 > 长度"符合主流共识 |
| 证据质量 | ⭐⭐ 全文基于"非正式自测"，无对照实验、无引用 |
| 机制理解 | ⭐⭐ 多处把不同机制混为一谈（attention/primacy/dilution） |
| 时效性 | ⭐⭐ 大量建议更适合 2023-2024 年的模型，在 Claude 4.x + adaptive thinking 时代已部分过时 |
| 实操价值 | ⭐⭐⭐ 作为启发式入门材料可用，但每条具体规则都需要读者自己验证、不能直接奉为准则 |

**一句话总结**：这是一篇"方向对、姿势半错、证据薄弱"的经验贴——把它当作"让你意识到 prompt 应该更聚焦"的推动力是合适的，但把具体规则（字数带、约束条数、位置权重、CoT 触发器）当作 Claude Code 的客观规律，会引导读者做出错误的 prompt 决策。

---

## 证据明细文件

- [C1+C2 长度 vs 信息密度](./c1-c2-length-vs-density.md)
- [C3 任务-长度分档](./c3-task-length-tiers.md)
- [C4 负向约束价值](./c4-negative-constraints.md)
- [C5+C6 约束数量与位置](./c5-c6-constraint-count-position.md)
- [C7 CLAUDE.md 职责分离](./c7-claude-md-separation.md)
- [C8 CoT 推理触发器](./c8-cot-trigger.md)
