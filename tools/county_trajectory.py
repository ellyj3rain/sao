#!/usr/bin/env python3
"""Record completed causal county simulations with their inputs and provenance.

Defaults to real engine names/professions and joint SAO/ZAO dormant execution.
The records describe this harness's outcomes; they are not generation rules or
fitted world states. Every requested seed/horizon must complete before export.
"""
import argparse
import json
import math
import os
import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep  # noqa: E402


def fit_exponential_decay(points):
    """Optional descriptive log slope; never a survivor floor or runtime model."""
    if len(points) < 3 or len({p['days'] for p in points}) < 3:
        raise Sweep.EvidenceError('a descriptive slope needs at least three distinct horizons')
    if any(p['alive'] <= 0 for p in points):
        raise Sweep.EvidenceError('log slope is undefined for extinction; no fallback is fitted')
    if len({p['provenance']['seed'] for p in points}) != 1:
        raise Sweep.EvidenceError('describe each seed separately; do not fit unrelated counties')
    x = [p['days'] for p in points]
    y = [math.log(p['alive']) for p in points]
    mx, my = sum(x) / len(x), sum(y) / len(y)
    xx = sum((v - mx) ** 2 for v in x)
    slope = sum((a - mx) * (b - my) for a, b in zip(x, y)) / xx
    residual = sum((b - (my + slope * (a - mx))) ** 2 for a, b in zip(x, y))
    total = sum((b - my) ** 2 for b in y)
    return {'description': 'log-alive slope only; no floor or generation model',
            'slope': slope, 'r2': 1 - residual / total if total else None}


def run_trajectories(spans, runs_per_span, lua=None, population=None, engine=True,
                     joint=True, seed_prefix='Trajectory', timeout=3600):
    lua_path = pathlib.Path(lua).resolve() if lua else ROOT / 'mod/42.20/media/lua'
    if not spans or any(span <= 0 for span in spans) or runs_per_span <= 0:
        raise Sweep.EvidenceError('positive horizons and run count required')
    Sweep.prepare(lua_path, engine, joint)
    records = []
    for run in range(runs_per_span):
        # The common label identifies a replicate, not a common county: production
        # seeds include each horizon's own exact target start date.
        name = '%s%03d' % (seed_prefix, run)
        for span in spans:
            print('Simulating %s through calendar day %s ...' % (name, span), flush=True)
            result = Sweep.one(name, lua_path, span, refill=None, population=population,
                               engine=engine, joint=joint, timeout=timeout)
            if not result or result.get('ranTo') != span or not result.get('completed'):
                raise Sweep.EvidenceError('%s did not complete day %s' % (name, span))
            result['spanTarget'] = span
            result['days'] = result['ranTo']
            records.append(result)
            print('  alive=%s dead=%s groups=%s largest=%s' %
                  (result['alive'], result['dead'], result['housesStanding'],
                   result['biggestHouse']), flush=True)
    return records


def export_records(records, path):
    """Exclusive creation protects old evidence and sibling authored datasets."""
    target = pathlib.Path(path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8',
                                         dir=target.parent, delete=False) as stream:
            temporary = pathlib.Path(stream.name)
            for record in records:
                stream.write(json.dumps(record, sort_keys=True, allow_nan=False) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        # A hard link is atomic and refuses an existing name on both platforms.
        os.link(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--spans', default='30,90,180,365,730,1096')
    ap.add_argument('--runs', type=int, default=1)
    ap.add_argument('--population', type=int)
    ap.add_argument('--lua')
    ap.add_argument('--out', help='explicit new JSONL path; existing files are preserved')
    ap.add_argument('--engine', action=argparse.BooleanOptionalAction, default=True,
                    help='real game name pools and profession definitions (default on)')
    ap.add_argument('--joint', action=argparse.BooleanOptionalAction, default=True,
                    help='run the sibling ZAO pathogen modules (default on)')
    ap.add_argument('--seed-prefix', default='Trajectory')
    ap.add_argument('--timeout', type=int, default=3600)
    ap.add_argument('--describe-log-slope', action='store_true',
                    help='optional descriptive statistic, never a generation model')
    args = ap.parse_args()
    try:
        spans = sorted(set(int(s.strip()) for s in args.spans.split(',')))
        if args.out and pathlib.Path(args.out).exists():
            raise Sweep.EvidenceError('output exists; choose a new evidence file')
        records = run_trajectories(spans, args.runs, args.lua, args.population,
                                  args.engine, args.joint, args.seed_prefix, args.timeout)
        if args.describe_log_slope:
            for name in sorted({r['provenance']['saveName'] for r in records}):
                print(name, json.dumps(fit_exponential_decay(
                    [r for r in records if r['provenance']['saveName'] == name])))
        if args.out:
            export_records(records, args.out)
            print('Recorded %s completed simulations in %s' % (len(records), args.out))
        else:
            for row in records:
                print(json.dumps(row, sort_keys=True))
        return 0
    except (Sweep.EvidenceError, ValueError, OSError) as exc:
        print('FAILED: %s; no aggregate or dataset accepted' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
