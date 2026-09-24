#!/usr/bin/env python3
"""Border 159: incomplete or unobserved simulations cannot become evidence."""
import copy
import contextlib
import datetime
import importlib.util
import io
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
from unittest import mock

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / 'sweep'))
import county_sweep as Sweep  # noqa: E402
import county_trajectory as Trajectory  # noqa: E402


def specimen():
    return {'ranTo': 90, 'yearsTicks': 90 * 216000, 'alive': 4, 'dead': 6, 'completed': True,
            'housesStanding': 1, 'biggestHouse': 4,
            'evidence': {'faultCount': 0, 'faults': {}, 'seed': 'Control:1996-6-8',
                         'callbackCounts': {'simulateDay': 90}}}


def rejects(call):
    try:
        call()
    except Sweep.EvidenceError:
        return True
    return False


def partial_probe(path):
    spec = importlib.util.spec_from_file_location('sweep_control', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    row = specimen()
    row['ranTo'] = 60
    try:
        module.validate_result(row, 90)
    except module.EvidenceError:
        return 0
    return 1


def observer_fixture(root):
    """Exercise actual roster, withdrawal and widow transitions in Kahlua."""
    if not (Sweep.PZ.is_file() and (Sweep.JDK / 'java.exe').is_file()):
        print('  observer VM fixture SKIPPED - installed game/JDK absent')
        return []
    spec = importlib.util.spec_from_file_location('observer_company_fixture',
                                                 HERE / 'company_forms_test.py')
    fixture = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixture)
    fixture.LUA = root / 'mod/42.20/media/lua'
    fixture.MODULES = list(fixture.MODULES) + [
        'shared/SAO_Organization.lua', 'shared/SAO_Recognition.lua',
        str(HERE / 'sweep/evidence.lua')]
    if not fixture.build():
        return ['observer fixture runner did not build']
    expression = r'''(function()
      local made = {}
      for i = 1, 3 do
        made[i] = SAO.Identity.create(nil, nil, 10500, 9000, 0)
        SAO.History.generate(made[i].id, made[i])
      end
      for i = 1, 3 do for j = 1, 3 do if i ~= j then
        SAO.Standing.adjustTrust(made[i].id, made[j].id, 0.85)
      end end end
      local evidence = SAOSweepEvidence.begin()
      _G.__hours = 10
      SAO.Standing.formCompany({ made[1].id, made[2].id }, 'observer-house')
      _G.__hours = 11
      SAO.Standing.formCompany({ made[1].id, made[2].id, made[3].id }, 'observer-house')
      _G.__hours = 12
      SAO.Standing.leaveGroup(made[3].id)
      _G.__hours = 13
      SAO.Identity.markDead(made[2], 0, 'observer-control')
      return evidence.finish()
    end)()'''
    try:
        report = json.loads(fixture.probe(expression))
    except (ValueError, OSError) as exc:
        return ['observer VM fixture failed: ' + str(exc)]
    house = report['companies'].get('observer-house', {})
    events = list(report['events'].values())
    faults = []
    if report['housesFounded'] != 1 or house.get('foundedHour') != 10:
        faults.append('existing-host append restarted a company lifetime')
    if house.get('maxSize') != 3 or house.get('endedHour') != 13:
        faults.append('transient maximum or exact dissolution hour was lost')
    if report['survivorsJoined'] != 1 or report['survivorsLeft'] != 3:
        faults.append('append, departure, death or election widow delta was missed')
    if len([e for e in events if e['kind'] == 'ended']) != 1:
        faults.append('nested mutations duplicated or missed company end')
    if report['snapshots']['0']['groups']:
        faults.append('observer final snapshot contradicts the actual empty roster')
    # Trust loss and the retired election verb do not remove anybody. A named
    # person withdraws through the process owner; lifecycle cleanup then frees
    # the remaining widow without manufacturing a successor.
    expression = r'''(function()
      local a = SAO.Identity.create(nil, nil, 10500, 9000, 0)
      local b = SAO.Identity.create(nil, nil, 10500, 9000, 0)
      SAO.Standing.adjustTrust(a.id, b.id, 0.85)
      SAO.Standing.adjustTrust(b.id, a.id, 0.85)
      local evidence = SAOSweepEvidence.begin()
      _G.__hours = 20
      SAO.Standing.formCompany({ a.id, b.id }, 'walkout-house')
      SAO.Standing.adjustTrust(a.id, b.id, -1.0)
      SAO.Standing.adjustTrust(b.id, a.id, -1.85)
      _G.__hours = 21
      local changed, _, why = SAO.Standing.electLeader('walkout-house')
      if changed ~= nil or SAO.Standing.groupSize('walkout-house') ~= 2
        or why ~= 'explicit-process-required' then
        error('retired election changed the roster')
      end
      local ok, process, left = pcall(SAO.Standing.withdrawFromCompany, a.id,
        'voluntary-separation', {}, 'dormant-encounter', {})
      if not ok then return 'withdraw-error:' .. tostring(process) end
      if not process or not left then return 'withdraw-refused' end
      return evidence.finish()
    end)()'''
    raw = fixture.probe(expression)
    try:
        report = json.loads(raw)
    except (ValueError, OSError):
        return faults + ['explicit withdrawal fixture failed: ' + raw]
    if (report['survivorsLeft'] != 2 or report['snapshots']['0']['groups']
            or report['companies']['walkout-house'].get('endedHour') != 21):
        faults.append('explicit withdrawal/widow transition was not observed')
    expression = r'''(function()
      local people = {}
      for i = 1, 4 do people[i] = SAO.Identity.create(nil, nil, 10500, 9000, 0) end
      for i = 1, 4 do for j = 1, 4 do if i ~= j then
        SAO.Standing.adjustTrust(people[i].id, people[j].id, 0.5)
      end end end
      local evidence = SAOSweepEvidence.begin()
      _G.__hours = 30
      SAO.Standing.formCompany({ people[1].id, people[2].id,
        people[3].id, people[4].id }, 'split-house')
      local core, ally = people[1].id, people[2].id
      SAO.Standing.setHostile(people[3].id, core, true)
      SAO.Standing.setHostile(core, people[3].id, true)
      SAO.Standing.adjustTrust(ally, core, 0.4)
      _G.__hours = 31
      local split, _, _, why = SAO.Standing.checkSchism('split-house')
      if split ~= nil or why ~= 'explicit-process-required'
        or SAO.Standing.groupSize('split-house') ~= 4 then
        error('hostility manufactured a schism')
      end
      local ok1, p1, left1 = pcall(SAO.Standing.withdrawFromCompany, core,
        'contested-separation', {}, 'dormant-encounter', {})
      local ok2, p2, left2 = pcall(SAO.Standing.withdrawFromCompany, ally,
        'contested-separation', {}, 'dormant-encounter', {})
      if not ok1 then return 'first-withdraw-error:' .. tostring(p1) end
      if not ok2 then return 'second-withdraw-error:' .. tostring(p2) end
      if not p1 or not p2 or not left1 or not left2 then
        error('explicit separations failed')
      end
      return evidence.finish()
    end)()'''
    raw = fixture.probe(expression)
    try:
        report = json.loads(raw)
    except (ValueError, OSError):
        return faults + ['explicit separation fixture failed: ' + raw]
    snapshot = report['snapshots']['0']
    splits = [h for name, h in report['companies'].items() if name.startswith('schism-')]
    if (report['housesFounded'] != 1 or report['survivorsLeft'] != 2
            or report['survivorsJoined'] != 0 or snapshot['groupSizes'] != {'2': 1}
            or len(splits) != 0
            or report['companies']['split-house'].get('foundedHour') != 30
            or report['companies']['split-house'].get('maxSize') != 4):
        faults.append('explicit separation or no-automatic-schism observation disagrees')
    # Calendar host uses the same start-minus-behind rule as SAORecord. Verify
    # real Lua reads across month, year and leap-day boundaries.
    fixture.MODULES = list(fixture.MODULES[:-1])
    owed = (datetime.date(1996, 3, 1) - Sweep.HISTORY_ORIGIN).days
    original_prelude = fixture.PRELUDE
    fixture.PRELUDE += '\n_G.__owed = %d\n' % owed + Sweep.evidence_host(owed)
    dates = [datetime.date(1993, 7, 9), datetime.date(1993, 8, 1),
             datetime.date(1994, 1, 1), datetime.date(1996, 2, 28),
             datetime.date(1996, 2, 29), datetime.date(1996, 3, 1)]
    queries = []
    for date in dates:
        hours = (date - Sweep.HISTORY_ORIGIN).days * 24
        queries.append('tostring(SAOJavaBridge:countyMonth(%d, false))' % hours)
    expression = '''(function()
      local gt = GameTime.getInstance()
      local out = { %s, tostring(gt:getStartYear()), tostring(gt:getStartMonth()),
        tostring(gt:getStartDay()), tostring(SAOJavaBridge:recordDayToday()) }
      _G.__hours = 24
      out[#out+1] = tostring(gt:getDay())
      out[#out+1] = tostring(SAOJavaBridge:recordDayToday())
      return table.concat(out, ',')
    end)()''' % ', '.join(queries)
    got = fixture.probe(expression).split(',')
    expected = [str(date.month - 1) for date in dates] + ['1996', '2', '0',
                str(owed), '1', str(owed + 1)]
    if got != expected:
        faults.append('exact Gregorian host boundary mismatch: %s != %s' % (got, expected))
    fixture.PRELUDE = original_prelude
    return faults


def main(root):
    faults = []
    lua = root / 'mod/42.20/media/lua'
    try:
        Sweep.require_modules(lua)
    except Sweep.EvidenceError as exc:
        print('159) FAULT:', exc)
        return 1
    # C65 option descriptors name their loaded executor. The dormant county
    # declares that absent owner; it neither loads a body driver nor hides an
    # undeclared dependency. Removing the declaration must restore refusal.
    _, loaded = Sweep.modules_referenced(lua)
    if 'SourceUse' in loaded:
        faults.append('dormant county silently acquired the loaded source executor')
    undeclared = dict(Sweep.NOT_DORMANT)
    undeclared.pop('SourceUse', None)
    with mock.patch.object(Sweep, 'NOT_DORMANT', undeclared):
        if not rejects(lambda: Sweep.require_modules(lua)):
            faults.append('undeclared source executor accepted')
    row = specimen()
    Sweep.validate_result(row, 90, True, {'names': 10, 'professions': 25}, True)
    cases = [('partial horizon', {'ranTo': 60}),
             ('frozen tick clock', {'yearsTicks': 0}),
             ('empty county', {'alive': 0, 'dead': 0}),
             ('swallowed callback', {'evidence': {'faultCount': 1, 'faults': {'nil': 1}}})]
    for name, changed in cases:
        bad = copy.deepcopy(row)
        bad.update(changed)
        if not rejects(lambda: Sweep.validate_result(bad, 90)):
            faults.append(name + ' accepted')
    if not rejects(lambda: Sweep.validate_result(row, 90, True, None)):
        faults.append('unverified engine pools accepted')
    bad = copy.deepcopy(row)
    bad['evidence']['callbackCounts']['simulateDay'] = 0
    if not rejects(lambda: Sweep.validate_result(bad, 90, joint=True)):
        faults.append('joint run without pathogen callbacks accepted')
    with tempfile.TemporaryDirectory() as tmp:
        absent = pathlib.Path(tmp) / 'lua'
        absent.mkdir()
        if not rejects(lambda: Sweep.require_modules(absent)):
            faults.append('missing modules accepted')
        # A single omitted dependency must be rejected, not silently filtered.
        shutil.copytree(lua, absent, dirs_exist_ok=True)
        omitted = absent / 'shared/SAO_Census.lua'
        omitted.unlink()
        if not rejects(lambda: Sweep.require_modules(absent)):
            faults.append('single missing Census module accepted')
        shutil.copy2(lua / 'shared/SAO_Census.lua', omitted)
        (absent / 'shared/SAO_BodySnapshot.lua').unlink()
        if not rejects(lambda: Sweep.require_modules(absent)):
            faults.append('single missing body snapshot dependency accepted')
        source = (HERE / 'county_sweep.py').read_text(encoding='utf-8')
        old = "if result.get('ranTo') != owed:"
        if source.count(old) != 1:
            faults.append('partial-horizon control did not locate its mutation')
        else:
            changed = source.replace(old, 'if False:  # control disables completion refusal')
            assert changed != source
            path = pathlib.Path(tmp) / 'county_sweep_control.py'
            path.write_text(changed, encoding='utf-8')
            baseline = subprocess.run([sys.executable, str(__file__), '--probe',
                                       str(HERE / 'county_sweep.py')], capture_output=True)
            control = subprocess.run([sys.executable, str(__file__), '--probe', str(path)],
                                      capture_output=True)
            if baseline.returncode != 0 or control.returncode != 1:
                faults.append('partial-horizon mutation did not flip subprocess verdict')
        # One failed seed refuses the whole collection, rather than exporting the other.
        with contextlib.redirect_stdout(io.StringIO()), mock.patch.object(Sweep, 'prepare'), \
                mock.patch.object(Sweep, 'one', side_effect=[copy.deepcopy(row), None]):
            if not rejects(lambda: Trajectory.run_trajectories([90], 2, lua=lua)):
                faults.append('failed seed accepted into aggregate')
        names = []
        def completed(name, _lua, owed, **kwargs):
            names.append(name)
            result = copy.deepcopy(row)
            result['ranTo'] = owed
            return result
        with contextlib.redirect_stdout(io.StringIO()), mock.patch.object(Sweep, 'prepare'), \
                mock.patch.object(Sweep, 'one', completed):
            Trajectory.run_trajectories([30, 90], 1, lua=lua, seed_prefix='Repeat')
        if names != ['Repeat000', 'Repeat000']:
            faults.append('horizon changed the recorded replicate label')
        proof = pathlib.Path(tmp) / 'source.lua'
        proof.write_text('one', encoding='utf-8')
        first = Sweep.sha256(proof)
        if first != Sweep.sha256(proof):
            faults.append('identical source hash is unstable')
        proof.write_text('two', encoding='utf-8')
        if first == Sweep.sha256(proof):
            faults.append('changed source retained its provenance hash')
    if not rejects(lambda: Trajectory.fit_exponential_decay([])):
        faults.append('missing data manufactured a fitted coefficient')
    unrelated = [{'days': day, 'alive': 5, 'provenance': {'seed': 'seed-%d' % day}}
                 for day in [30, 90, 180]]
    if not rejects(lambda: Trajectory.fit_exponential_decay(unrelated)):
        faults.append('unrelated horizon cohorts accepted as one fitted trajectory')
    with tempfile.TemporaryDirectory() as tmp:
        # Explicit destinations are honored, while existing evidence is preserved.
        external = pathlib.Path(tmp) / 'sibling-decisions.jsonl'
        external.write_text('existing evidence', encoding='utf-8')
        try:
            Trajectory.export_records([row], external)
            faults.append('external dataset overwrite was permitted')
        except FileExistsError:
            pass
        if external.read_text(encoding='utf-8') != 'existing evidence':
            faults.append('rejected export changed existing evidence')
        selected = pathlib.Path(tmp) / 'explicit-evidence.jsonl'
        Trajectory.export_records([row], selected)
        if json.loads(selected.read_text(encoding='utf-8')) != row:
            faults.append('explicit external export did not preserve the evidence')
    faults.extend(observer_fixture(root))
    for fault in faults:
        print('159) FAULT:', fault)
    if faults:
        return 1
    print('  159) simulation evidence: completion, modules, callback faults, engine data, '
          'joint coverage, seed identity and source hashes held; partial-horizon control flips')
    return 0


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--probe':
        sys.exit(partial_probe(pathlib.Path(sys.argv[2])))
    sys.exit(main(pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HERE.parent))
