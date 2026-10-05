#!/usr/bin/env python3
"""Execute independent cognitive models in installed Kahlua, with source controls.

Native event authenticity belongs to the separate producer tests. No world,
model training, recipe realization or loaded-game behavior is claimed here.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = pathlib.Path(r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid')
if 'PZ_DIR' in os.environ:
    GAME = Path(os.environ['PZ_DIR'])
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
MODULE = ROOT / 'mod/42.20/media/lua/shared/SAO_CognitiveModels.lua'
CASES = ROOT / 'tools/luacheck/CognitiveModelChecks.lua'


def runtime_root():
    for parent in ROOT.parents:
        if (parent / 'tools/luacheck/LuaRun.java').is_file():
            return parent
    return ROOT


def fingerprint(path):
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--control', action='append', default=[],
                        help='Run only these named controls, plus the production baseline.')
    args = parser.parse_args(argv)
    if args.baseline_only and args.control:
        parser.error('--baseline-only and --control are mutually exclusive')
    engine = GAME / 'projectzomboid.jar'
    # Missing repository inputs remain faults even on a machine without PZ.
    inputs = [fingerprint(MODULE), fingerprint(CASES), fingerprint(Path(__file__))]
    runner = runtime_root() / 'tools/luacheck/LuaRun.java'
    runner_input = fingerprint(runner)
    missing = [path for path in (engine, GAME / 'stdlib.lua', JDK / 'javac.exe', JDK / 'java.exe')
               if not path.is_file()]
    if missing:
        reason = 'installed Project Zomboid engine or JDK unavailable'
        receipt = {'schema': 'sao-cognitive-model-proof/1', 'inputs': inputs,
                   'runner': runner_input, 'engine': {'path': str(engine), 'available': engine.is_file()},
                   'verdict': 'SKIPPED', 'reason': reason,
                   'missingPrerequisites': [str(path) for path in missing],
                   'controls': [], 'baselineOnly': args.baseline_only, 'boundary': __doc__.strip()}
        if args.receipt:
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            args.receipt.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
        print('SKIPPED -- independent cognitive models: ' + reason, flush=True)
        return 0
    source = MODULE.read_text(encoding='utf-8')
    checks = CASES.read_text(encoding='utf-8')
    controls = [
        ('structural identity fallback', [('if not structural and (not text(candidate.id, 128)',
          'if (not text(candidate.id, 128)')], 'long native identity lost neutral structural fallback'),
        ('ordinary equality', [('frame.thirst>=frame.drinkAt', 'frame.thirst>frame.drinkAt')],
         'ordinary drinking equality or priority changed'),
        ('ordinary priority', [('if frame.waterAllowed and frame.thirst>=frame.drinkAt then',
          'if false and frame.waterAllowed and frame.thirst>=frame.drinkAt then')],
         'ordinary drinking equality or priority changed'),
        ('shared admission', [('if f.waterAllowed and water>=0.72 then', 'if water>=0.72 then')],
         'inadmissible goal selected'),
        ('anticipation', [('if f.foodAllowed and food>=0.72 then', 'if f.foodAllowed and food>=1 then')],
         'associative anticipation missing'),
        ('private frame', [('if not validFrame(frame) then return nil,"private-frame" end', '')],
         'foreign model output admitted'),
        ('state identity', [('state.modelId==id', 'true')], 'foreign model state admitted'),
        ('shared belief table', [
          ('return { modelId=modelId, version=VERSION[modelId], revision=0, nextBelief=0,',
           'M.__shared=M.__shared or {}\n    return { modelId=modelId, version=VERSION[modelId], revision=0, nextBelief=0,'),
          ('nextHypothesis=0, beliefs={}, beliefOrder={}, hypotheses={},',
           'nextHypothesis=0, beliefs=M.__shared, beliefOrder={}, hypotheses={},')],
         'model states share evidence storage'),
        ('foreign actor', [('if state.actorId and state.actorId~=frame.actorId then return nil,"foreign-actor" end', '')],
         'foreign actor proposal admitted'),
        ('query self-amplification', [('local p=predictions(state,modelId=="associative",frame.worldHours)',
           'state.revision=state.revision+1\n    local p=predictions(state,modelId=="associative",frame.worldHours)')],
         'query or elapsed time strengthened beliefs'),
        ('repeated evidence', [('if state.seen[e.id] then return "ignored:duplicate" end', '')],
         'duplicate outcome was not recognized'),
        ('censored outcome', [('if e.status=="interrupted" or e.status=="unavailable" then return nil,"censored-access-or-interruption" end', '')],
         'censored access or absent measure became counterevidence'),
        ('private relief leak', [
          ('elseif e.hungerDelta~=nil or e.thirstDelta~=nil\n        or e.foodPresent~=nil or e.waterPresent~=nil\n        or (e.kind~="acquire" and e.kind~="store") then return false end',
           'elseif false then return false end')],
         "other person's private relief leaked"),
        ('zero relief', [('return e.category,delta>0', 'return e.category,delta>=0')],
         'zero native relief became success'),
        ('ignore outcomes', [('local direct=state.beliefs["goal:"..goal]', 'local direct=nil')],
         'authenticated witnessed transfer was discarded'),
        ('inspection emptiness', [('return "inspect",true', 'return "inspect",e.foodPresent==true or e.waterPresent==true')],
         'empty inspection mislabeled as failed observation'),
        ('semantic transfer', [('if contain or waterContain then', 'if false then')],
         'container experience did not transfer information value'),
        ('composition', [('a.into==b.from', 'false')], 'distinct observed links did not compose'),
        ('unsupported certainty', [('confidence=confidence*(0.55^(depth-1))', 'confidence=1'),
                                  ('confidence=confidence*(0.55^(h.depth-1))', 'confidence=1')],
         'cross-domain conjecture missing or overconfident'),
        ('depth limit', [('for depth=2,maxDepth do', 'for depth=2,4 do'),
                         ('limit=math.min(maxDepth,#bases+', 'limit=math.min(4,#bases+')],
         'configured depth bound bypassed'),
        ('counterexample erasure', [('b.support>0 and "refined" or "falsified"', 'b.support>0 and "supported" or "falsified"')],
         'counterexample erased provenance or failed to refine'),
        ('mutable summary', [('evidenceIds=copyList(h.evidenceIds,8),parentIds=', 'evidenceIds=h.evidenceIds,parentIds=')],
         'summary aliases evidence or hypothesis state'),
        ('state capacity', [('local MAX_BELIEFS, MAX_HYPOTHESES, MAX_EVENTS = 32, 32, 256',
          'local MAX_BELIEFS, MAX_HYPOTHESES, MAX_EVENTS = 96, 32, 256')],
         'state or receipt history unbounded'),
        ('old receipt replay', [('if e.worldHours<=state.evictedThroughHours then return "ignored:evicted-evidence-frontier" end', '')],
         'evicted evidence relearned as new'),
        ('fixed ladder', [('limit=math.min(maxDepth,#bases+((#bases>=3 and relevantContext) and 1 or 0))',
                          'limit=maxDepth')], 'repeated single action unlocked a fixed hypothesis ladder'),
        ('irrelevant evidence', [('if left==b.from or left==b.into then return true end', 'return true')],
         'unrelated object outcome escalated another association'),
        ('confidence aging', [('local weight=0.5^(math.max(0,hours-sample.hours)/CONFIDENCE_HALF_LIFE_HOURS)',
                              'local weight=1')], 'aging altered receipts or failed to reduce certainty'),
        ('future horizon', [('if state.lastHours and frame.worldHours<state.lastHours then return nil,"future-evidence" end', '')],
         'future evidence entered past prediction'),
        ('frame identity bound', [('not text(f.id,128)', 'not text(f.id,160)')],
         'overlong frame identity admitted'),
        ('known count bound', [(' or f[key]>100000', '')], 'unbounded known count admitted'),
        ('source identity bound', [('not text(e[key],160)', 'not text(e[key],256)')],
         'overlong source identity admitted'),
        ('late capability context', [('e.capabilities and (not state.capabilityHours or e.worldHours>=state.capabilityHours)',
                                     'e.capabilities')], 'late evidence rewound capability context'),
        ('discard contradicted path', [('if counterevidence then', 'if false then')],
         'contradicted derived branch lost its identity'),
        ('renewed branch identity', [('local id=previous and previous.id',
                                   'local id=previous and previous.active~=false and previous.id')],
         'renewed support invented a fresh branch identity'),
        ('erase refutation history', [('previous and previous.revisions or {}', '{}')],
         'branch refutation history was erased'),
        ('held interpretation', [('h.active~=false and h.status~="falsified"', 'h.status~="falsified"')],
         'held branch was used as current interpretation'),
        ('unbounded revision history', [('if #h.revisions>8 then', 'if false then')],
         'refutation history exceeded its bound or lost identity'),
        ('plan exact evidence retention', [('    rememberPlanEvidence(state, e, yes)', '')],
         'exact acquisition did not change relative plan order'),
        ('plan specific expectation influence', [('adjustment = predicted.adjustment', 'adjustment = 0')],
         'exact acquisition did not change relative plan order'),
        ('plan exact source isolation', [('c.sourceId ~= nil and b.sourceId == c.sourceId', 'c.sourceId ~= nil')],
         'exact acquisition did not change relative plan order'),
        ('plan exact item isolation', [('(c.itemType == nil or b.itemType == c.itemType\n                or modelId=="associative" and c.kind=="study" and b.sourceId==c.sourceId)', 'true'),
                                       ('(c.itemType==nil or b.itemType==c.itemType)', 'true')],
         'another item type became exact acquisition evidence'),
        ('plan private actor', [('if state.actorId and state.actorId ~= context.actorId then return false end', '')],
         'foreign actor plan prediction admitted'),
        ('plan current state clock', [('if state.lastHours ~= nil and (not finite(state.lastHours) or state.lastHours > context.atHours) then return false end', '')],
         'future state entered plan prediction'),
        ('plan current receipt clock', [('or sample.hours < 0 or sample.hours > context.atHours or type(sample.yes)',
                                         'or sample.hours < 0 or type(sample.yes)')],
         'future receipt entered plan prediction'),
        ('plan query clock aging', [('local weight = 0.5 ^ ((context.atHours - sample.hours) / CONFIDENCE_HALF_LIFE_HOURS)',
                                    'local weight = 1')],
         'plan evidence did not age at query clock'),
        ('plan weaker preparation transfer', [('return transfer, "related-experience", 0.45',
                                               'return transfer, "related-experience", 1')],
         'related preparation failed to transfer with lower confidence'),
        ('plan current capability prior', [('if c.kind == "prepare" and context.capabilities and context.capabilities.cook == true then',
                                           'if false then')],
         'current capability prior invented experience or certainty'),
        ('plan duplicate identity', [('or ids[candidate.id] then', 'then')],
         'duplicate plan identity admitted'),
        ('plan measured inspection contents', [('retain("inspect", "food", e.foodPresent)',
                                                'retain("inspect", "food", true)')],
         'empty inspection became successful food discovery'),
        ('plan owner influence cap', [('adjustment = math.max(-candidate.maxAdjustment, math.min(candidate.maxAdjustment, adjustment))',
                                      'adjustment = adjustment')],
         'plan adjustment cap changed belief or exceeded owner bound'),
        ('plan query mutation', [('local result = {schema="sao-plan-prediction/1", predictions={}, expectedValue=0, adjustment=0}',
                                 'state.revision=state.revision+1\n    local result = {schema="sao-plan-prediction/1", predictions={}, expectedValue=0, adjustment=0}')],
         'plan query trained or aged stored facts'),
        ('plan consequence bounds', [('not boundedArray(candidate.consequences, 4)',
                                      'not boundedArray(candidate.consequences, 8)')],
         'unbounded consequence list admitted'),
    ]
    unknown = set(args.control) - {name for name, _, _ in controls}
    if unknown:
        parser.error('unknown controls: ' + ', '.join(sorted(unknown)))
    selected = [control for control in controls if not args.control or control[0] in args.control]
    receipt = {'schema': 'sao-cognitive-model-proof/1', 'inputs': inputs,
               'engine': fingerprint(engine), 'controls': [], 'boundary': __doc__.strip(),
               'selectedControls': [name for name, _, _ in selected] if not args.baseline_only else [],
               'partialControls': bool(args.control) or args.baseline_only}
    faults = []
    with tempfile.TemporaryDirectory(prefix='sao-cognitive-models-') as temporary:
        work = Path(temporary)
        receipt['runner'] = runner_input
        shutil.copy2(GAME / 'stdlib.lua', work / 'stdlib.lua')
        subprocess.run([str(JDK / 'javac.exe'), '-cp', str(engine), '-d', str(work), str(runner)],
                       check=True, capture_output=True, text=True, timeout=120)
        (work / 'checks.lua').write_text(checks, encoding='utf-8')

        def run(candidate):
            (work / 'model.lua').write_text(candidate, encoding='utf-8')
            result = subprocess.run([str(JDK / 'java.exe'), '-cp', str(engine) + ';.', 'LuaRun',
                                     str(work / 'model.lua'), str(work / 'checks.lua'), '--', 'cognitiveModelCases()'],
                                    cwd=work, capture_output=True, text=True, timeout=60)
            lines = [line for line in result.stdout.splitlines() if line.startswith(('VALUE ', 'ERROR '))]
            return result.returncode, '\n'.join(lines) or (result.stdout + result.stderr)[-2000:]

        code, result = run(source)
        print('BASELINE', code, result, flush=True)
        receipt['baseline'] = {'exit': code, 'result': result}
        if code or result != 'VALUE PASS 43 cases':
            faults.append('production baseline')
        if not faults and not args.baseline_only:
            for name, changes, expected in selected:
                changed = source
                for old, new in changes:
                    if changed.count(old) != 1:
                        raise AssertionError('non-unique mutation seam: ' + name)
                    changed = changed.replace(old, new, 1)
                code, result = run(changed)
                rejected = code != 0 and result.startswith('ERROR ') and expected in result
                print('CONTROL', name, 'REJECTED' if rejected else 'FAILED', result, flush=True)
                receipt['controls'].append({'name': name, 'expected': expected, 'exit': code,
                                            'result': result, 'rejected': rejected})
                if not rejected:
                    faults.append(name)
    receipt['verdict'] = 'FAIL' if faults else 'PASS'
    receipt['faults'] = faults
    receipt['baselineOnly'] = args.baseline_only
    receipt['inputsUnchanged'] = receipt['inputs'] == [fingerprint(MODULE), fingerprint(CASES), fingerprint(Path(__file__))]
    if not receipt['inputsUnchanged']:
        faults.append('source drift')
        receipt['verdict'] = 'FAIL'
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(receipt['verdict'] + ' -- independent cognitive models', flush=True)
    return bool(faults)


if __name__ == '__main__':
    raise SystemExit(main())
