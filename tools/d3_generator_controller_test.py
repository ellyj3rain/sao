#!/usr/bin/env python3
"""D3.6 private generator continuation through actual planning and Controller.

Installed Kahlua executes P, Labor, both interpreters, Cooking, and extracted
production Controller decision/dispatch functions. Generator, manual reading,
SourceUse, body/map and thermal receivers are controlled canonical boundaries;
the separate native generator instrument establishes engine effects/custody.
"""
from pathlib import Path
from hashlib import sha256
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'tools/native_proof_preflight.py'
# Preserve mandatory owned validation even when the engine/helper is absent.
if not HELPER.is_file():
    print('FAILED generator Controller: owned proof inputs absent: ' + str(HELPER))
    raise SystemExit(1)
from native_proof_preflight import presence, causal_controls, installed_path

GAME = installed_path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = installed_path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA = ROOT / 'mod/42.20/media/lua'
P = LUA / 'shared/SAO_ProceduralPlanning.lua'
LABOR = LUA / 'shared/SAO_Labor.lua'
CTL = LUA / 'client/SAO_Controller.lua'
MODELS = LUA / 'shared/SAO_CognitiveModels.lua'
COGNITION = LUA / 'shared/SAO_Cognition.lua'
COOKING = LUA / 'client/SAO_Cooking.lua'
CASES = ROOT / 'tools/luacheck/d3_generator_controller_cases.lua'
PRELUDE = ROOT / 'tools/cooking_checks/prelude.lua'
RUNNER = ROOT / 'tools/luacheck/LuaRun.java'
OWNED = [Path(__file__), HELPER, P, LABOR, CTL, MODELS, COGNITION, COOKING, CASES, PRELUDE, RUNNER]
NATIVE = [GAME / p for p in ['projectzomboid.jar', 'stdlib.lua',
    'media/lua/shared/ISBaseObject.lua', 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    'media/lua/shared/TimedActions/ISToggleStoveAction.lua']]
COUNT = 33
CONTROL_NAMES = ['omit-terminal-admission-retirement', 'omit-source-revision', 'omit-generator-authority',
                 'omit-manual-native-knowledge', 'omit-supplier-coverage', 'omit-original-meal-resume',
                 'restore-long-utility-candidate-id', 'retain-fulfilled-power-demand', 'clear-unrelated-power-demand',
                 'omit-powered-meal-return', 'omit-rejected-generator-context', 'retain-superseded-meal-request']


def controller(source):
    def section(begin, end):
        assert source.count(begin) == 1 and source.count(end) == 1, (begin, end)
        return begin + source.split(begin, 1)[1].split(end, 1)[0]
    resource = section('function Ctl.resourceContext', '-- This read-only preflight')
    travel = section('local function orderTravelState', 'local function startNearbyCollection')
    generator = section('function Ctl.generatorContext', '-- Retained private prerequisites')
    begin = '        if Ctl.resumePoweredMeal(id, agent, body, tick) then return end'
    end = '        if Ctl.advanceResidencePurpose(id, agent, body, tick) then return end'
    assert source.count(begin) == 1 and source.count(end) == 1
    idle = begin + source.split(begin, 1)[1].split(end, 1)[0]
    return ('local Ctl=SAO.Controller\nlocal tickCount=0\n'
            'local setState=function(agent,id,state,reason) agent.state=state;agent.reason=reason;return true end\n'
            + travel + resource + generator + '\nfunction Ctl.testUtilityIdle(id,agent,body,tick,needs)\n'
            'tickCount=tick\n' + idle + '\n__ordinaryResourceTurns=(__ordinaryResourceTurns or 0)+1\nend\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--required', action='store_true')
    parser.add_argument('--controls', choices=['selected', 'none'], default='selected')
    parser.add_argument('--control', action='append', choices=CONTROL_NAMES,
                        help='execute only named motivating controls; repeat to select several')
    args = parser.parse_args()
    if args.control and args.controls == 'none':
        parser.error('--control requires --controls selected')
    absent = presence(OWNED, NATIVE + [JDK/'java.exe', JDK/'javac.exe'], args.required, 'generator Controller')
    if absent is not None:
        return absent
    temporary = tempfile.TemporaryDirectory(prefix='sao-generator-controller-') if args.out is None else None
    out = Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists():
        raise ValueError('refuse replacing retained evidence: ' + str(out))
    out.mkdir(parents=True)
    classes = out/'classes'
    classes.mkdir()
    inputs = OWNED + NATIVE
    pins = {str(p): sha256(p.read_bytes()).hexdigest() for p in inputs}
    shutil.copy2(GAME/'stdlib.lua', out/'stdlib.lua')
    bootstrap = out/'bootstrap.lua'
    bootstrap.write_text('SAO.Controller={agents={}}\n', encoding='utf-8')
    compilation = subprocess.run([str(JDK/'javac.exe'), '-cp', str(NATIVE[0]), '-d', str(classes), str(RUNNER)],
                                 capture_output=True, text=True, timeout=60)
    (out/'compile.log').write_text(compilation.stdout+compilation.stderr)
    sources = {p: p.read_text(encoding='utf-8-sig') for p in [MODELS, COGNITION, LABOR, P, COOKING, CTL]}
    runs = []
    cli = None
    def execute(label, changes=()):
        changed = dict(sources)
        for path, before, after in changes:
            if changed[path].count(before) != 1:
                raise RuntimeError('mutation anchor must occur exactly once: ' + label + ': ' + before)
            changed[path] = changed[path].replace(before, after, 1)
        paths = []
        for path, content in changed.items():
            target = out/(label+'-'+path.name)
            target.write_text(controller(content) if path == CTL else content, encoding='utf-8')
            paths.append(target)
        result = subprocess.run([str(JDK/'java.exe'), '-cp', str(classes)+os.pathsep+str(NATIVE[0]),
            'LuaRun', str(PRELUDE), *[str(p) for p in NATIVE[2:]], str(bootstrap), *[str(p) for p in paths], str(CASES),
            '--', '__generatorControllerResults'], cwd=out, capture_output=True, text=True, timeout=60)
        (out/(label+'.log')).write_text(result.stdout+result.stderr)
        checks = dict(re.findall(r'^([a-z0-9_]+)=(true|false)$', result.stdout.replace('VALUE ', ''), re.M))
        runs.append({'name':label, 'exit':result.returncode, 'checks':checks})
        if result.returncode or len(checks) != COUNT:
            raise RuntimeError(label + ': exit=' + str(result.returncode) + ' checks=' + str(len(checks))
                               + ' tail=' + (result.stdout+result.stderr)[-2500:])
        return checks
    try:
        if compilation.returncode:
            raise RuntimeError('Java runner compile failed: ' + compilation.stderr[-1500:])
        checks = execute('candidate')
        if any(v != 'true' for v in checks.values()):
            raise RuntimeError('false candidate checks: ' + ', '.join(k for k,v in checks.items() if v != 'true'))
        controls = [
            ('retain-superseded-meal-request', P,
             'purpose.generatorPower[field] = dataCopy(intent[field])',
             'purpose.generatorPower[field] = purpose.generatorPower[field]',
             'newer_same_consumer_meal_rebinds_retained_utility_and_resumes'),
            ('omit-powered-meal-return', CTL,
             'if consumer and SAO.WorldSources.generatorConsumerObject',
             'if false and SAO.WorldSources.generatorConsumerObject', 'displaced_powered_meal_returns_before_exact_cooking'),
            ('omit-rejected-generator-context', CTL,
             'intent.rejectedGenerators = retained.generatorPower.rejectedGenerators',
             'intent.rejectedGenerators = nil', 'coverage_rejection_releases_pinned_generator_in_context'),
            ('omit-terminal-admission-retirement', P,
             'or purpose.leisureAcquisition or purpose.generatorPower then',
             'or purpose.leisureAcquisition then', 'query_inspection_without_native_attempt_advances_and_releases'),
            ('omit-source-revision', P,
             'if purpose.generatorPower and (authoritative.actorId ~= receipt.actorId',
             'if false and (authoritative.actorId ~= receipt.actorId', 'wrong_source_revision_cannot_acquire'),
            ('omit-generator-authority', P,
             'or step.owner == "SAO.Generator" and authority ~= GENERATOR_RESULT',
             'or false', 'caller_completion_cannot_advance_generator'),
            ('omit-manual-native-knowledge', P,
             'or not finite(row.progress) or row.progress <= 0 or row.recipeKnown ~= true',
             'or not finite(row.progress) or row.progress <= 0', 'reading_without_native_recipe_cannot_advance'),
            ('omit-supplier-coverage', P,
             'if row.operation == "verify-power" and (row.sourceCovered ~= true or row.consumerPowered ~= true) then return false end',
             'if row.operation == "verify-power" and row.consumerPowered ~= true then return false end',
             'consumer_power_without_source_coverage_cannot_close'),
            ('omit-original-meal-resume', CTL,
             'local meal = SAO.ProceduralPlanning.poweredMeal(id)',
             'local meal = nil', 'final_power_resumes_exact_original_meal_without_backoff'),
            ('restore-long-utility-candidate-id', LABOR,
             'local row = { id = "generator:" .. tostring(index) .. ":" .. option.operation,',
             'local row = { id = "generator:" .. generator.sourceId .. ":" .. generator.revision .. ":" .. option.operation .. ":" .. tostring(option.inputItemId or "missing-input"),',
             'native_length_anchors_preserve_both_model_views_and_admission'),
            ('retain-fulfilled-power-demand', CTL,
             '        agent.rec.cookingPowerDemand=nil',
             '        agent.rec.cookingPowerDemand=demand', 'completed_original_meal_does_not_reopen_stale_power_goal'),
            ('clear-unrelated-power-demand', CTL,
             'if demand and demand.requestingPurposeId==meal.purposeId\n'
             '        and tostring(demand.foodItemId)==tostring(meal.foodItemId) and demand.foodItemType==meal.foodItemType\n'
             '        and demand.applianceSourceId==meal.applianceSourceId and type(demand.consumer)=="table"\n'
             '        and (demand.consumer.sourceId or demand.consumer.id)==meal.consumerId then',
             'if demand then', 'original_meal_resume_preserves_newer_unmet_power_request'),
        ]
        selected_controls = [control for control in controls if not args.control or control[0] in args.control]
        if args.controls == 'selected':
            for label,path,before,after,target in selected_controls:
                if execute(label, [(path,before,after)])[target] != 'false':
                    raise RuntimeError('undetected motivating control: '+label)
            child_args = ['--control', args.control[0]] if args.control else ['--controls','none']
            cli = causal_controls(ROOT, Path(__file__), OWNED, child_args, missing_owned=CASES)
            (out/'preflight-controls.json').write_text(json.dumps(cli,indent=2)+'\n')
        preserved = pins == {str(p):sha256(p.read_bytes()).hexdigest() for p in inputs}
        if not preserved:
            raise RuntimeError('proof inputs changed during execution')
        receipt = {'schema':'sao-d3.6-generator-controller/1', 'status':'PASS', 'cases':COUNT,
                   'controls':len(selected_controls) if args.controls=='selected' else 0,
                   'controlNames':[control[0] for control in selected_controls] if args.controls=='selected' else [],
                   'inputs':pins, 'sourcePreserved':preserved, 'runs':runs,
                   'preflightControls':cli is not None, 'boundary':__doc__}
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print(f'PASS generator Controller: {COUNT}/{COUNT} checks, {receipt["controls"]} executed controls')
        return 0
    except (AssertionError, RuntimeError, subprocess.TimeoutExpired) as error:
        (out/'receipt.json').write_text(json.dumps({'status':'FAIL','error':str(error),'inputs':pins,'runs':runs,
                                                   'boundary':__doc__},indent=2)+'\n')
        print('FAIL', error)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
