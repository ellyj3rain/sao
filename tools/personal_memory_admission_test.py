#!/usr/bin/env python3
"""Installed Kahlua admission/reload proof, with controlled identity, History and Neuro.

Executes real PopulationAdmissions and PersonalMemory, actual generated ID
binding and installed table serialization. No loaded game, corpus grounding,
psychiatric calibration or learned-policy claim.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'admissions': ROOT / 'mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua',
    'memory': ROOT / 'mod/42.20/media/lua/shared/SAO_PersonalMemory.lua',
    'cases': ROOT / 'tools/personal_memory_admission_cases.lua',
    'study': ROOT / 'tools/world_lab/StudyWorld.lua',
}
PROBE = ROOT / 'tools/luacheck/PhysicalMeansLuaProbe.java'

def run(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '_scratch/d1-shared-reasoning/personal-memory/admission-proof')
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args(argv)
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    jar = fixture.GAME / 'projectzomboid.jar'
    paths = [*FILES.values(), Path(__file__), PROBE, Path(fixture.__file__), jar, fixture.GAME / 'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "personal memory admission")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins(): return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt = {'schema': 'sao.personal-memory-admission-proof/1', 'status': 'INCOMPLETE',
               'boundary': __doc__, 'inputs': pins(), 'runs': []}
    def save(): (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    def invoke(name, command, marker=None):
        process = subprocess.run(list(map(str, command)), cwd=out, capture_output=True, text=True, timeout=90)
        log = process.stdout + process.stderr
        (out / (name + '.log')).write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name': name, 'exit': process.returncode, 'command': list(map(str, command)),
                               'expectedFailure': marker, 'logSha256': hashlib.sha256(log.encode()).hexdigest()})
        save(); return process.returncode, log
    save()
    try:
        classes = out / 'classes'; classes.mkdir(exist_ok=True)
        code, log = invoke('compile', [fixture.JDK / 'javac.exe', '-cp', jar, '-d', classes, PROBE])
        assert code == 0, log
        shutil.copy2(fixture.GAME / 'stdlib.lua', out / 'stdlib.lua')
        sources = {k: p.read_text(encoding='utf-8') for k, p in FILES.items()}
        variants = [('production', None, None, None, None)]
        if not args.baseline_only:
            variants += [
                ('native-date-ignored', 'admissions', 'or row.startDate~=startDate or not awarenessArray(row.episodes,64)',
                 'or not awarenessArray(row.episodes,64)', 'native-start-date-authority'),
                ('history-birth-ignored', 'admissions', 'if not ok or birth~=target.birthYear then return {} end',
                 'if not ok then return {} end', 'history-mismatch-withheld'),
                ('ordinal-binding-removed', 'admissions', 'row.siteId==siteId and row.actorOrdinal==ordinal',
                 'row.siteId==siteId and row.actorOrdinal==1', 'ordinal-ledger-binding'),
                ('source-content-pin-removed', 'admissions', '        or not awarenessEqual(staged.rows,memorySourcePins.rows)\n',
                 '', 'altered-saved-source-withheld'),
                ('study-producer-removed', 'study', 'local lifeHistory = Config.situation and Config.situation.initialLifeHistory',
                 'local lifeHistory = nil', 'actual-study-start-stages-memory'),
                ('configuration-phase-clock-ordered', 'admissions', 'or not awarenessTime(staged.stagedAtHours) or not awarenessTime(now)',
                 'or not awarenessTime(staged.stagedAtHours) or staged.stagedAtHours>now or not awarenessTime(now)',
                 'replay-rebase-attaches-memory'),
                ('replay-rebind-clock-ordered', 'admissions', '            or not awarenessTime(prior.stagedAtHours)\n',
                 '            or not awarenessTime(prior.stagedAtHours) or prior.stagedAtHours>now\n',
                 'replay-rebind-before-genesis'),
            ]
        for name, key, before, after, marker in variants:
            current = dict(sources)
            if before:
                assert current[key].count(before) == 1, (name, 'mutation anchor', current[key].count(before))
                current[key] = current[key].replace(before, after, 1)
            directory = out / name; directory.mkdir(exist_ok=True)
            owners = 'function __loadOwners()\n'
            for part, source in [('memory', current['memory']), ('admissions', current['admissions'])]:
                owners += 'local function load_' + part + '()\n' + source + '\nend\nload_' + part + '()\n'
            owners += 'end\nfunction __loadStudy(Config)\n' + current['study'] + '\nend\n'
            (directory / 'owners.lua').write_text(owners, encoding='utf-8')
            (directory / 'cases.lua').write_text(sources['cases'], encoding='utf-8')
            code, log = invoke(name, [fixture.JDK / 'java.exe', '-cp', os.pathsep.join([str(jar), str(classes)]),
                'PhysicalMeansLuaProbe', directory / 'owners.lua', directory / 'cases.lua', '--', '__result'], marker)
            if marker: assert code != 0 and 'MEMORY_ADMISSION:' + marker in log, (name, log)
            else: assert code == 0 and 'VALUE PASS personal memory admission ' in log, (name, log)
            print(name + ': ' + log.strip().splitlines()[-1], flush=True)
        receipt['inputsAfter'] = pins()
        assert receipt['inputsAfter'] == receipt['inputs'], 'proof inputs changed during run'
        receipt['status'] = 'PASS'; save()
    except Exception as error:
        receipt['status'] = 'FAIL'; receipt['error'] = str(error); save(); raise
    return 0

if __name__ == '__main__':
    try: raise SystemExit(run())
    except Exception as error:
        print('FAIL personal memory admission: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
