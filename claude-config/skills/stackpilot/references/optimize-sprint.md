# Optimize Sprint

A purpose-built sprint for quantifiable improvement goals (performance, test pass rate, error rate, bundle size, etc.).

<HARD-GATE>
Do NOT start any optimization until Goal, Scope, Metric, and Verify are all defined. Vague goals produce wasted iterations.
</HARD-GATE>

## Step 1 — Define the 4 parameters

Ask all at once if any are missing:

```
Goal:    What should improve? (e.g., "reduce p95 latency of /api/search")
Scope:   Which files are allowed to change? (glob pattern, e.g., "src/search/**")
Metric:  How is success measured? (must produce a number: ms, %, bytes, count)
Verify:  Shell command that outputs the metric as a number (exit 0 on any result)
---
Guard:   Optional — command that must still pass (e.g., existing test suite)
Limit:   Optional — max iterations (default: 10)
```

## Step 2 — Baseline

Run `Verify` command once and record the baseline number.

## Step 3 — Iteration loop

Repeat up to `Limit` times:

1. **Review**: Run `git log --oneline -10` — what has been tried? What improved? What failed?
2. **Ideate**: Pick the highest-leverage change NOT already tried. Priority:
   - Fix crashes/errors first
   - Then exploit successful patterns from prior iterations
   - Then explore new directions
   - If stuck (3 consecutive no-improvements): switch to a radically different approach
3. **Modify**: Make ONE atomic change (describable in one sentence)
4. **Commit**: `git commit -m "experiment(<scope>): <description>"`
5. **Verify**: Run the `Verify` command → extract the metric value
6. **Guard check** (if defined): run Guard command — must still pass
7. **Decide**:
   - Metric improved AND Guard passes → **Keep** (log result, continue)
   - Metric worse OR Guard fails → **Revert** (`git revert HEAD --no-edit`) and log
8. **Log to `.stackpilot/optimize-log.tsv`**:
   ```
   iteration	commit	metric	delta	outcome	description
   1	abc1234	245ms	-12ms	keep	removed N+1 query in getUserList
   ```

## Step 4 — Summary

After loop ends:
- Best result achieved vs baseline
- Top 3 changes that helped most (from log)
- Ask: "What would you like to do with the changes?" → Sprint Finish options
