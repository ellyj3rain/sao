#!/usr/bin/env python3
"""D3.12 installed recipe reading through actual named native knowledge.

Production Study, installed ISReadABook and queue execute in native Kahlua.
Installed script definitions/Literature and the real shell ReadLiterature/
isRecipeActuallyKnown methods supply metadata and effects. Actor, animation,
clock, sounds/network and declared Planner callback receivers are controlled.
The separate integrated gate proof owns real gate planning/build/use.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'tools/native_proof_preflight.py'
if not HELPER.is_file():
    print('FAILED D3.12 recipe reading: owned proof inputs absent: ' + str(HELPER)); raise SystemExit(1)
from native_proof_preflight import presence, causal_controls, installed_path
GAME = installed_path(os.environ.get('PZ_DIR', r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK = installed_path(os.environ.get('JDK_BIN', r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
STUDY = ROOT / 'mod/42.20/media/lua/client/SAO_Study.lua'
PROBE = ROOT / 'tools/resource_production_checks/RecipeReadingNativeProbe.java'
CASES = ROOT / 'tools/resource_production_checks/recipe_reading_cases.lua'
BASE = ROOT / 'tools/luacheck/window_repair_cases.lua'
BOARD = ROOT / 'tools/luacheck/d3_native_boarding_cases.lua'
METADATA = ROOT / 'tools/d2_leisure_materials/metadata.java.inc'
NATIVE = [GAME / p for p in [
    'media/lua/shared/ISBaseObject.lua', 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    'media/lua/client/TimedActions/ISTimedActionQueue.lua', 'media/lua/shared/TimedActions/ISReadABook.lua']]
HELPERS = [ROOT / 'tools/luacheck' / p for p in ['MovementCrossingProbe.java', 'LuaSyntax.java']]
JAR = ROOT / 'mod/42.20/media/java/SAO.jar'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--required', action='store_true')
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args()
    owned = [Path(__file__), HELPER, STUDY, PROBE, CASES, BASE, BOARD, METADATA, *HELPERS, JAR]
    installed = [*NATIVE, GAME / 'media/scripts/generated/items/literature.txt', GAME / 'projectzomboid.jar',
                 GAME / 'ZombieBuddy.jar', GAME / 'stdlib.lua', JDK / 'java.exe', JDK / 'javac.exe']
    absent = presence(owned, installed, args.required, 'D3.12 recipe reading')
    if absent is not None:
        return absent
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    jars = [JAR, GAME / 'projectzomboid.jar', GAME / 'ZombieBuddy.jar', *sorted((GAME / 'jars').glob('*.jar'))]
    inputs = list(dict.fromkeys(owned + installed + jars))
    raw_inputs = [p for p in owned if p != JAR]
    receipt = {'schema': 'sao-d312-recipe-reading/1', 'status': 'INCOMPLETE', 'boundary': __doc__,
               'productionFiles': [STUDY.relative_to(ROOT).as_posix()],
               'instrumentFiles': [p.relative_to(ROOT).as_posix() for p in raw_inputs if p != STUDY],
               'sourcePins': {p.relative_to(ROOT).as_posix(): sha(p) for p in raw_inputs},
               'compiledInputs': {JAR.relative_to(ROOT).as_posix(): sha(JAR)},
               'nativeInputs': {p.as_posix(): sha(p) for p in list(dict.fromkeys(installed + jars)) if p != JAR},
               'inputsBefore': {p.as_posix(): sha(p) for p in inputs}, 'runs': [], 'controls': [],
               'reusedEvidence': 'Existing native action/queue fixtures, installed metadata loader and crossing-shell boot are unchanged. Ordinary study/leisure and generator producer regressions receive separate selected runs.',
               'unverified': ['Rendered play', 'native server execution', 'actual integrated gate Planner/Controller; owned by coupled gate proof']}
    def save():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def run(name, command, work):
        done = subprocess.run(list(map(str, command)), cwd=work, capture_output=True, timeout=90)
        log = out / (name + '.log'); log.write_bytes(done.stdout + done.stderr)
        receipt['runs'].append({'name': name, 'command': list(map(str, command)), 'exitCode': done.returncode,
                                'log': log.name, 'logSha256': sha(log)})
        save()
        return done.returncode, log.read_text(encoding='utf-8', errors='replace')
    save()
    try:
        metadata = METADATA.read_text()
        anchor = 'definition.Load(name,text.substring(match.start(),end));'
        assert metadata.count(anchor) == 1
        metadata = metadata.replace(anchor, 'var modField=ScriptManager.class.getDeclaredField("currentLoadFileMod");modField.setAccessible(true);Object oldMod=modField.get(null);modField.set(null,"fixture-installed-source");try{definition.setModID("fixture-installed-source");definition.InitLoadPP(name);' + anchor + '}finally{modField.set(null,oldMod);}', 1)
        generated = out / PROBE.name; generated.write_text(PROBE.read_text().replace('    METADATA', metadata, 1))
        receipt['compiledInputs']['generatedProbe'] = {'file': generated.name, 'sha256': sha(generated)}
        with tempfile.TemporaryDirectory(prefix='sao-recipe-reading-') as temporary:
            work = Path(temporary); shutil.copy2(GAME / 'stdlib.lua', work / 'stdlib.lua')
            cp = os.pathsep.join(map(str, jars))
            code, log = run('compile', [JDK / 'javac.exe', '-encoding', 'UTF-8', '-cp', cp, '-d', work, *HELPERS, generated], work)
            assert code == 0, log
            code, log = run('syntax', [JDK / 'java.exe', '-cp', str(work) + os.pathsep + cp, 'LuaSyntax', STUDY, CASES], work)
            assert code == 0, log
            chunks = {'base.lua': BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()', 1)[0],
                      'boarding-fixture.lua': BOARD.read_text(encoding='utf-8-sig') + '\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n'}
            chunks.update({'native-' + str(i) + '.lua': p.read_text(encoding='utf-8-sig') for i, p in enumerate(NATIVE)})
            chunks['reading-fixture.lua'] = CASES.read_text(encoding='utf-8-sig')
            chunks['study.lua'] = STUDY.read_text(encoding='utf-8-sig')
            def execute(name, variant, entry):
                directory = out / name; directory.mkdir(); paths = []
                for filename, source in variant.items():
                    path = directory / filename; path.write_text(source, encoding='utf-8'); paths.append(path)
                path = directory / 'run.lua'; path.write_text(entry); paths.append(path)
                return run(name, [JDK / 'java.exe', '--enable-native-access=ALL-UNNAMED', '-Duser.home=' + str(work),
                                 '-Djava.awt.headless=true', '-cp', str(work) + os.pathsep + cp,
                                 'RecipeReadingNativeProbe', GAME, *paths], work)
            code, log = execute('baseline', chunks, '__runRecipeReadingCases()')
            checks = dict(re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$', log, re.M)); receipt['checks'] = checks; save()
            marker = re.search(r'^PASS recipe reading (\d+)$', log, re.M)
            assert code == 0 and marker and len(checks) == int(marker[1]) and len(checks) >= 60 and all(v == 'true' for v in checks.values()), log[-14000:]
            if not args.baseline_only:
                mutations = [
                    ('native-effect', [('local result=ISReadABook.complete(self)', 'local result=true')], 'native_named_knowledge_effect'),
                    ('completion-progress', [('or not self.action or self:getJobDelta()<1', 'or not self.action')], 'partial_completion_refused'),
                    ('exact-purpose-recipe', [('and (w.kind=="generator-reading" or s.recipeName==w.recipeName and s.target==w.recipeName)', '')], 'changed_recipe_identity_refused'),
                    ('native-validity', [('and ISReadABook.isValid(a)', '')], 'native_darkness_after_start_refused'),
                    ('native-knowledge-measurement', [('or not rt.body:isRecipeActuallyKnown(learnedRecipe(w))', 'or false'),
                                                     ('recipeKnown=status=="completed" and rt.body:isRecipeActuallyKnown(learnedRecipe(w)) or false', 'recipeKnown=status=="completed"')], 'native_complete_without_learning_refused'),
                    ('pending-ack', [('or not rt.ack or queued(rt.action)', 'or false'), ('or rt.queue.current==rt.action or hours()<w.beganAt', 'or hours()<w.beganAt')], 'pending_ack_retained'),
                    ('saved-runtime-retirement', [('if a.action then a:forceStop() else a:forceCancel() end', 'if false then a:forceStop() else a:forceCancel() end')], 'saved_native_ack_no_learning'),
                    ('exact-current-queue', [('or not current() and not (rt.ack and not rt.queue.current and #rt.queue.queue==0)', 'or false')], 'replacement_queue_preserved'),
                ]
                for name, replacements, detector in mutations:
                    variant = dict(chunks)
                    for old, new in replacements:
                        assert variant['study.lua'].count(old) == 1, (name, old, variant['study.lua'].count(old))
                        variant['study.lua'] = variant['study.lua'].replace(old, new, 1)
                    code, log = execute(name, variant, "__runRecipeReadingControl('" + detector + "')")
                    detected = code == 0 and 'CHECK ' + detector + '=false' in log
                    receipt['controls'].append({'name': name, 'detector': detector, 'detected': detected}); save()
                    assert detected, (name, log[-4000:])
                receipt['preflightControls'] = causal_controls(ROOT, Path(__file__), owned,
                    child_args=['--out', 'proof'], missing_owned=PROBE)
            receipt['inputsAfter'] = {p.as_posix(): sha(p) for p in inputs}
            receipt['sourcePreserved'] = receipt['inputsBefore'] == receipt['inputsAfter']
            assert receipt['sourcePreserved'], 'qualified input changed during proof'
            receipt['status'] = 'PASS'; save()
            print('PASS D3.12 recipe reading: ' + str(len(checks)) + ' checks, ' + str(len(receipt['controls'])) + ' detecting controls')
            print(out / 'receipt.json')
            return 0
    except Exception as error:
        receipt['status'] = 'FAIL'; receipt['error'] = str(error); save()
        print('FAIL D3.12 recipe reading: ' + str(error)[-14000:]); return 1

if __name__ == '__main__':
    raise SystemExit(main())
