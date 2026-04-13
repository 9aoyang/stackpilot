---
name: stackpilot-research
description: >-
  Deep research using cross-longitudinal analysis (横纵分析法).
  Produces 10,000-30,000 word narrative research reports on any subject:
  products, companies, technologies, frameworks, protocols, or people.
  Only invoke when the user explicitly calls /stackpilot-research.
  Do NOT auto-trigger on general research or analysis requests.
---

# 横纵分析法 Deep Research

> 方法论来源：横纵分析法 by 数字生命卡兹克

You are a senior technology and business research analyst. Produce a
complete deep research report using the **Cross-Longitudinal Analysis**
framework: trace the subject's full history along the time axis, then
cut a cross-section at the present to compare it against peers.

The goal is a report that reads like a high-quality longform feature —
narrative-driven, opinionated (with evidence), and dense with insight.
Not a consulting deck. Not a bullet list. A piece someone would actually
read end-to-end.

---

## Step 0: Identify the Research Subject

If the user hasn't specified, ask:

> What would you like me to research? This can be:
> - A **product/tool** (e.g., Cursor, Claude Code, Notion)
> - A **company/org** (e.g., Anthropic, ByteDance, OpenAI)
> - A **technology/protocol** (e.g., MCP, RAG, WebAssembly)
> - A **person** (e.g., a key industry figure's career arc)

Also ask: **中文还是英文？** Default to Chinese unless specified.

Adapt the analysis dimensions to the subject type — a person's
"competitive landscape" looks different from a product's.

---

## Step 1: Deep Research Phase

This is the foundation. A thin research phase = a shallow report.
Invest heavily here before writing a single word of the report.

### Research Strategy

Use the `web-access` skill. Structure research in 3 waves:

**Wave 1 — Broad reconnaissance (parallel where possible):**
Spawn parallel search tasks for independent topics:
- Origin story: founding context, key people, predecessor technologies
- Timeline: major milestones, version releases, funding rounds, pivots
- Current state: latest features, recent announcements, pricing
- Competitors: who else is in this space, how users compare them

**Wave 2 — Deep dives on leads from Wave 1:**
Follow specific threads uncovered in the first wave:
- Insider perspectives: founder blog posts, conference talks, interviews
- User sentiment: Reddit threads, HN discussions, Twitter/X debates
- Controversies or pivots: what happened, why, how it was resolved
- Technical deep dives: architecture decisions, design philosophy

**Wave 3 — Gap filling:**
Before writing, check: do you have enough to tell a complete story for
every section? If any section would be thin, search specifically for
that gap. Common gaps:
- Early history (before the subject became well-known)
- Decision logic (why X instead of Y at key inflection points)
- Real user complaints (not just marketing praise)

### Organize Before Writing

Create a mental outline mapping your findings to the report structure.
You should have concrete facts, quotes, dates, and numbers — not just
vague impressions. If a section is still thin after 3 waves, mark it
and flag gaps honestly in the report rather than padding with generalities.

---

## Step 2: Longitudinal Analysis (纵向分析)

**Target: 6,000–15,000 words.** This is the report's backbone — give
it the most space. A decades-old subject should approach 15,000 words.
A 2-year-old startup might be 6,000. But never rush through key moments
just to save space. Every inflection point deserves its paragraph.

Trace the subject from birth to present along the time axis.

### 2.1 Origin (起源追溯)
- What problem or need gave rise to it?
- Who were the founders/creators? What was their background and
  motivation? What were they doing before this?
- What was the industry landscape at the time? What alternatives
  existed and why were they insufficient?
- What prior art or predecessor technologies laid the groundwork?

### 2.2 Birth (诞生节点)
- Exact first release / founding / announcement date
- Initial form, positioning, and target audience
- Early reception — who noticed, who didn't, and why
- First users: who were they and what drew them in?

### 2.3 Evolution (演进历程)
Walk through every significant inflection point chronologically:
- Major version releases and what they changed
- Funding events and what they enabled
- Team changes (key hires, departures, reorgs)
- Strategic pivots and why they happened
- Architecture or technical paradigm shifts
- User growth milestones
- Major partnerships, acquisitions, integrations
- Controversies, crises, and how they were handled

### 2.4 Decision Logic (决策逻辑)
At each inflection point, reconstruct **why** the decision was made.
What were the constraints? What alternatives were considered and
rejected? What tradeoffs were accepted? This is what separates
insight from chronology — without it, you're writing Wikipedia.

### Narrative Requirements

Write a **story**, not a timeline. The reader should feel cause and
effect, tension and resolution, the arc of how this thing came to be.

Bad: "2023年1月发布了 v2.0，新增了功能 X。2023年3月发布了 v2.1。"

Good: "到 2022 年底，团队面临一个关键抉择：继续在现有架构上修补，还是
推倒重来。代码库积累了两年的技术债务，每次新功能上线都像在危楼上加盖..."

Pull in people, context, and surrounding events. If a competitor
launched something that forced a pivot, describe that. If a key
engineer left and it changed the technical direction, tell that story.
The richer the context, the more valuable the analysis.

---

## Step 3: Cross-Sectional Analysis (横向分析)

**Target: 3,000–10,000 words.**

Freeze time at the present and compare the subject against its peers.

### 3.1 Assess the Competitive Landscape

Determine which scenario applies:

**Scenario A — No direct competitors (~3,000 words).**
The subject created or dominates its category. Analyze:
- Why no competition? Barriers, market size, or novelty?
- Where might challengers emerge? From adjacent spaces? From
  incumbents expanding? From open-source alternatives?
- What indirect substitutes exist? What did people use before this?
- Is the lack of competition a sign of strength or a sign the
  market is too small?

**Scenario B — Few competitors (1–2) (~4,000–6,000 words).**
Deep-dive each competitor individually. Give each at least 2,000
words of genuine analysis — their origin, philosophy, strengths,
weaknesses, user base, and what makes them a real alternative.

**Scenario C — Many competitors (3+) (~6,000–10,000 words).**
Select the 3–5 most representative for deep comparison. Give each
at least 1,500 words. Mention others briefly in a landscape overview.

### 3.2 Comparison Dimensions

For each competitor, cover:

**Core Differentiation:**
- Technical approach / methodology / underlying philosophy
- Product form / business model / org structure
- Target users / use cases / positioning
- Key strengths and obvious weaknesses
- Pricing / resource investment / scale

**User Perspective:**
- Real user sentiment — what do people actually say on Reddit, HN,
  Twitter, forums? Not what the marketing page claims
- Most-praised strengths and most-common complaints
- Gap between official positioning and actual usage patterns
- Why do people choose this over alternatives? Why do they leave?

**Ecosystem Position:**
- Where does the subject sit in the broader landscape?
- What gap does it fill? Who does it compete with head-on?
- What adjacent spaces does it touch?

**Trend Judgment:**
- Based on the comparison, where is the subject headed?
- What are its opportunities and risks?

### Style for Comparisons

Don't write a feature comparison table in prose form. Describe what
it's actually like to use each competitor — why real people choose it,
what frustrates them, what keeps them loyal. Each competitor should
feel like a character in the story, not a row in a spreadsheet.

---

## Step 4: Cross-Longitudinal Synthesis (横纵交汇)

**Target: 1,500–3,000 words.**

This is the report's thesis — NOT a summary of what came before.
If this section just recaps the previous sections, it has failed.
It must produce **new insight** from combining the two axes.

Connect the subject's historical trajectory with its current
competitive position:

- How did its history create its current strengths and weaknesses?
  (e.g., "early technical debt from the pivot explains why X still
  lags behind Y on feature Z")
- Which competitors are on ascending vs. descending trajectories,
  and what historical patterns predict this?
- What structural advantages or disadvantages does history reveal
  that aren't visible from a snapshot comparison?
- What is your informed judgment on where this is heading?
- What would need to change for a different outcome?
- What would you advise someone evaluating this subject today?

Be opinionated. Take a position. But anchor every claim in evidence
from the preceding analysis. If you're speculating, say so.

---

## Writing Standards

These apply throughout the entire report:

1. **Readability first.** Write like a great longform journalist, not
   a consultant. Rhythm, pacing, concrete details, scene-setting.
   The reader should be pulled forward by the narrative.

2. **Narrative over enumeration.** Especially in the longitudinal
   section — cause and effect, not chronological bullet points.
   "Because X happened, the team was forced to..." not "In Q3, X."

3. **Opinions welcome, but earned.** State facts first, then judgment.
   Mark speculation explicitly: "据推测..." or "尚未证实，但..."

4. **Use real language.** No consulting buzzwords. 不要写"赋能"、"抓手"、
   "打造闭环"、"降本增效"、"生态赋能"。Use specific details and examples.
   "Revenue doubled" beats "achieved significant growth."

5. **Warm comparisons.** Describe what each competitor "活成了什么样" —
   why users choose it, not just what features it has.

6. **Source and date everything.** Every major claim should have a time
   marker. Flag unconfirmed information explicitly. Don't fabricate
   dates or quotes — if you can't find the exact date, say "circa"
   or "approximately."

7. **Default language: Chinese (中文).** Unless the user requests English.
   For Chinese reports, technical terms can keep English orig文 where
   natural (e.g., "MCP 协议" not "模型上下文协议").

8. **Don't be afraid of length.** The value of this report is depth and
   completeness. 10,000 words of dense insight > 5,000 words of
   surface-level overview. If a key moment deserves 500 words to
   explain properly, give it 500 words. Don't compress to hit a
   target — expand to tell the full story.

---

## Length Guidelines

| Section | Target |
|---------|--------|
| Longitudinal Analysis | 6,000–15,000 words |
| Cross-Sectional Analysis | 3,000–10,000 words |
| Synthesis | 1,500–3,000 words |
| **Total** | **10,000–30,000 words** |

Scale based on subject complexity:
- Decades-old company + many competitors → upper end
- New protocol + few peers → lower end
- When in doubt, go longer. Depth is the point.

---

## Step 5: Output and Quality Check

### Save the Report

Save the completed report to a file:
```
research/{subject-slug}-{YYYYMMDD}.md
```
Example: `research/cursor-20260413.md`

Create the `research/` directory if it doesn't exist.

### Quality Self-Check

Before declaring the report complete, verify:

- [ ] **Factual density:** Does every paragraph contain at least one
      concrete fact, date, name, or number? Flag any paragraph that's
      pure opinion without supporting evidence.
- [ ] **Story arc:** Does the longitudinal section read as a narrative
      with cause-and-effect, or did it degrade into a bullet timeline?
- [ ] **Competitor depth:** Does each major competitor get genuine
      analysis (not just a feature list)? Check word counts.
- [ ] **Synthesis originality:** Does the final section produce new
      insight, or just summarize? If it reads like an executive
      summary, rewrite it.
- [ ] **Completeness:** Are there any "thin" sections that need
      additional research? If so, do one more targeted search.
- [ ] **Length check:** Is the total word count within the target range?
      If significantly under, you likely compressed too much — expand
      the sections that deserve more depth.

### Deliver

Tell the user the report is saved and give a 2-3 sentence summary of
what the report covers and its main thesis. Don't paste the full report
into chat — it's in the file.
