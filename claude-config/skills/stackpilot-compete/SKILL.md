---
name: stackpilot-compete
description: Competitive gap analysis from the perspective of a heavy user of a competing product. Identifies what would make users switch and never go back. Use when asked to analyze competitive positioning, find product gaps, or generate improvement specs.
---

# Competitive Gap Analysis

Assume the persona of a **power user of the specified competing product** who is evaluating whether to switch to this project. Your goal: identify what would make you switch AND never go back.

## Step 1: Identify the Competitor

Ask the user (skip if already specified):

> What competing product should I analyze against? Examples:
> - **Claude Code** (raw, no framework)
> - **Cursor**
> - **Devin**
> - **Bolt / Lovable** (web-based AI builders)
> - **Aider**
> - **GitHub Copilot Workspace**
> - Or specify any product

If the user says "all" or doesn't specify, auto-select the top 3 competitors based on project type:
- CLI tool → Claude Code (raw), Aider, Cursor
- Web app → Devin, Bolt, Cursor
- Framework/library → Claude Code (raw), Copilot Workspace, Cursor

## Step 2: Deep Scan (mandatory, do not skip)

Read ALL of the following before any analysis:

```bash
# Project identity
cat README.md 2>/dev/null
cat CLAUDE.md 2>/dev/null
cat docs/architecture.md 2>/dev/null

# All agent definitions
for f in claude-config/agents/sp-*.md; do echo "=== $f ==="; cat "$f"; done

# All skill definitions
for d in claude-config/skills/stackpilot*/; do for f in "$d"*.md; do echo "=== $f ==="; cat "$f"; done; done

# Configuration
cat stackpilot.config.yml 2>/dev/null || cat templates/stackpilot.config.yml 2>/dev/null

# Scripts and hooks
for f in scripts/init.sh scripts/lib/config.sh; do echo "=== $f ==="; cat "$f" 2>/dev/null; done

# State layer
ls .stackpilot/ 2>/dev/null
ls -t .stackpilot/plans/*.md 2>/dev/null | head -3
ls -t .stackpilot/specs/*.md 2>/dev/null | head -3
cat .stackpilot/NEEDS_REVIEW.md 2>/dev/null

# External refs
cat docs/sync.md 2>/dev/null

# Recent git activity
git log --oneline -20
```

## Step 3: Dimension-Based Competitive Exploration (iterative)

For EACH competitor, explore gaps through **competitive dimensions** — not a fixed checklist. Each iteration picks one unexplored dimension, generates a concrete gap insight, classifies it, and logs the result.

**Competitive Exploration Dimensions:**

| Dimension | Exploration Focus |
|-----------|-------------------|
| **Daily workflow** | What do I do 10+ times/day? Where does friction hide? |
| **Muscle memory** | Keyboard shortcuts, commands, habits I'd lose by switching |
| **Onboarding** | First 5 minutes experience. How fast to first value? |
| **Error recovery** | What happens when things break? How does the tool help me fix it? |
| **Scale** | How does the tool handle large projects, big teams, massive codebases? |
| **Integration** | Ecosystem fit — IDE, CI/CD, git, team tools, external services |
| **Customization** | Can I bend it to my workflow? Plugins, config, hooks, extensions |
| **Performance** | Speed of response, latency, resource consumption |
| **Collaboration** | Multi-user, team workflows, sharing, review processes |
| **Data & State** | Context retention, history, session persistence, project memory |
| **Edge cases** | What weird situations does the competitor handle that this tool doesn't? |
| **Emotional** | Joy, trust, confidence — intangible factors that create loyalty |

**Iteration loop** (run 10–20 iterations per competitor, adapt based on diminishing returns):

1. **Pick** the highest-priority unexplored dimension (or combine 2 dimensions for deeper insight)
2. **Generate** a concrete gap insight — must include: specific scenario, what the competitor does, what this project does (or lacks), severity rating
3. **Classify**: `new` / `variant` / `duplicate` / `low-value` — deduplicate against all prior insights
4. **Expand**: for each KEPT insight, derive 1–2 edge cases or what-ifs ("what if the user has 50 files open?", "what if the team has 10 people?")
5. **Log** to `.stackpilot/compete-insights.tsv`:
   ```tsv
   iteration	competitor	dimension	classification	severity	title	gap_description
   1	Cursor	daily_workflow	new	instant-close	Tab completion context	Cursor uses full-file context for tab completion; stackpilot has no equivalent
   ```
6. **Repeat** — pick next unexplored dimension or combination

**Stuck detection**: if 3 consecutive iterations produce `duplicate` or `low-value` → switch competitor or stop.

**Every 5 iterations, print progress:**
```
=== Competitive Exploration (iteration 10) ===
Insights generated: 8 (6 new, 1 variant, 1 duplicate)
Dimensions covered: 6/12 (50%)
Severity: 2 instant-close, 3 week-1, 3 gradual-drift
Coverage gaps: collaboration, scale, emotional — unexplored
```

## Step 4: Multi-Persona Competitive Analysis (with debate)

After iterative exploration, analyze ALL gathered insights through **multiple expert perspectives** that independently evaluate and debate.

**Competitive Analysis Personas:**

| Persona | Focus | Bias Direction |
|---------|-------|----------------|
| **Power User** | Daily workflow friction, muscle memory, deal-breakers | "I've used [competitor] for 2 years — convince me to switch" |
| **Product Strategist** | Market positioning, moat sustainability, flywheel effects | "Which gaps compound over time? Which are one-time fixes?" |
| **DevEx Engineer** | API design, extensibility, integration architecture | "How hard is it to close each gap technically?" |
| **Community Builder** | Ecosystem, docs, community, adoption curve | "What makes users evangelize vs quietly leave?" |
| **Devil's Advocate** | Challenges consensus, surfaces blind spots | MUST challenge ≥50% of majority positions; MUST question at least one "obvious" gap |

**Analysis flow:**

1. **Independent analysis** — each persona reviews all gathered insights from Step 3 and produces their top findings (max 8 per persona)
2. **Structured debate** (1 round) — each persona sees others' findings, challenges disagreements, revises positions
3. **Consensus** — findings that ≥3 personas confirm become "Confirmed"; 2 = "Probable"; 1 = "Minority" (preserve all minority findings)
4. **Anti-herd check** — if all personas agree on everything, Devil's Advocate MUST inject at least one contrarian position

**Output the analysis in this structure:**

---

### Competitive Analysis: [Project Name] vs [Competitor(s)]

#### Moat (things competitors cannot easily replicate)

| Capability | Why competitors can't match this | Consensus |
|-----------|--------------------------------|-----------|
| ... | ... | Confirmed / Probable / Minority |

#### Migration Blockers (things that would make me go back to the competitor)

For each blocker, rate severity:
- **Instant close** — I try the tool, hit this, and uninstall
- **Week-1 churn** — I tolerate it initially but leave within a week
- **Gradual drift** — I slowly drift back to the competitor over a month

| Blocker | Severity | What the competitor does instead | Consensus |
|---------|----------|--------------------------------|-----------|
| ... | ... | ... | Confirmed / Probable / Minority |

#### Addiction Features (things that would make me unable to go back)

These are the "flywheel" features — the more you use it, the harder it is to leave.

| Feature | Current State | Gap | Flywheel Effect | Consensus |
|---------|--------------|-----|-----------------|-----------|
| ... | missing / partial / exists | what's needed | why it compounds over time | Confirmed / Probable / Minority |

#### Prioritized Improvements

Rank ALL confirmed/probable gaps by: `priority_score = severity × consensus_ratio × feasibility / effort`

| Priority | Improvement | Impact | Effort | Why now | Consensus |
|----------|------------|--------|--------|---------|-----------|
| P0 | ... | ... | ... | ... | ... |
| P1 | ... | ... | ... | ... | ... |
| P2 | ... | ... | ... | ... | ... |

#### Devil's Advocate Dissent

List contrarian positions the Devil's Advocate raised that were NOT adopted by majority. These are often the most valuable insights — gaps that seem unimportant but matter to specific user segments.

| Dissent | Why majority dismissed | Why it might matter |
|---------|----------------------|---------------------|
| ... | ... | ... |

---

## Step 5: Generate Specs (optional)

Ask the user:

> I've identified [N] improvements. Want me to generate spec drafts for the P0 items?
> - **A**: Generate specs for P0 items → `.stackpilot/specs/`
> - **B**: Generate specs for P0 + P1 items
> - **C**: Just the analysis, I'll decide what to build

If A or B:
- Write each spec to `.stackpilot/specs/compete-<short-name>.md`
- Follow the standard spec format (Overview, Goals, Out of Scope, Technical Requirements, Acceptance Criteria)
- Each spec should be self-contained and actionable
- After writing, prompt: "Commit these specs to trigger the sprint pipeline? (y/n)"

## Step 6: Track for Re-run

Append analysis metadata to `.stackpilot/compete-log.md` (create if not exists):

```markdown
## [DATE] — vs [Competitor(s)]

- Moat items: [N]
- Migration blockers: [N] (instant-close: [N], week-1: [N], gradual: [N])
- P0 gaps: [list]
- Specs generated: [list or "none"]
```

This enables periodic re-runs: `/stackpilot-compete` → see what's changed since last analysis.

---

## Constraints

- **No hallucinated competitor features**: If you're unsure whether a competitor has a specific feature, say "unverified" and suggest the user confirm.
- **Read before judging**: Never assess a capability without reading the actual implementation. "I think it does X" is not acceptable — grep for it.
- **Persona fidelity**: Stay in character as a power user, not a product manager writing a report. Use language like "I would immediately miss...", "The thing that keeps me on [competitor] is...", "After a week without [feature], I'd go back because...".
- **Actionable over comprehensive**: 5 sharp insights beat 20 vague observations.
