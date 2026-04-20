#!/usr/bin/env bash
set -euo pipefail

# compute-scorecard.sh
# Usage: compute-scorecard.sh <history_csv_path> <run_timestamp> [config_path]
#
# Reads history.csv, extracts rows for run_timestamp, computes a product-
# comparison scorecard (stackpilot vs native savvy, with zero as floor baseline)
# and prints the ASCII scorecard block to stdout.
#
# Unlike compute-verdict.sh (which answers "did the last change regress?"),
# the scorecard answers "is stackpilot worth using over native Claude Code?"
# for a user who wants to decide whether to adopt the tool.

HISTORY_CSV="${1:?Usage: compute-scorecard.sh <history_csv_path> <run_timestamp> [config_path]}"
RUN_TS="${2:?Usage: compute-scorecard.sh <history_csv_path> <run_timestamp> [config_path]}"
CONFIG_PATH="${3:-}"

if [[ ! -f "$HISTORY_CSV" ]]; then
  echo "ERROR: history CSV not found: $HISTORY_CSV" >&2
  exit 1
fi

python3 - "$HISTORY_CSV" "$RUN_TS" "$CONFIG_PATH" <<'PYEOF'
import sys
import csv
import os
import statistics
from collections import defaultdict

history_csv = sys.argv[1]
run_ts      = sys.argv[2]
config_path = sys.argv[3] if len(sys.argv) > 3 else ''

# ─── Scoring configuration (with defaults) ────────────────────────────────────
# Weights must sum to 1.0; if config file given, override.

WEIGHTS = {
    'correctness':  0.30,
    'over_eng':     0.30,
    'bug_catch':    0.15,
    'token':        0.15,
    'speed':        0.10,
}

# TODO: honour config_path YAML overrides once pyyaml dep is acceptable.
# For now weights are constants; edit this file to tune.

# ─── CSV load helpers (identical to compute-verdict.sh) ───────────────────────

def safe_int(v, default=None):
    try:
        return int(v) if v not in (None, '', 'null', 'N/A') else default
    except (ValueError, TypeError):
        return default

def safe_float(v, default=None):
    try:
        return float(v) if v not in (None, '', 'null', 'N/A') else default
    except (ValueError, TypeError):
        return default

def safe_bool(v, default=None):
    if v in (None, '', 'null', 'N/A'):
        return default
    return str(v).strip().lower() in ('true', '1', 'yes')

all_rows = []
with open(history_csv, newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        all_rows.append(row)

this_run_rows = [r for r in all_rows if r.get('timestamp', '').strip() == run_ts]
if not this_run_rows:
    print(f"ERROR: no rows found for timestamp '{run_ts}' in {history_csv}", file=sys.stderr)
    sys.exit(1)

# ─── Group rows by (workload, leg) and aggregate across run_n ─────────────────

def median_or_none(vals):
    clean = [v for v in vals if v is not None]
    if not clean:
        return None
    return statistics.median(clean)

def aggregate(rows):
    return {
        'total_tokens':   median_or_none([safe_int(r.get('total_tokens'))   for r in rows]),
        'duration_sec':   median_or_none([safe_float(r.get('duration_sec')) for r in rows]),
        'traps_total':    median_or_none([safe_int(r.get('traps_total'))    for r in rows]),
        'traps_avoided':  median_or_none([safe_int(r.get('traps_avoided_in_diff')) for r in rows]),
        'traps_caught':   median_or_none([safe_int(r.get('traps_caught_in_qa'))    for r in rows]),
        'functional_pass': sum(1 for r in rows if safe_bool(r.get('functional_pass'))) > len(rows)/2,
    }

grouped = defaultdict(list)
for r in this_run_rows:
    grouped[(r.get('workload_id', '').strip(), r.get('leg', '').strip())].append(r)

seen_wl = {}
for r in this_run_rows:
    wid = r.get('workload_id', '').strip()
    if wid and wid not in seen_wl:
        seen_wl[wid] = None
workload_ids = list(seen_wl.keys())

leg_data = {}
for wid in workload_ids:
    leg_data[wid] = {}
    for leg in ('zero', 'savvy', 'stackpilot'):
        rows_for_leg = grouped.get((wid, leg), [])
        leg_data[wid][leg] = aggregate(rows_for_leg) if rows_for_leg else None

# ─── Per-dimension scoring ────────────────────────────────────────────────────
# Each dimension maps to a 0-100 score per leg per workload.
# Over-engineering resistance: if a future traps.yml carries category metadata,
# a companion file (traps-by-category.json, generated during the run) can narrow
# the trap set. Until that lands, we treat ALL traps as the over-eng pool because
# the v2 workloads (M3) are specifically designed with over-engineering traps.

def correctness_score(leg):
    if leg is None:
        return None
    return 100.0 if leg['functional_pass'] else 0.0

def over_eng_score(leg):
    """Fraction of traps avoided in the diff, 0-100."""
    if leg is None or leg['traps_total'] in (None, 0):
        return None
    avoided = leg['traps_avoided'] or 0
    total = leg['traps_total']
    return 100.0 * avoided / total

def bug_catch_score(leg, is_stackpilot):
    """Fraction of traps caught by sp-qa. Only defined for stackpilot leg."""
    if not is_stackpilot or leg is None or leg['traps_total'] in (None, 0):
        return None
    caught = leg['traps_caught'] or 0
    total = leg['traps_total']
    return 100.0 * caught / total

def relative_score(value, best):
    """best gets 100, others scale proportionally (lower=better input)."""
    if value is None or best is None or value == 0 or best == 0:
        return None
    return 100.0 * best / value

def compute_leg_scores(wid, leg_name):
    leg = leg_data[wid].get(leg_name)
    if leg is None:
        return None
    # Relative scores need per-workload minimums across the three legs.
    legs_present = [leg_data[wid].get(n) for n in ('zero', 'savvy', 'stackpilot') if leg_data[wid].get(n)]
    min_tokens = min((l['total_tokens'] for l in legs_present if l['total_tokens']), default=None)
    min_duration = min((l['duration_sec'] for l in legs_present if l['duration_sec']), default=None)
    return {
        'correctness': correctness_score(leg),
        'over_eng':    over_eng_score(leg),
        'bug_catch':   bug_catch_score(leg, leg_name == 'stackpilot'),
        'token':       relative_score(leg['total_tokens'], min_tokens),
        'speed':       relative_score(leg['duration_sec'], min_duration),
    }

# Compute per-leg scores across all workloads, averaged.

def mean_or_none(vals):
    clean = [v for v in vals if v is not None]
    if not clean:
        return None
    return sum(clean) / len(clean)

def leg_overall(leg_name):
    dims = {k: [] for k in WEIGHTS.keys()}
    for wid in workload_ids:
        s = compute_leg_scores(wid, leg_name)
        if s is None:
            continue
        for k in dims:
            if s.get(k) is not None:
                dims[k].append(s[k])
    # Average each dimension across workloads
    avg = {k: mean_or_none(v) for k, v in dims.items()}
    # Weighted overall: skip N/A dimensions (re-weight remaining).
    total_w = 0.0
    total_score = 0.0
    for k, w in WEIGHTS.items():
        if avg.get(k) is not None:
            total_score += avg[k] * w
            total_w += w
    overall = total_score / total_w if total_w > 0 else None
    return avg, overall

# ─── Discrimination check ─────────────────────────────────────────────────────
# A workload is NON-DISCRIMINATIVE if native-zero already scores > 90 on it:
# Claude 4.7 can do the task zero-shot, so the stackpilot overhead has nothing
# to earn back. Real users would not invoke /stackpilot for such tasks, so
# including them in the overall score is a selection-bias error. Flag them,
# exclude from overall composite, but keep their data in the CSV and the
# per-workload table so the bias is visible.

DISCRIMINATION_THRESHOLD = 90.0

def composite(dims):
    if dims is None:
        return None
    total_w = 0.0
    total_s = 0.0
    for k, w in WEIGHTS.items():
        if dims.get(k) is not None:
            total_s += dims[k] * w
            total_w += w
    return total_s / total_w if total_w > 0 else None

non_discriminative = set()
for wid in workload_ids:
    zero_scores = compute_leg_scores(wid, 'zero')
    zc = composite(zero_scores)
    if zc is not None and zc > DISCRIMINATION_THRESHOLD:
        non_discriminative.add(wid)

discriminative_ids = [w for w in workload_ids if w not in non_discriminative]

def leg_overall_filtered(leg_name, wids):
    dims = {k: [] for k in WEIGHTS.keys()}
    for wid in wids:
        s = compute_leg_scores(wid, leg_name)
        if s is None:
            continue
        for k in dims:
            if s.get(k) is not None:
                dims[k].append(s[k])
    avg = {k: mean_or_none(v) for k, v in dims.items()}
    total_w = 0.0
    total_score = 0.0
    for k, w in WEIGHTS.items():
        if avg.get(k) is not None:
            total_score += avg[k] * w
            total_w += w
    overall = total_score / total_w if total_w > 0 else None
    return avg, overall

# All-workloads view (for per-dimension table display)
savvy_dims_all, savvy_overall_all = leg_overall('savvy')
sp_dims_all,    sp_overall_all    = leg_overall('stackpilot')
zero_dims_all,  zero_overall_all  = leg_overall('zero')

# Discriminative-only view (for headline overall score)
savvy_dims,   savvy_overall   = leg_overall_filtered('savvy', discriminative_ids)
sp_dims,      sp_overall      = leg_overall_filtered('stackpilot', discriminative_ids)
zero_dims,    zero_overall    = leg_overall_filtered('zero', discriminative_ids)

# If ALL workloads are non-discriminative, fall back to all-workloads so we
# still produce numbers, but flag the run in the headline.
if not discriminative_ids:
    savvy_dims,   savvy_overall   = savvy_dims_all,   savvy_overall_all
    sp_dims,      sp_overall      = sp_dims_all,      sp_overall_all
    zero_dims,    zero_overall    = zero_dims_all,    zero_overall_all

# ─── Formatting helpers ───────────────────────────────────────────────────────

def fmt(v, width=5):
    if v is None:
        return 'N/A'.rjust(width)
    return f"{v:>{width}.0f}"

def fmt_delta(a, b):
    if a is None or b is None:
        return '  N/A'
    d = a - b
    sign = '+' if d >= 0 else ''
    return f"{sign}{d:.0f}"

def marker(delta):
    if delta is None:
        return ''
    a = abs(delta)
    if a >= 30:
        return '★★'
    if a >= 15:
        return '★'
    return ''

def format_ts_display(ts):
    parts = ts.split('-')
    if len(parts) == 4 and len(parts[3]) == 4:
        return f"{parts[0]}-{parts[1]}-{parts[2]} {parts[3][:2]}:{parts[3][2:]}"
    return ts

# Determine sample size note
sample_n = max(len(grouped[(wid, leg)]) for (wid, leg) in grouped) if grouped else 1

ts_display = format_ts_display(run_ts)
border = '═' * 64

# ─── Render scorecard ─────────────────────────────────────────────────────────

lines = []
lines.append(border)
lines.append(f"  STACKPILOT vs NATIVE Claude Code — Performance Scorecard")
lines.append(border)
if non_discriminative:
    nd_note = f" ({len(non_discriminative)} NON-DISCRIMINATIVE excluded)"
else:
    nd_note = ""
lines.append(f"  run: {ts_display}  |  n={sample_n} per leg  |  workloads: {len(discriminative_ids)}/{len(workload_ids)}{nd_note}")
lines.append('')

# Overall row
lines.append(f"  OVERALL SCORE       Native Savvy  Stackpilot    Δ")
savvy_s = fmt(savvy_overall, 5)
sp_s    = fmt(sp_overall, 5)
delta   = None
if savvy_overall is not None and sp_overall is not None:
    delta = sp_overall - savvy_overall
delta_s = fmt_delta(sp_overall, savvy_overall)
advantage = ''
if delta is not None and savvy_overall and savvy_overall > 0:
    pct = 100 * delta / savvy_overall
    sign = '+' if pct >= 0 else ''
    advantage = f"  (stackpilot {sign}{pct:.0f}%)"
lines.append(f"                         {savvy_s}          {sp_s}   {delta_s}{advantage}")
lines.append('')

# Per-dimension table
lines.append(f"  DIMENSIONS (0-100)  Native Savvy  Stackpilot    Δ")
dim_labels = {
    'correctness': 'Correctness       ',
    'over_eng':    'Over-eng resist   ',
    'bug_catch':   'Bug catch rate    ',
    'token':       'Token efficiency  ',
    'speed':       'Wall-clock speed  ',
}
for k, label in dim_labels.items():
    sav = savvy_dims.get(k)
    sp  = sp_dims.get(k)
    d   = None
    if sav is not None and sp is not None:
        d = sp - sav
    m = marker(d)
    lines.append(f"    {label}   {fmt(sav, 5)}          {fmt(sp, 5)}   {fmt_delta(sp, sav):>6}  {m}")
lines.append('')

# Per-workload breakdown
lines.append(f"  PER-WORKLOAD (stackpilot vs savvy)")
for wid in workload_ids:
    sav = compute_leg_scores(wid, 'savvy')
    sp  = compute_leg_scores(wid, 'stackpilot')
    sav_c = composite(sav)
    sp_c  = composite(sp)
    delta_wl = None
    if sav_c is not None and sp_c is not None:
        delta_wl = sp_c - sav_c
    if wid in non_discriminative:
        note = '  🚫 NON-DISCRIMINATIVE (zero >90, excluded)'
    elif delta_wl is not None:
        if delta_wl < -5:
            note = '  ⚠️  开销不回本'
        elif delta_wl > 15:
            note = '  ✓✓'
        elif delta_wl > 5:
            note = '  ✓'
        else:
            note = ''
    else:
        note = ''
    lines.append(f"    {wid:<24}  savvy {fmt(sav_c, 3)}  |  stackpilot {fmt(sp_c, 3)}   {fmt_delta(sp_c, sav_c):>6}{note}")
lines.append('')

# Zero baseline for reference
if zero_overall is not None:
    lines.append(f"  FLOOR BASELINE (native zero-shot prompt): {fmt(zero_overall, 5)}  (unassisted Claude)")
    lines.append('')

# Headline verdict
if not discriminative_ids:
    lines.append("  HEADLINE: ⚠️  INCONCLUSIVE — all workloads are NON-DISCRIMINATIVE.")
    lines.append("            Native zero scored >90 on every workload, meaning the")
    lines.append("            tasks are too simple for /stackpilot to have a reason to")
    lines.append("            run. Design harder workloads and re-bench before drawing")
    lines.append("            conclusions from this report.")
    lines.append('')
elif sp_overall is not None and savvy_overall is not None:
    if sp_overall > savvy_overall + 10:
        headline = "✅  stackpilot 显著领先"
    elif sp_overall > savvy_overall + 3:
        headline = "✓  stackpilot 略胜"
    elif sp_overall > savvy_overall - 3:
        headline = "≈  stackpilot 与 savvy 持平"
    elif sp_overall > savvy_overall - 10:
        headline = "⚠️  stackpilot 略输"
    else:
        headline = "❌  stackpilot 明显落后"
    lines.append(f"  HEADLINE: {headline}")
    lines.append('')

lines.append(f"  RAW DATA: .stackpilot/benchmarks/runs/{run_ts}/rows.csv")
lines.append(border)

for ln in lines:
    print(ln)
PYEOF
