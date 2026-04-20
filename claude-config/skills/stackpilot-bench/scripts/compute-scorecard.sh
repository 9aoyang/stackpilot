#!/usr/bin/env bash
set -euo pipefail

# compute-scorecard.sh
# Usage: compute-scorecard.sh <history_csv_path> <run_timestamp> [config_path]
#
# Reads history.csv, extracts rows for run_timestamp, computes a product-
# comparison scorecard (stackpilot vs native zero by default; native savvy is
# still supported for reading older 3-leg history)
# and prints a score/time-first human-readable scorecard to stdout.
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
# Dimension collection weights. Human-facing score uses QUALITY_WEIGHTS below;
# token and speed are still collected but displayed separately.

WEIGHTS = {
    'correctness':  0.30,
    'over_eng':     0.30,
    'bug_catch':    0.15,
    'token':        0.15,
    'speed':        0.10,
}

QUALITY_WEIGHTS = {
    'correctness': 0.45,
    'over_eng':    0.40,
    'bug_catch':   0.15,
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
    statuses = [(r.get('status') or 'ok').strip() for r in rows]
    non_ok_statuses = [s for s in statuses if s and s != 'ok']
    return {
        'total_tokens':   median_or_none([safe_int(r.get('total_tokens'))   for r in rows]),
        'duration_sec':   median_or_none([safe_float(r.get('duration_sec')) for r in rows]),
        'traps_total':    median_or_none([safe_int(r.get('traps_total'))    for r in rows]),
        'traps_avoided':  median_or_none([safe_int(r.get('traps_avoided_in_diff')) for r in rows]),
        'traps_caught':   median_or_none([safe_int(r.get('traps_caught_in_qa'))    for r in rows]),
        'functional_pass': not non_ok_statuses and sum(1 for r in rows if safe_bool(r.get('functional_pass'))) > len(rows)/2,
        'status_ok':       not non_ok_statuses,
        'statuses':        statuses,
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
    if not leg.get('status_ok', True):
        return 0.0
    return 100.0 if leg['functional_pass'] else 0.0

def over_eng_score(leg):
    """Fraction of traps avoided in the diff, 0-100."""
    if leg is None or leg['traps_total'] in (None, 0):
        return None
    if not leg.get('status_ok', True):
        return 0.0
    avoided = leg['traps_avoided'] or 0
    total = leg['traps_total']
    return 100.0 * avoided / total

def bug_catch_score(leg, is_stackpilot):
    """Fraction of traps caught by sp-qa. Only defined for stackpilot leg."""
    if not is_stackpilot or leg is None or leg['traps_total'] in (None, 0):
        return None
    if not leg.get('status_ok', True):
        return 0.0
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
    # Human-facing score is quality-only. Cost is shown separately as time.
    total_w = 0.0
    total_score = 0.0
    for k, w in QUALITY_WEIGHTS.items():
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
    for k, w in QUALITY_WEIGHTS.items():
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
    for k, w in QUALITY_WEIGHTS.items():
        if avg.get(k) is not None:
            total_score += avg[k] * w
            total_w += w
    overall = total_score / total_w if total_w > 0 else None
    return avg, overall

has_savvy = any(leg_data[wid].get('savvy') for wid in workload_ids)
baseline_leg = 'savvy' if has_savvy else 'zero'
baseline_label = 'Native Savvy' if has_savvy else 'Native Zero'

invalid_legs = []
for wid in workload_ids:
    for leg_name in ('zero', 'savvy', 'stackpilot'):
        leg = leg_data[wid].get(leg_name)
        if not leg:
            continue
        bad_statuses = sorted({s for s in leg.get('statuses', []) if s and s != 'ok'})
        for status in bad_statuses:
            invalid_legs.append((wid, leg_name, status))

# All-workloads view (for per-dimension table display)
baseline_dims_all, baseline_overall_all = leg_overall(baseline_leg)
sp_dims_all,       sp_overall_all       = leg_overall('stackpilot')
zero_dims_all,     zero_overall_all     = leg_overall('zero')

# Discriminative-only view (for headline overall score)
baseline_dims,   baseline_overall   = leg_overall_filtered(baseline_leg, discriminative_ids)
sp_dims,         sp_overall         = leg_overall_filtered('stackpilot', discriminative_ids)
zero_dims,       zero_overall       = leg_overall_filtered('zero', discriminative_ids)

# If ALL workloads are non-discriminative, fall back to all-workloads so we
# still produce numbers, but flag the run in the headline.
if not discriminative_ids:
    baseline_dims,   baseline_overall   = baseline_dims_all,   baseline_overall_all
    sp_dims,         sp_overall         = sp_dims_all,         sp_overall_all
    zero_dims,       zero_overall       = zero_dims_all,       zero_overall_all

# ─── Human-readable formatting helpers ────────────────────────────────────────

def format_ts_display(ts):
    parts = ts.split('-')
    if len(parts) == 4 and len(parts[3]) == 4:
        return f"{parts[0]}-{parts[1]}-{parts[2]} {parts[3][:2]}:{parts[3][2:]}"
    return ts

def fmt_score(v):
    if v is None:
        return 'N/A'
    return f"{v:.0f}/100"

def fmt_delta(a, b):
    if a is None or b is None:
        return 'N/A'
    d = a - b
    sign = '+' if d >= 0 else ''
    return f"{sign}{d:.0f}"

def stars(score):
    if score is None:
        return 'N/A'
    full = max(0, min(5, int(round(score / 20.0))))
    return '★' * full + '☆' * (5 - full)

def bar(score, width=10):
    if score is None:
        return 'N/A'
    filled = max(0, min(width, int(round(width * score / 100.0))))
    return '█' * filled + '░' * (width - filled)

def fmt_duration(seconds):
    if seconds is None:
        return 'N/A'
    seconds = int(round(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}h{m:02d}m"
    if m:
        return f"{m}m{s:02d}s"
    return f"{s}s"

def fmt_duration_delta(a, b):
    if a is None or b is None:
        return 'N/A'
    delta = a - b
    sign = '+' if delta >= 0 else '-'
    return f"{sign}{fmt_duration(abs(delta))}"

def fmt_pct_delta(a, b):
    if a is None or b in (None, 0):
        return 'N/A'
    d = 100.0 * (a - b) / b
    sign = '+' if d >= 0 else ''
    return f"{sign}{d:.0f}%"

def aggregate_duration(wids, leg_name):
    vals = []
    for wid in wids:
        leg = leg_data.get(wid, {}).get(leg_name)
        if leg and leg.get('duration_sec') is not None:
            vals.append(leg['duration_sec'])
    if not vals:
        return None
    return sum(vals)

def workload_composite(wid, leg_name):
    return composite(compute_leg_scores(wid, leg_name))

def recommendation_for(wid, delta):
    if wid in non_discriminative:
        return '不用 Stackpilot'
    if delta is None:
        return '数据不足'
    if delta >= 8:
        return '用 Stackpilot'
    if delta >= 3:
        return '看成本敏感度'
    return '不用 Stackpilot'

# Determine sample size note
sample_n = max(len(grouped[(wid, leg)]) for (wid, leg) in grouped) if grouped else 1

ts_display = format_ts_display(run_ts)
border = '─' * 72

target_ids = discriminative_ids
native_enough_ids = [w for w in workload_ids if w in non_discriminative]
display_ids = target_ids if target_ids else workload_ids

baseline_time = aggregate_duration(display_ids, baseline_leg)
sp_time = aggregate_duration(display_ids, 'stackpilot')
zero_time = aggregate_duration(display_ids, 'zero')

baseline_speed = baseline_dims.get('speed') if baseline_dims else None
sp_speed = sp_dims.get('speed') if sp_dims else None
zero_speed = zero_dims.get('speed') if zero_dims else None

score_delta = sp_overall - baseline_overall if sp_overall is not None and baseline_overall is not None else None
time_delta = sp_time - baseline_time if sp_time is not None and baseline_time is not None else None
extra_min_per_point = None
if score_delta and score_delta > 0 and time_delta is not None and time_delta > 0:
    extra_min_per_point = (time_delta / 60.0) / score_delta

# ─── Render scorecard ─────────────────────────────────────────────────────────

lines = []
lines.append("# Stackpilot Bench")
lines.append('')
lines.append(f"Run: `{run_ts}`  |  n={sample_n} per leg  |  workloads: {len(target_ids)} target / {len(workload_ids)} total")
if native_enough_ids:
    lines.append(f"Native-enough workloads excluded from target summary: {len(native_enough_ids)}")
lines.append('')

lines.append("## Headline")
lines.append('')
if any(status == 'orchestration_invalid' for _, _, status in invalid_legs):
    lines.append("Stackpilot 编排无效：至少一个 stackpilot leg 缺少可审计的 architect/dev/qa 阶段证据。")
    lines.append("这次不能作为正常 Stackpilot 质量对比，只能作为 Codex skill 执行契约失败样本。")
elif not target_ids:
    lines.append("这次结果不可作为 Stackpilot 价值判断：所有 workload 都属于 native-enough，原生 zero-shot 已经接近满分。")
    lines.append("下一步应该换更复杂的 workload，而不是调 agent prompt。")
elif score_delta is not None and time_delta is not None:
    if score_delta >= 8:
        lines.append(f"复杂任务建议使用 Stackpilot：质量 {fmt_delta(sp_overall, baseline_overall)} 分，额外耗时 {fmt_duration_delta(sp_time, baseline_time)}（{fmt_pct_delta(sp_time, baseline_time)}）。")
    elif score_delta >= 3:
        lines.append(f"Stackpilot 略有质量收益：质量 {fmt_delta(sp_overall, baseline_overall)} 分，但额外耗时 {fmt_duration_delta(sp_time, baseline_time)}（{fmt_pct_delta(sp_time, baseline_time)}）。")
    else:
        lines.append(f"不建议为这类任务使用 Stackpilot：质量 {fmt_delta(sp_overall, baseline_overall)} 分，耗时 {fmt_duration_delta(sp_time, baseline_time)}。")
    if extra_min_per_point is not None:
        lines.append(f"换算下来，每提升 1 分大约多花 {extra_min_per_point:.1f} 分钟。")
else:
    lines.append("数据不足，无法判断 Stackpilot 是否值得使用。")
lines.append('')
lines.append("## Overall")
lines.append('')
lines.append("Native Zero")
lines.append(f"质量：{stars(zero_overall)} {fmt_score(zero_overall)}")
lines.append(f"耗时：{fmt_duration(zero_time)}（速度 {stars(zero_speed)}）")
lines.append('')
if has_savvy:
    lines.append("Native Savvy")
    lines.append(f"质量：{stars(baseline_overall)} {fmt_score(baseline_overall)}")
    lines.append(f"耗时：{fmt_duration(baseline_time)}（速度 {stars(baseline_speed)}）")
    lines.append('')
lines.append("Stackpilot")
lines.append(f"质量：{stars(sp_overall)} {fmt_score(sp_overall)}")
lines.append(f"耗时：{fmt_duration(sp_time)}（速度 {stars(sp_speed)}）")
lines.append('')
lines.append("质量图")
lines.append(f"{baseline_label:<13} {bar(baseline_overall)} {fmt_score(baseline_overall)}")
lines.append(f"Stackpilot    {bar(sp_overall)} {fmt_score(sp_overall)}")
lines.append('')
lines.append("## Per Workload")
lines.append('')
for wid in workload_ids:
    zero_c = workload_composite(wid, 'zero')
    base_c = workload_composite(wid, baseline_leg)
    sp_c = workload_composite(wid, 'stackpilot')
    zero_d = leg_data[wid]['zero']['duration_sec'] if leg_data[wid].get('zero') else None
    base_d = leg_data[wid][baseline_leg]['duration_sec'] if leg_data[wid].get(baseline_leg) else None
    sp_d = leg_data[wid]['stackpilot']['duration_sec'] if leg_data[wid].get('stackpilot') else None
    delta_wl = sp_c - base_c if sp_c is not None and base_c is not None else None
    rec = recommendation_for(wid, delta_wl)
    label = "native enough" if wid in non_discriminative else "target"
    lines.append(f"{wid} ({label})")
    lines.append(f"{baseline_label}：{stars(base_c)} {fmt_score(base_c)} / {fmt_duration(base_d)}")
    lines.append(f"Stackpilot： {stars(sp_c)} {fmt_score(sp_c)} / {fmt_duration(sp_d)}")
    if delta_wl is not None:
        lines.append(f"差异：{fmt_delta(sp_c, base_c)} 分，耗时 {fmt_duration_delta(sp_d, base_d)}（{fmt_pct_delta(sp_d, base_d)}）")
    lines.append(f"建议：{rec}")
    lines.append('')
lines.append("## Diagnostics")
lines.append('')
lines.append(f"- Target workloads: {len(target_ids)}")
lines.append(f"- Native-enough workloads: {len(native_enough_ids)}")
if invalid_legs:
    rendered_invalid = ', '.join(f"{wid}/{leg}={status}" for wid, leg, status in invalid_legs)
    lines.append(f"- Invalid legs: {rendered_invalid}")
lines.append(f"- Raw rows: `.stackpilot/benchmarks/runs/{run_ts}/rows.csv`")
lines.append(f"- Full history source: `.stackpilot/benchmarks/history.csv`")
lines.append(border)

for ln in lines:
    print(ln)
PYEOF
