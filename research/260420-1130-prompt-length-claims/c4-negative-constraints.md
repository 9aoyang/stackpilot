# C4: "不需要什么"约束

## 裁决
**部分支持（论断有方向性正确，但"更重要"是过度简化；正确表述应为"抑制 over-engineering 时，显式边界指令确实必要，但应优先用'替代方案'式正向框架，而非'不要'式否定指令"）**

## 子论断拆解

### 论断 A：LLM 会"自作主张"加额外功能（over-engineering） —— **强支持**
- Anthropic 官方在 Claude Opus 4.7 prompting guide 中明确承认："Claude Opus 4.5 和 Claude Opus 4.6 有 overengineer 的倾向，会创建多余文件、添加不必要的抽象、构建未被要求的灵活性。"
- FeatBench 2025（arxiv 2509.22237）实证：122 个 LLM coding agent 失败案例中 **73.6% 来自"regressive implementation"**，agents 主动进行"scope creep"，在未明确要求的情况下重构代码或扩展功能。
- Anthropic 官方 prompting guide 专门有一节 "Avoid over-engineering"，明确列出四类典型失控行为：Scope（额外功能）、Documentation（额外注释/类型标注）、Defensive coding（未必要的 error handling / fallback / validation）、Abstractions（一次性操作的 helper）——这和原博文举的 "retry / cache / rate limiting" 是同一类问题。

### 论断 B：显式负向约束能有效抑制 —— **部分支持 / 有警告**
- 有效：Anthropic 官方自己的 "Avoid over-engineering" 示例 prompt 就是一连串 "Don't add...": *"Don't add features, refactor code... Don't add docstrings, comments... Don't add error handling... Don't create helpers..."*——这是来自模型厂商自己对"有效抑制 over-engineering"的答案。
- 但有副作用：Cursor 工程团队实战记录，当他们在 Codex harness 里写"should take care to preserve tokens and not be wasteful"，模型变得过度保守，直接对用户任务说："我不应该浪费 token，我觉得不值得继续这个任务！"——负向指令会让模型放弃合理的任务。
- 学术证据：GPT-3/InstructGPT 在 NeQA 这类负向指令 benchmark 上"随模型规模越大表现反而更差"（inverse scaling）。Truong 等 (2023) 《Language models are not naysayers》系统化证明 LLM 对 negation 有三个稳定失败模式：insensitivity to negation、无法理解 negation 的词义、在 negation 下推理崩溃。

### 论断 C：负向约束比正向约束"更重要" —— **反驳**
- Anthropic 官方 Be Clear and Direct 章节的第一条黄金法则就是："**Tell Claude what to do instead of what not to do**"，并给出对照示例：
  - ✗ "Do not use markdown in your response"
  - ✓ "Your response should be composed of smoothly flowing prose paragraphs."
- Anthropic Opus 4.7 prompting guide 原文："**Positive examples showing how Claude can communicate with the appropriate level of concision tend to be more effective than negative examples or instructions that tell the model what not to do.**"
- Claude Code 官方 best practices："Avoid negative-only constraints like 'Never use the --foo-bar flag' because the agent will get stuck... **Always provide an alternative instead.**"
- 独立博客 Gadlet 给出可复现对照："don't uppercase names" 频繁失败，而 "always lowercase names" 稳定生效。
- 机理解释（多来源一致）：token generation 本质上是"选出概率高的下一个 token"，"不要 X"仍需在 context 中激活 X 的表征；正向指令提供可直接采样的目标分布。

## 证据

### Anthropic 官方
1. **Claude Prompting Best Practices（Opus 4.7 版）** — 同一份文档里同时出现两个看似矛盾的指导：(a) 明确反对负向指令："Positive examples... tend to be more effective than negative examples or instructions that tell the model what not to do."；(b) 在 "Avoid over-engineering" 小节却用一连串 "Don't add..." 来限制范围、文档、防御编码和抽象。这说明负向指令不是被禁止，而是 "短负向标语" 被反对，"具体列举不要做的实际事项（scope boundary）" 被保留。  
   https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

2. **Anthropic Be Clear and Direct（旧版 docs）** — "Tell Claude what to do instead of what not to do" 列为第一条技巧，配对照示例。  
   https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/be-clear-and-direct（已重定向至 platform.claude.com）

3. **Claude Code Best Practices** — "Avoid negative-only constraints... Always provide an alternative instead"，同时承认 "Claude Opus 4.5 和 4.6 有 overengineer 的倾向"，建议 "add specific guidance to keep solutions minimal"。  
   https://code.claude.com/docs/en/best-practices

### 学术研究
4. **Truong 等 (2023) "Language models are not naysayers"（arxiv 2306.08189）** — 在 GPT-3 / GPT-Neo / InstructGPT 多规模对 9 种 negation benchmark 测试，得出三大结论：insensitivity to negation、lexical semantics 失败、negation reasoning 失败。特别发现 InstructGPT 随规模增大在含负向指令的任务上表现下降（inverse scaling）。  
   https://arxiv.org/abs/2306.08189

5. **"Negation: A Pink Elephant in LLMs' Room?"（arxiv 2503.22395, 2025）** — Llama 3 (3B/8B/70B)、Qwen 2.5、Mistral 多尺寸测试。最大模型在含否定的文本蕴含任务上达到 80-95%，小模型 50-70%。结论是 **scale 确实改善 negation 处理，但未完全解决**；相同模型在 affirmative 版本上仍显著更好。  
   https://arxiv.org/abs/2503.22395

6. **FeatBench（arxiv 2509.22237, 2025）** — 122 个失败样本中 73.6% 是 "regressive implementation"，作者将其归因于 "aggressive implementation / scope creep"：agents 会主动超出用户意图去重构和扩展。原文称需要 "mechanisms to control the agent's level of aggressive implementation"。  
   https://arxiv.org/abs/2509.22237

7. **MIT News (2025) "Vision-language models can't handle queries with negation words"** — 非代码但同源现象，系统性显示 VLM 对 "no / not" 的处理显著差于对正向查询。  
   https://news.mit.edu/2025/study-shows-vision-language-models-cant-handle-negation-words-queries-0514

### 社区实践
8. **Cursor Engineering Blog "Improving Cursor's agent for OpenAI Codex models"** — 实战一手证据：系统提示中加入"preserve tokens, not be wasteful"这类负向约束，导致 Codex 拒绝合理任务（"I'm not supposed to waste tokens, I don't think it's worth continuing"）。结论：负向系统指令会在"与用户意图冲突时覆盖用户"。  
   https://cursor.com/blog/codex-model-harness

9. **Shrivu Shankar "How I Use Every Claude Code Feature"** — 高活跃 Claude Code 用户的公开经验：明确主张 CLAUDE.md 不要使用"Never... / Don't..."这类只说禁止、不给替代的规则。原因同 Anthropic 官方：agent 会在"以为必须"时卡住。  
   https://blog.sshh.io/p/how-i-use-every-claude-code-feature

10. **Gadlet "Why Positive Prompts Outperform Negative Ones"** — 可复现实测：
    - "don't uppercase names" 频繁失败 vs "always lowercase names" 稳定成功
    - "don't include fields that have no value" 失败 vs "only include fields that have a value" 成功  
   https://gadlet.com/posts/negative-prompting/

11. **HumanLayer "Writing a good CLAUDE.md"** — 强调 CLAUDE.md 应是"通用正向规则"而非"hotfix 列表"。隐含观点：用"不要 X"来补救单次失败是反模式。  
   https://www.humanlayer.dev/blog/writing-a-good-claude-md

### 反对声音 / 边界条件
12. **Anthropic 官方自己的 "Avoid over-engineering" 模板** —— 上面已列出，是**唯一明确推荐使用一连串 "Don't" 指令**的官方场景。说明对 over-engineering 这个特定问题，Anthropic 自己承认正向表述不足以约束（"don't add retry / cache / helper" 这类具体边界比泛泛说 "be minimal" 更有效）。

13. **Swimm.io "Understanding LLMs and Negation"** — 明确指出 token-level 机理："negation tokens ('not') have a limited effect on the representations learned distributionally"——即使模型读到 "not"，它对隐层表征的影响非常有限，这是正向框架胜出的底层原因。  
   https://swimm.io/blog/understanding-llms-and-negation

## 分析

### 原博文说的"省掉它自作主张加的 retry / cache / rate limiting"在实证上成立
- FeatBench 73.6% regression、Anthropic 官方承认 Opus 4.5/4.6 的 overengineering 倾向、官方 prompting guide 专门开辟 "Avoid over-engineering" 小节——三条独立来源互证：LLM coding agent 确实会"自作主张"添加用户未要求的防御编码、abstraction、helper。
- 博主举的三个例子（retry、cache、rate limiting）恰好全部落在 Anthropic 官方示例的 "Defensive coding" 类别里，属于教科书式的真实问题。

### 但"负向比正向更重要"是过度简化
真正准确的表述应当分层：

| 场景 | 正向指令 | 负向指令 | 证据 |
|------|----------|----------|------|
| 格式控制（markdown、list、preamble） | **显著更优** | 差 | Anthropic 官方明确示例 |
| 短情绪性约束（"be concise" / "don't be verbose"） | **显著更优**（给具体数字） | 差 | Anthropic 官方 |
| 作用域边界（"不要加 retry"） | 难以正向表述 | **官方自己用这种写法** | Avoid over-engineering 模板 |
| 系统级全局约束（"不要浪费 token"） | 好 | **会导致模型拒绝任务** | Cursor 实战反例 |

### 机理上的精确表述
- LLM 对 negation 的处理能力确实随 scale 提升（Pink Elephant 论文），但 **"negation"（语义级否定推理）** 和 **"negative instruction"（写什么指令让模型别做 X）** 是两个不同问题。
- 对指令跟随而言，负向约束成功的前提是模型在 token 选择时能把 "不该出现的 token" 从分布中抑制掉。而 autoregressive 采样的本性是"选最可能的下一个 token"，没有显式的"避开 X"机制。因此好的负向指令需要让 **context 足够明确地铺出替代选择**——这就回到了"提供替代方案"这条官方建议。
- Cursor 的反例指向另一个风险：**模糊的负向系统指令**（"preserve tokens" 没说边界）会被模型解读为"全局偏好"，污染所有子任务的判断。这和 Anthropic 官方 "Don't add error handling for scenarios that can't happen"（**具体且作用域限定**的负向）有本质差别。

### 原博文的真正价值和偏差
- **正确部分**：指出 "LLM 会加它觉得该有的东西" 这一 over-engineering 现象真实存在，用"不要 X"的显式边界是必要手段；Anthropic 官方自己在 "Avoid over-engineering" 小节也这么写。
- **偏差部分**：说"负向比正向更重要"过度强化。实际官方立场是**负向指令是必要的最后一道栅栏，但首选仍是正向替代方案**。博主的经验很可能来自这一特定场景（over-engineering 边界）的成功，被过度泛化成了通用原则。
- **更完整的表述**应该是："告诉 Claude **边界在哪里**（具体到哪些功能不在本次任务范围内）比只给正向需求更重要；但这个边界最好以'替代方案'而非'纯禁止'的形式表达。"

## 一句话结论
"LLM 会自作主张加功能" 有强实证支持（Anthropic 官方承认 + FeatBench 73.6% 数据），但 "显式负向约束比正向更重要" 是过度简化——Anthropic 官方第一原则仍是"告诉 Claude 做什么而不是不做什么"，仅在 over-engineering 边界这一特定场景下，具体列举 "Don't add X" 才被官方自己采用；而对 LLM 处理否定指令的能力，学术证据显示模型规模越大能力越强但远未解决（80-95% vs 50-70%），Cursor 实战则证明模糊的全局负向约束会让模型拒绝合理任务。
