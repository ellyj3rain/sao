#!/usr/bin/env python3
"""Exact meaningful reading and leisure renewal on installed item/Lua owners."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import study_test as fixture
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / 'mod/42.20/media/lua/client/SAO_Study.lua'
PLAN = ROOT / 'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
CASES = ROOT / 'tools/d2_reading_cases.lua'
CONTROLS = [
    ('uninteresting-allowed', 'study', '    if item:hasTag(ItemTag.UNINTERESTING) then return false, "uninteresting-literature" end\n', '', 'offer_skips_actual_native_id_cards'),
    ('positive-pages-only', 'study', 'item:getNumberOfPages() ~= 0', 'item:getNumberOfPages() > 0', 'offer_skips_actual_native_id_cards'),
    ('action-skips-material', 'study', 'return bound(self) and readableAction(self)\n', 'return bound(self)\n', 'action_rechecks_meaningful_material'),
    ('completion-choice-ignored', 'study', 'return SAO.ProceduralPlanning.leisureChoice(id, "read " .. item:getFullType(), tostring(item:getID()))', 'return true', 'completed_exact_item_not_reoffered'),
    ('item-identity-omitted', 'study', '            itemKey = tostring(item:getID()),\n', '', 'completed_exact_item_not_reoffered'),
    ('refusal-feedback-omitted', 'study', '        if leisure then SAO.ProceduralPlanning.leisureRefusal(id, purpose.id, workId) end\n', '', 'refusal_selects_next_exact_item'),
    ('foreign-refusal-accepted', 'plan', 'work.id ~= workId or work.purposeId ~= purposeId or work.itemId ~= purpose.leisure.itemKey', 'work.purposeId ~= purposeId or work.itemId ~= purpose.leisure.itemKey', 'foreign_refusal_work_rejected'),
    ('suspended-reading-ignored', 'plan', 'local suspended = s and s.suspendedLeisure', 'local suspended = nil', 'suspended_reading_still_blocks_completed_exact_item'),
    ('sharing-retention-omitted', 'plan', '    if optionalSharing(old) then', '    if false then', 'capacity_does_not_discard_pending_sharing'),
    ('interrupted-admission-retained', 'study', '    SAO.ProceduralPlanning.releaseStudy(action.personId, work.purposeId, work.id)\n', '', 'interruption_releases_exact_admission'),
    ('instrument-generic-completion', 'plan', '    if purpose and purpose.instrument and authority ~= INSTRUMENT_RESULT then return false end\n', '', 'generic_instrument_completion_refused'),
    ('instrument-end-unproven', 'plan', 'or result.soundEnded ~= true or not finite(result.startedAtHours)', 'or not finite(result.startedAtHours)', 'sound_without_observed_end_cannot_complete'),
    ('instrument-generation-unbound', 'plan', ' or result.bodyToken ~= admission.bodyToken', '', 'foreign_sound_generation_cannot_complete'),
    ('instrument-stale-sequence', 'plan', ' or work.sequence ~= purpose.instrument.expectedSequence', '', 'old_admission_cannot_claim_new_attempt'),
    ('instrument-lifetime-completion', 'plan', 'leisurePurpose(id, activityKey, itemKey, instrument)', 'leisurePurpose(id, activityKey, itemKey)', 'completed_sound_allows_new_occurrence'),
    # Both capacity callers now use retirePurpose's authenticated optional suspension;
    # sharing-retention-omitted covers that shared writer, with both callers in baseline.
    ('instrument-prediction-omitted', 'plan', 'planned.consequences, spontaneous.consequences = { dataCopy(effect) }, { dataCopy(effect) }', 'planned.consequences, spontaneous.consequences = {}, {}', 'instrument_candidates_use_exact_sound_consequence'),
    ('instrument-prepared-completes', 'plan', 'result.queueAdmitted ~= true\n                or ', '', 'prepared_unqueued_work_cannot_complete'),
    ('instrument-live-owner-lost', 'plan', ' or owner.instrumentWork(id) then return false end', ' then return false end', 'reconcile_cannot_retire_live_native_work'),
    ('note-blank-query-mutates', 'study', '        if item:isEmptyPages() then return nil, "note-content-empty" end', '        item:getCustomPages()\n        if item:isEmptyPages() then return nil, "note-content-empty" end', 'blank_note_query_refused_without_allocation'),
    ('note-whitespace-accepted', 'study', '        if not meaningful then return nil, "note-content-empty" end\n', '', 'whitespace_note_refused'),
    ('note-equal-length-authorizes', 'study', '    for index, text in ipairs(first.pages) do if second.pages[index] ~= text then return false end end\n', '', 'equal_length_text_mutation_invalidates_owner'),
    ('note-cached-unread-is-durable', 'study', '    action.noteContent = content\n', '    action.noteContent = content\n    work.content = content\n', 'unread_note_text_not_durable_at_admission'),
    ('note-native-perform-unproven', 'study', ' or active.notePerformed ~= self', '', 'complete_without_native_perform_refused'),
    ('note-native-perform-is-receipt', 'study', '        active.notePerformed = self\n', '        active.notePerformed = self\n        self.nativeCompleted = true\n        close(self, "completed")\n', 'perform_handoff_is_not_text_receipt'),
    ('note-book-counter-effects', 'study', '    self.nativeCompleted = true\n    return close(self, "completed")', '    ISReadABook.complete(self)\n    self.nativeCompleted = true\n    return close(self, "completed")', 'note_completion_has_no_book_effects_or_shared_receipt'),
    ('note-generic-book-feedback', 'study', '        if writable then return SAO.ProceduralPlanning.leisureChoice(id, "read written notes", tostring(item:getID()), noteActivity(rec(id), item)) end\n', '', 'legacy_pages_do_not_prove_note_exposure'),
    ('note-content-history-forgotten', 'study', '    if writable and noteWasExposed(id, item, content) then return false, "note-text-already-exposed" end\n', '', 'same_written_text_is_not_reoffered'),
    ('note-occurrence-lookup-omitted', 'plan', '(choice.activityKey or choice.activity)', 'choice.activity', 'note_queue_refusal_throttles_exact_retry'),
    ('note-occurrence-leaks-objective', 'plan', 'objective = "make time for " .. activity .. " in a usable shared place"', 'objective = "make time for " .. activityKey .. " in a usable shared place"', 'note_occurrence_is_not_human_objective'),
    ('note-foreign-exposure-authority', 'study', 'if row.actorId == id and row.itemId == tostring(item:getID())', 'if row.itemId == tostring(item:getID())', 'foreign_exposure_cannot_exclude_note'),
    ('note-future-exposure-authority', 'study', ' and row.atHours <= hours()', '', 'future_exposure_cannot_exclude_note'),
    ('note-overlimit-clipped', 'study', 'if #text > 16384 or bytes > 65536 then', 'if false then', 'oversized_note_refused_without_truncation'),
    ('note-content-retention-unbounded', 'study', '            if #person.noteReadingOutcomes > 16 then table.remove(person.noteReadingOutcomes, 1) end\n', '', 'completed_note_content_retention_bounded'),
    ('note-public-result-authority', 'plan', '    if purpose and purpose.noteReading and authority ~= NOTE_RESULT then return false end\n', '', 'public_note_completion_refused'),
    ('note-practice-pollution', 'plan', 'not purpose.instrument and not purpose.noteReading and (step.verb == "practice"', 'not purpose.instrument and (step.verb == "practice"', 'note_exposure_has_no_practice_credit'),
    ('note-result-foreign-generation', 'plan', 'or result.bodyToken ~= expected.bodyToken', 'or false', 'foreign_note_generation_cannot_advance_purpose'),
    ('note-result-content-unbound', 'plan', 'or result.contentBinding ~= expected.contentBinding or result.contentBinding ~= result.workId', 'or false', 'wrong_note_content_binding_cannot_advance_purpose'),
    ('note-result-clock-reversed', 'plan', 'or result.endedAt < result.startedAt\n', '\n', 'reversed_note_clock_refused'),
    ('note-result-future-terminal', 'plan', 'or result.atHours < admission.at or result.atHours > nowHours()', 'or result.atHours < admission.at', 'future_note_terminal_refused'),
    ('note-result-wrong-occurrence', 'plan', 'or result.sequence ~= expected.sequence\n', '\n', 'wrong_note_occurrence_refused'),
    ('note-stop-mutates-transferred-item', 'study', '    if held(action.character, action.item) then action.item:setJobDelta(0) end', '    action.item:setJobDelta(0)', 'transferred_note_stop_preserves_foreign_item_progress'),
    ('note-retired-perform-authority', 'study', '    if work.status ~= "reading" or not active or active.action ~= self then return end\n', '', 'retired_queued_note_callbacks_preserve_current_action'),
    ('note-retired-stop-authority', 'study', '        and person.studyWork.status == "reading" and active and active.action == self\n', '', 'retired_queued_note_callbacks_preserve_current_action'),
    ('note-interruption-presentation-retained', 'study', '            if work.contentKind == "written-note" then endNotePresentation(active.action) end\n', '', 'explicit_note_interruption_retires_owned_presentation'),
]

NOTE_BINDING = '''    if content and not SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId) then
        close(action, "interrupted", "note-purpose-binding-refused")
        return false
    end
    if not SAO.Needs.queueVerified(action) then
        if content and work.status == "completed" and work.exposureCompleted == true then return true end
        close(action, "interrupted", "native-reading-queue-refused")
        if leisure then SAO.ProceduralPlanning.leisureRefusal(id, purpose.id, workId) end
        return false
    end
    if content then return work.status == "reading" or work.status == "completed" end
'''
LATE_BINDING = '''    if not SAO.Needs.queueVerified(action) then
        if content and work.status == "completed" and work.exposureCompleted == true then return true end
        close(action, "interrupted", "native-reading-queue-refused")
        if leisure then SAO.ProceduralPlanning.leisureRefusal(id, purpose.id, workId) end
        return false
    end
    if content then
        SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAONeeds", workId)
        return work.status == "reading" or work.status == "completed"
    end
'''
CONTROLS.append(('note-binding-after-native-add', 'study', NOTE_BINDING, LATE_BINDING,
                 'inline_native_note_callbacks_have_prior_exact_binding'))

# Add only test exposure to the existing native probe. Production item/action
# implementations are installed bytes; this retained adapter supplies clocks
# and lets the proof inspect whether a pure query allocated custom pages.
NOTE_PROBE = r'''
        env.rawset("__customPagesAbsent",(JavaFunction)(frame,count)->{
            try {var field=Literature.class.getDeclaredField("customPages");field.setAccessible(true);
                return frame.push(field.get(frame.get(0))==null);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        env.rawset("__newNote",(JavaFunction)(frame,count)->{
            var value=InventoryItemFactory.CreateItem("Base.Notebook");
            value.setID(((Number)frame.get(0)).intValue());value.setName("Written notebook");body.getInventory().AddItem(value);return frame.push(value);
        });
        env.rawset("__nativeItemRoundtrip",(JavaFunction)(frame,count)->{
            try {var bytes=ByteBuffer.allocate(2*1024*1024);((InventoryItem)frame.get(0)).saveWithSize(bytes,false);bytes.flip();
                var value=InventoryItem.loadItem(bytes,249);body.getInventory().AddItem(value);return frame.push(value);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        env.rawset("__transferNativeNote",(JavaFunction)(frame,count)->{
            var item=(InventoryItem)frame.get(0);var old=item.getContainer();
            if(old!=null)old.Remove(item);
            var destination=new zombie.inventory.ItemContainer();destination.AddItem(item);
            return frame.push(destination);
        });
        var actions=new java.util.IdentityHashMap<KahluaTable,zombie.characters.CharacterTimedActions.LuaTimedActionNew>();
        env.rawset("__nativeNoteCallback",(JavaFunction)(frame,count)->{
            var table=(KahluaTable)frame.get(0);String command=(String)frame.get(1);
            var action=actions.get(table);
            if(command.equals("start")){
                action=new zombie.characters.CharacterTimedActions.LuaTimedActionNew(table,body);
                actions.put(table,action);table.rawset("action",action);action.start();
            } else if(action==null)throw new AssertionError("Native action was not started");
            else if(command.equals("progress")){action.setJobDelta(((Number)frame.get(2)).floatValue());action.update();}
            else if(command.equals("perform"))action.perform();
            else if(command.equals("complete"))action.complete();
            else if(command.equals("stop"))action.stop();
            else throw new AssertionError("Unknown native callback");
            return frame.push(action.getJobDelta());
        });
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '_scratch/d2-meaningful-leisure/reading-planning/proof')
    parser.add_argument('--variants', nargs='+')
    parser.add_argument('--repair-native', action='store_true')
    args = parser.parse_args()
    if args.repair_native: return native_repair(args)
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    game, jdk = fixture.GAME, fixture.JDK
    native = [game / 'media/lua/shared/ISBaseObject.lua', game / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
              game / 'media/lua/client/TimedActions/ISInventoryTransferAction.lua', game / 'media/lua/shared/TimedActions/ISReadABook.lua']
    java = [ROOT / 'tools/luacheck/MovementCrossingProbe.java', ROOT / 'tools/luacheck/D2ReadingProbe.java']
    jars = [game / 'projectzomboid.jar', game / 'ZombieBuddy.jar', ROOT / 'mod/42.20/media/java/SAO.jar']
    inputs = [STUDY, PLAN, CASES, Path(__file__), ROOT / 'tools/study_test.py', fixture.IDENTITY, fixture.NEEDS,
              *native, *java, *jars, game / 'stdlib.lua', game / 'media/scripts/generated/items/literature.txt',
              game / 'media/lua/client/ISUI/ISInventoryPaneContextMenu.lua']
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "d2 reading")
    if preflight is not None:
        raise SystemExit(preflight)
    digest = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
    pins = {str(p): digest(p) for p in inputs}
    receipt = {'status': 'INCOMPLETE', 'atUtc': datetime.now(timezone.utc).isoformat(), 'inputs': pins, 'runs': [],
               'scope': 'Installed literal native Literature items and ReadLiterature effects, actual ISReadABook and SAO Study/Planning/Needs Lua, native Kahlua persistence. Fixture controls action progress and body/queue admission; no rendered gameplay claim.'}
    source = {'study': STUDY.read_text(encoding='utf-8-sig'), 'plan': PLAN.read_text(encoding='utf-8-sig')}
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", CASES.read_text()))
    selected = args.variants or ['production', *[x[0] for x in CONTROLS]]
    assert set(selected) <= {'production', *[x[0] for x in CONTROLS]}, 'unknown variant'
    def save():
        receipt['changedInputs'] = [p for p, h in pins.items() if digest(p) != h]
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def execute(name, command, cwd):
        done = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, text=True, timeout=120)
        text = done.stdout + done.stderr
        path = out / (name + '.log'); path.write_text(text, encoding='utf-8')
        return done, {'name': name, 'command': list(map(str, command)), 'exitCode': done.returncode,
                      'log': str(path), 'logSha256': digest(path)}, text
    try:
        with tempfile.TemporaryDirectory(prefix='sao-d2-reading-') as temporary:
            work = Path(temporary); shutil.copyfile(game / 'stdlib.lua', work / 'stdlib.lua')
            cp = os.pathsep.join(map(str, jars))
            probe = java[1].read_text(encoding='utf-8-sig')
            for before, after in [
                ('LuaManager.caller=new LuaCaller(LuaManager.converterManager);', '''LuaManager.caller=new LuaCaller(LuaManager.converterManager){
                    @Override public Object[] pcall(KahluaThread vm,Object function,Object argument){
                        var result=super.pcall(vm,function,argument);
                        if(!Boolean.TRUE.equals(result[0]))throw new AssertionError("Native callback failed: "+java.util.Arrays.deepToString(result));
                        return result;
                    }
                };'''),
                ('"IDcard_Male","IDcard_Female","Book","ComicBook"', '"IDcard_Male","IDcard_Female","Book","ComicBook","Notebook","Journal"'),
                ('Literature.class,ItemTag.class,ArrayList.class,', 'Literature.class,ItemTag.class,ArrayList.class,java.util.HashMap.class,zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,'),
                ('        Path planner=null;', NOTE_PROBE + '\n        Path planner=null;')]:
                assert probe.count(before) == 1, 'native note adapter anchor'
                probe = probe.replace(before, after, 1)
            generated = out / 'D2ReadingProbe.java'; generated.write_text(probe, encoding='utf-8')
            receipt['generatedProbe'] = {'path':str(generated), 'sha256':digest(generated), 'source':str(java[1])}
            done, record, output = execute('compile', [jdk / 'javac.exe', '-encoding', 'UTF-8', '-cp', cp, '-d', work, java[0], generated], work)
            receipt['compile'] = record; save(); assert done.returncode == 0, output
            (work / 'prelude.lua').write_text(fixture.PRELUDE, encoding='utf-8')
            for name in selected:
                current = dict(source); target = None
                if name != 'production':
                    _, owner, before, after, target = next(x for x in CONTROLS if x[0] == name)
                    assert current[owner].count(before) == 1, name + ': exact mutation anchor'
                    current[owner] = current[owner].replace(before, after, 1)
                for owner, text in current.items(): (work / (owner + '.lua')).write_text(text, encoding='utf-8')
                command = [jdk / 'java.exe', '-Duser.home=' + str(work), '-Djava.awt.headless=true', '--enable-native-access=ALL-UNNAMED',
                           '-cp', str(work) + os.pathsep + cp, 'D2ReadingProbe', game, work / 'prelude.lua', *native,
                           fixture.IDENTITY, work / 'plan.lua', fixture.NEEDS, work / 'study.lua', CASES, '--', '__d2ReadingResults']
                done, record, output = execute(name, command, work)
                checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', output))
                record.update(checks=checks, expectedFailure=target)
                receipt['runs'].append(record); save()
                if target:
                    assert done.returncode != 0 and checks.get(target) == 'false' and 'D2_READING:' + target in output, name + ': intended verdict did not reject\n' + output[-4000:]
                else:
                    assert done.returncode == 0 and set(checks) == expected and all(v == 'true' for v in checks.values()), output[-6000:]
                print(name + ': PASS ' + str(len(checks)), flush=True)
        assert not receipt['changedInputs'], receipt['changedInputs']
        receipt.update(status='PASS', checks=len(expected), controls=len(selected) - ('production' in selected)); save()
        return 0
    except Exception as error:
        receipt['error'] = str(error); save(); print('D2 reading FAILED:', error, file=sys.stderr); return 1


def native_repair(args):
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    game,jdk=fixture.GAME,fixture.JDK
    here=ROOT/'tools/instrument_checks'
    java=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
          ROOT/'tools/cognition_checks/CognitionUseProbe.java',here/'InstrumentProbe.java']
    jars=[game/'projectzomboid.jar',game/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    native=[game/'media/lua/shared/ISBaseObject.lua',game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
            game/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
    cases=ROOT/'tools/d2_leisure_repair_cases.lua'
    perception=ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua'
    shared=[ROOT/'mod/42.20/media/lua/shared'/('SAO_'+name+'.lua') for name in ('CognitiveModels','Disposition','Cognition')]
    source=PLAN.read_text(encoding='utf-8-sig')
    controls=[
      ('same-frame-clock','or result.endedAtHours > result.atHours','or result.endedAtHours ~= result.atHours','delayed_native_perform_accepts_ordered_clock'),
      ('optional-capacity-lock','return performed and pending','return false','routine_sound_capacity_accepts_more_than_twelve'),
      ('discard-optional-evidence','if optionalSharing(old) then','if false then','suspension_keeps_unresolved_share_and_exact_receipt'),
      ('resource-capacity-lock','not p.leisure or optionalSharing(p)','not p.leisure','material_purpose_admits_after_solo_completions'),
      ('forget-revival','suspended, suspensionLedger = suspendedPurpose(s, spec.key)','suspended, suspensionLedger = nil, nil','same_key_revival_preserves_unresolved_participation'),
      ('suspend-required-participation','if step.required ~= false then return false end','if false then return false end','required_participation_is_not_optional_archive'),
      ('unbounded-optional-history','while #ledger.order > MAX_EVENTS do','while false do','suspended_history_is_bounded_with_explicit_omission'),
      ('revive-abandoned','        or purpose.status == "abandoned" or purpose.status == "completed" then return false end','        then return false end','abandoned_share_is_not_revived_as_unresolved_intent'),
      ('required-capacity-lock','if not executable then return nil, "conflict-purpose-capacity" end','if true then return nil, "conflict-purpose-capacity" end','canonical_defense_admits_over_required_capacity'),
      ('drop-owned-admission','if purpose and not purpose.admission then','if purpose then','all_native_admissions_require_owner_handback'),
      ('lose-swapped-conflict','ledger.purposes[activeId] = active;ledger.order[#ledger.order + 1] = activeId','ledger.purposes[activeId] = nil;ledger.order[#ledger.order + 1] = activeId','ordinary_resume_preserves_conflict_identity_history'),
      ('lose-obligation-order','table.insert(s.order, clamp(position, 1, #s.order + 1), key)','s.order[#s.order + 1] = key','restored_obligation_reenters_actual_resource_demand'),
      ('ignore-suspended-deadline','    if purpose.resourceOutcome then P.resourceOutcomeDemand(id) end\n','','expired_queued_obligation_uses_canonical_deadline_retirement'),
      ('ignore-reversed-clock','result.endedAtHours < result.startedAtHours','false','reversed_native_start_end_is_rejected'),
      ('ignore-terminal-order','result.endedAtHours > result.atHours','false','native_end_after_terminal_is_rejected'),
      ('ignore-future-terminal',' or result.atHours > nowHours()','', 'future_native_terminal_is_rejected'),
    ]
    paths=[perception,*java,*jars,*native,*shared,here/'prelude.lua',here/'setup.lua',PLAN,fixture.NEEDS,fixture.GESTURE,cases,Path(__file__),
           game/'stdlib.lua',game/'media/scripts/generated/items/normal.txt',game/'media/scripts/generated/items/weapon.txt']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, game, jdk, "D2 native intent continuity")
    if preflight is not None:
        raise SystemExit(preflight)
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    pins={str(p):sha(p) for p in paths}
    rec={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],
         'scope':'Actual installed native shell/material/inventory/Lua action queue and world sound with canonical Gesture/Planning. Emitter hardware is controlled. Private conflict appraisal controlled to isolate admission capacity. No game or audible acceptance.'}
    selected=args.variants or ['production',*[x[0] for x in controls]]
    expected=set(re.findall(r"check\('([a-z0-9_]+)'",cases.read_text()))
    def save():
      rec['changedInputs']=[p for p,h in pins.items() if sha(p)!=h]
      (out/'receipt.json').write_text(json.dumps(rec,indent=2)+'\n')
    def run(name,command,cwd):
      done=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=90)
      log=out/(name+'.log');log.write_bytes(done.stdout+done.stderr)
      row={'name':name,'command':list(map(str,command)),'exitCode':done.returncode,'log':str(log),'logSha256':sha(log)}
      rec['runs'].append(row);save();return row,log.read_text(encoding='utf-8',errors='replace')
    try:
      assert set(selected)<={'production',*[x[0] for x in controls]}
      with tempfile.TemporaryDirectory(prefix='sao-d2-repair-') as directory:
        work=Path(directory);shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
        row,log=run('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*java],work)
        assert row['exitCode']==0,log
        owner=perception.read_text(encoding='utf-8-sig')
        sorter=owner.split('local function sortSightEvidence(',1)[1].split('local function zombieReports(',1)[0]
        sort_owner=out/'perception-sort.lua'
        sort_owner.write_text('SAO.Perception=SAO.Perception or {}\nlocal P=SAO.Perception\nlocal function sortSightEvidence('+sorter,encoding='utf-8')
        rec['generatedSortOwner']={'path':str(sort_owner),'sha256':sha(sort_owner)}
        for name in selected:
          text=source;target=None
          if name!='production':
            _,before,after,target=next(x for x in controls if x[0]==name)
            assert text.count(before)==1,name+': anchor'
            text=text.replace(before,after,1)
          overlay=out/(name+'-Planning.lua');overlay.write_text(text,encoding='utf-8')
          row,log=run(name,[jdk/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
            '-cp',str(work)+os.pathsep+cp,'InstrumentProbe',game,here/'prelude.lua',*native,here/'setup.lua',*shared,sort_owner,fixture.NEEDS,overlay,fixture.GESTURE,cases],work)
          checks=dict(re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M));row.update(checks=checks,expectedFailure=target);save()
          if target:assert row['exitCode']!=0 and checks.get(target)=='false' and 'D2_REPAIR:'+target in log,name+': '+log[-3000:]
          else:assert row['exitCode']==0 and set(checks)==expected and all(x=='true' for x in checks.values()),log[-4000:]
          print(name+': PASS '+str(len(checks)),flush=True)
      assert not rec['changedInputs'],rec['changedInputs']
      rec.update(status='PASS',checks=len(expected),controls=len(selected)-('production' in selected));save();return 0
    except Exception as error:
      rec['error']=str(error);save();print('D2 repair FAILED:',error,file=sys.stderr);return 1

if __name__ == '__main__':
    raise SystemExit(main())
