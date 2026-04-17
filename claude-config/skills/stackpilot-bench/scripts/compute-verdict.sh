#!/usr/bin/env bash
set -euo pipefail

# compute-verdict.sh
# Usage: compute-verdict.sh <history_csv_path> <run_timestamp>
# Example: compute-verdict.sh .stackpilot/benchmarks/history.csv 2026-04-17-1430
#
# Reads history.csv, extracts rows for run_timestamp, computes pairwise per-workload
# verdicts and an overall run verdict, then prints the ASCII verdict block to stdout.

HISTORY_CSV="${1:?Usage: compute-verdict.sh <history_csv_path> <run_timestamp>}"
RUN_TS="${2:?Usage: compute-verdict.sh <history_csv_path> <run_timestamp>}"

if [[ ! -f "$HISTORY_CSV" ]]; then
  echo "ERROR: history CSV not found: $HISTORY_CSV" >&2
  exit 1
fi

python3 - "$HISTORY_CSV" "$RUN_TS" <<'PYEOF'
import sys
import csv
import statistics
import math
from collections import defaultdict

history_csv = sys.argv[1]
run_ts      = sys.argv[2]

# ─── Load CSV ────────────────────────────────────────────────────────────────

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

this_run_rows  = [r for r in all_rows if r.get('timestamp', '').strip() == run_ts]
prior_run_rows = [r for r in all_rows if r.get('timestamp', '').strip() != run_ts]

if not this_run_rows:
    print(f"ERROR: no rows found for timestamp '{run_ts}' in {history_csv}", file=sys.stderr)
    sys.exit(1)

# ─── Helper: aggregate per (workload, leg) using median/mode ─────────────────

def median_or_none(vals):
    clean = [v for v in vals if v is not None]
    if not clean:
        return None
    return statistics.median(clean)

def mode_bool(vals):
    """Return majority-vote bool; None if no values."""
    clean = [v for v in vals if v is not None]
    if not clean:
        return None
    return sum(clean) > len(clean) / 2

def aggregate_leg_rows(rows):
    """
    Given a list of CSV rows for one (workload, leg), return a single aggregated dict.
    Numeric fields: median; bool fields: mode.
    """
    total_tokens     = median_or_none([safe_int(r.get('total_tokens'))  for r in rows])
    duration_sec     = median_or_none([safe_float(r.get('duration_sec')) for r in rows])
    traps_total      = median_or_none([safe_int(r.get('traps_total'))   for r in rows])
    traps_avoided    = median_or_none([safe_int(r.get('traps_avoided_in_diff')) for r in rows])
    traps_caught     = median_or_none([safe_int(r.get('traps_caught_in_qa'))    for r in rows])
    functional_pass  = mode_bool([safe_bool(r.get('functional_pass'))          for r in rows])
    return {
        'total_tokens':          total_tokens,
        'duration_sec':          duration_sec,
        'traps_total':           traps_total,
        'traps_avoided_in_diff': traps_avoided,
        'traps_caught_in_qa':    traps_caught,
        'functional_pass':       functional_pass,
    }

# ─── Build per-(workload, leg) aggregated view for this run ──────────────────

# Group rows by (workload_id, leg)
grouped = defaultdict(list)
for r in this_run_rows:
    key = (r.get('workload_id', '').strip(), r.get('leg', '').strip())
    grouped[key].append(r)

# Collect unique workload IDs (preserve order)
seen_wl = {}
for r in this_run_rows:
    wid = r.get('workload_id', '').strip()
    if wid and wid not in seen_wl:
        seen_wl[wid] = None
workload_ids = list(seen_wl.keys())

if not workload_ids:
    print("ERROR: no workload_id values found in the run rows", file=sys.stderr)
    sys.exit(1)

# Build a dict: wl -> leg -> aggregated metrics
leg_data = {}
for wid in workload_ids:
    leg_data[wid] = {}
    for leg in ('zero', 'savvy', 'stackpilot'):
        rows_for_leg = grouped.get((wid, leg), [])
        if rows_for_leg:
            leg_data[wid][leg] = aggregate_leg_rows(rows_for_leg)
        else:
            leg_data[wid][leg] = None

# ─── Thresholds ──────────────────────────────────────────────────────────────

SAVVY_COST_MULT              = 3
ZERO_COST_MULT               = 5
POSITIVE_REGRESSION_THRESHOLD = 0.20   # >20% is bad
MARGINAL_LOW                 = 0.05    # 5%
MARGINAL_HIGH                = 0.20    # 20%

# ─── Per-workload pairwise verdicts ──────────────────────────────────────────

def pairwise_pass_vs(sp, baseline, cost_mult):
    """Return (pass_bool, reason_str) for a pairwise comparison."""
    if sp is None or baseline is None:
        return False, "missing data for one leg"
    reasons = []

    sp_traps    = sp['traps_avoided_in_diff']
    bl_traps    = baseline['traps_avoided_in_diff']
    trap_ok     = (sp_traps is not None and bl_traps is not None and sp_traps >= bl_traps)
    if not trap_ok:
        reasons.append(f"traps {sp_traps} < {bl_traps}")

    func_ok = bool(sp.get('functional_pass'))
    if not func_ok:
        reasons.append("functional_pass=false")

    sp_tok  = sp['total_tokens']
    bl_tok  = baseline['total_tokens']
    cost_ok = (sp_tok is not None and bl_tok is not None and sp_tok <= cost_mult * bl_tok)
    if not cost_ok:
        reasons.append(f"tokens {sp_tok} > {cost_mult}x{bl_tok}={cost_mult*bl_tok if bl_tok else '?'}")

    passed = trap_ok and func_ok and cost_ok
    return passed, ('; '.join(reasons) if reasons else 'ok')

workload_verdicts = {}
for wid in workload_ids:
    sp   = leg_data[wid].get('stackpilot')
    savvy = leg_data[wid].get('savvy')
    zero  = leg_data[wid].get('zero')

    pass_vs_savvy, _ = pairwise_pass_vs(sp, savvy, SAVVY_COST_MULT)
    pass_vs_zero,  _ = pairwise_pass_vs(sp, zero,  ZERO_COST_MULT)

    workload_verdicts[wid] = {
        'pass_vs_savvy': pass_vs_savvy,
        'pass_vs_zero':  pass_vs_zero,
        'sp':    sp,
        'savvy': savvy,
        'zero':  zero,
    }

# ─── Aggregate delta vs prior run ────────────────────────────────────────────

def most_recent_prior_ts(rows):
    """Return the most recent timestamp string from prior rows, or None."""
    tss = [r.get('timestamp', '').strip() for r in rows if r.get('timestamp', '').strip()]
    if not tss:
        return None
    # Sort lexicographically; format YYYY-MM-DD-HHMM sorts correctly
    return sorted(set(tss))[-1]

prior_ts = most_recent_prior_ts(prior_run_rows)

def sum_stackpilot_tokens(rows):
    """Sum total_tokens for all stackpilot legs in the given row set."""
    total = 0
    for r in rows:
        if r.get('leg', '').strip() == 'stackpilot':
            v = safe_int(r.get('total_tokens'))
            if v is not None:
                total += v
    return total

def sum_traps_caught(rows):
    """Sum traps_caught_in_qa for all stackpilot legs."""
    total = 0
    for r in rows:
        if r.get('leg', '').strip() == 'stackpilot':
            v = safe_int(r.get('traps_caught_in_qa'))
            if v is not None:
                total += v
    return total

def sum_traps_total(rows):
    """Sum traps_total for all stackpilot legs (to compute rate)."""
    total = 0
    for r in rows:
        if r.get('leg', '').strip() == 'stackpilot':
            v = safe_int(r.get('traps_total'))
            if v is not None:
                total += v
    return total

agg_tokens_this  = sum_stackpilot_tokens(this_run_rows)
agg_caught_this  = sum_traps_caught(this_run_rows)
agg_ttotal_this  = sum_traps_total(this_run_rows)

# Prior run aggregates (use the single most-recent timestamp)
has_prior = prior_ts is not None
agg_tokens_prev  = None
agg_caught_prev  = None
agg_ttotal_prev  = None
tokens_growth_pct = None
trap_shrink_pct   = None

if has_prior:
    prior_run_only = [r for r in prior_run_rows if r.get('timestamp', '').strip() == prior_ts]
    agg_tokens_prev = sum_stackpilot_tokens(prior_run_only)
    agg_caught_prev = sum_traps_caught(prior_run_only)
    agg_ttotal_prev = sum_traps_total(prior_run_only)

    if agg_tokens_prev and agg_tokens_prev > 0:
        tokens_growth_pct = (agg_tokens_this - agg_tokens_prev) / agg_tokens_prev

    if agg_ttotal_prev and agg_ttotal_prev > 0 and agg_ttotal_this > 0:
        rate_this = agg_caught_this / agg_ttotal_this
        rate_prev = agg_caught_prev / agg_ttotal_prev
        trap_shrink_pct = (rate_prev - rate_this) / rate_prev if rate_prev > 0 else None

# ─── Overall run verdict ─────────────────────────────────────────────────────

all_pass_vs_savvy = all(workload_verdicts[wid]['pass_vs_savvy'] for wid in workload_ids)

if not has_prior:
    overall = 'BASELINE ESTABLISHED'
    overall_emoji = '\U0001f3af'  # 🎯
else:
    # Check NEGATIVE first
    token_regression  = (tokens_growth_pct is not None and tokens_growth_pct >  POSITIVE_REGRESSION_THRESHOLD)
    trap_dropped_hard = (trap_shrink_pct   is not None and trap_shrink_pct   >  MARGINAL_HIGH)

    if not all_pass_vs_savvy or trap_dropped_hard:
        overall = 'NEGATIVE OPTIMIZATION'
        overall_emoji = '\u274c'  # ❌
    elif all_pass_vs_savvy and (tokens_growth_pct is None or tokens_growth_pct <= POSITIVE_REGRESSION_THRESHOLD) and \
         (trap_shrink_pct is None or trap_shrink_pct <= 0):
        # No shrink at all → positive
        overall = 'POSITIVE OPTIMIZATION'
        overall_emoji = '\u2705'  # ✅
    elif all_pass_vs_savvy:
        # Marginal band: token growth 5-20% OR trap rate shrank 5-20%
        token_marginal = (tokens_growth_pct is not None and MARGINAL_LOW < tokens_growth_pct <= MARGINAL_HIGH)
        trap_marginal  = (trap_shrink_pct   is not None and MARGINAL_LOW < trap_shrink_pct   <= MARGINAL_HIGH)
        token_exceeded = token_regression  # >20%
        if token_exceeded:
            overall = 'NEGATIVE OPTIMIZATION'
            overall_emoji = '\u274c'
        elif token_marginal or trap_marginal:
            overall = 'MARGINAL'
            overall_emoji = '\u26a0\ufe0f'  # ⚠️
        else:
            # token growth <= 5% and trap didn't shrink materially
            overall = 'POSITIVE OPTIMIZATION'
            overall_emoji = '\u2705'
    else:
        overall = 'NEGATIVE OPTIMIZATION'
        overall_emoji = '\u274c'

# ─── Build display deltas ─────────────────────────────────────────────────────

def pct_str(frac):
    """Format fraction as +X% / -X%."""
    if frac is None:
        return 'n/a'
    pct = frac * 100
    sign = '+' if pct >= 0 else ''
    return f"{sign}{pct:.1f}%"

def mult_str(num, denom):
    """Format ratio as Xx (e.g., 2.4x)."""
    if num is None or denom is None or denom == 0:
        return 'n/a'
    return f"{num/denom:.2g}x"

def quality_delta_str(sp_val, baseline_val):
    """Format trap count delta as +N / -N."""
    if sp_val is None or baseline_val is None:
        return 'n/a'
    delta = sp_val - baseline_val
    sign = '+' if delta >= 0 else ''
    return f"{sign}{int(delta)}"

# Aggregate vs-savvy and vs-zero deltas across all workloads
def agg_metric(wids, leg_key, field):
    vals = []
    for wid in wids:
        d = leg_data[wid].get(leg_key)
        if d and d.get(field) is not None:
            vals.append(d[field])
    return sum(vals) if vals else None

agg_sp_tokens    = agg_metric(workload_ids, 'stackpilot', 'total_tokens')
agg_savvy_tokens = agg_metric(workload_ids, 'savvy',      'total_tokens')
agg_zero_tokens  = agg_metric(workload_ids, 'zero',       'total_tokens')
agg_sp_dur       = agg_metric(workload_ids, 'stackpilot', 'duration_sec')
agg_savvy_dur    = agg_metric(workload_ids, 'savvy',      'duration_sec')
agg_zero_dur     = agg_metric(workload_ids, 'zero',       'duration_sec')
agg_sp_traps     = agg_metric(workload_ids, 'stackpilot', 'traps_avoided_in_diff')
agg_savvy_traps  = agg_metric(workload_ids, 'savvy',      'traps_avoided_in_diff')
agg_zero_traps   = agg_metric(workload_ids, 'zero',       'traps_avoided_in_diff')

tok_frac_savvy = ((agg_sp_tokens - agg_savvy_tokens) / agg_savvy_tokens) if (agg_sp_tokens and agg_savvy_tokens) else None
dur_frac_savvy = ((agg_sp_dur    - agg_savvy_dur)    / agg_savvy_dur)    if (agg_sp_dur    and agg_savvy_dur)    else None
qual_delta_savvy = quality_delta_str(agg_sp_traps, agg_savvy_traps)
tok_mult_zero    = mult_str(agg_sp_tokens, agg_zero_tokens)
dur_mult_zero    = mult_str(agg_sp_dur,    agg_zero_dur)
qual_delta_zero  = quality_delta_str(agg_sp_traps, agg_zero_traps)

# ─── Workload line helpers ────────────────────────────────────────────────────

def workload_line(wid, verdicts):
    sp    = verdicts['sp']
    savvy = verdicts['savvy']
    status = 'PASS' if verdicts['pass_vs_savvy'] else 'FAIL'
    short_id = wid.split('-', 1)[0] if '-' in wid else wid

    sp_avoided   = int(sp['traps_avoided_in_diff'])   if sp   and sp.get('traps_avoided_in_diff')   is not None else '?'
    savvy_avoided = int(savvy['traps_avoided_in_diff']) if savvy and savvy.get('traps_avoided_in_diff') is not None else '?'
    ttotal       = int(sp['traps_total'])              if sp   and sp.get('traps_total')              is not None else '?'

    return f"  {wid}: {status} (traps {sp_avoided}/{ttotal} vs savvy {savvy_avoided}/{ttotal})"

# Timestamp display: "2026-04-17-1430" → "2026-04-17 14:30"
def format_ts_display(ts):
    parts = ts.split('-')
    if len(parts) == 4 and len(parts[3]) == 4:
        return f"{parts[0]}-{parts[1]}-{parts[2]} {parts[3][:2]}:{parts[3][2:]}"
    return ts

ts_display = format_ts_display(run_ts)
border = '\u2501' * 36  # ━━━━...

# ─── Print verdict block ──────────────────────────────────────────────────────

print(border)
print(f"  /stackpilot-bench Verdict \u2014 {ts_display}")
print(border)
print()
print(f"  {overall} {overall_emoji}")
print()
print(f"  vs savvy:  tokens {pct_str(tok_frac_savvy)}   quality {qual_delta_savvy}    duration {pct_str(dur_frac_savvy)}")
print(f"  vs zero:   tokens {tok_mult_zero}   quality {qual_delta_zero}    duration {dur_mult_zero}")
print()
for wid in workload_ids:
    print(workload_line(wid, workload_verdicts[wid]))
print()
print(f"  Full report: .stackpilot/benchmarks/runs/{run_ts}/report.md")
print(border)

PYEOF
