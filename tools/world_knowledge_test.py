#!/usr/bin/env python3
"""Border 187: a dated report needs a person-bound native reading completion."""
from pathlib import Path
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

import county_sweep as Sweep
import world_knowledge_evidence as Evidence

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / 'mod/42.20/media/lua/shared/SAO_WorldKnowledge.lua'
KNOWLEDGE = ROOT / 'mod/42.20/media/lua/shared/SAO_Knowledge.lua'
FIXTURE = ROOT / 'tools/sweep/print_read_fixture.lua'
NATIVE = Sweep.PZ.parent / 'media/lua/shared/TimedActions/ISReadABook.lua'
ENCODER = ROOT / 'tools/sweep/decision_capture.lua'
PRELUDE = r'''
SAO = {}; __now=48; __records={}
SAO.Identity={get=function(id) return __records[id] end,all=function() return __records end}
SAO.History={countyHours=function() return __now end,
    recordHour=function(day) return day*24 end,ageInYear=function() return 31 end}
'''
SETUP = r'''
for _, id in ipairs({"adult","other","arrival"}) do
    __records[id]={id=id,originRegion="Muldraugh, KY"}
    assert(SAO.WorldKnowledge.markCountyPresence(id,id~="arrival"))
end
function __facts(id) return SAO.WorldKnowledge.claimsOf(id,__now) end
'''


def run(code, module=WORLD):
    with tempfile.TemporaryDirectory(prefix='sao-report-read-') as tmp:
        work=Path(tmp)
        shutil.copy2(Sweep.STDLIB,work/'stdlib.lua')
        for p in Sweep.OUT.glob('LuaRun*.class'): shutil.copy2(p,work/p.name)
        (work/'prelude.lua').write_text(PRELUDE)
        (work/'setup.lua').write_text(SETUP)
        expression='(function() '+code+' end)()'
        paths=[work/'prelude.lua',FIXTURE,NATIVE,module,KNOWLEDGE,ENCODER,work/'setup.lua']
        result=subprocess.run([str(Sweep.JDK/'java.exe'),'-cp',f'{Sweep.PZ};.','LuaRun',
            *map(str,paths),'--',expression],cwd=work,capture_output=True,text=True,timeout=90)
        values=[s[6:] for s in result.stdout.splitlines() if s.startswith('VALUE ')]
        if result.returncode or len(values)!=1 or 'ERROR ' in result.stdout:
            raise RuntimeError((result.stdout+result.stderr)[-1600:])
        return json.loads(values[0])


RECORD = Evidence.RECORD

def calendar_control() -> str | None:
    """Compile one bad production source and require the mature anchor to move."""
    text = RECORD.read_text(encoding="utf-8")
    old = ".minusDays(Math.max(0, behind)).atStartOfDay();"
    new = ".atStartOfDay();"
    if text.count(old) != 1:
        return "calendar mutation anchor does not occur exactly once"
    helper = """\
import com.sao.engine.SAORecord;
public final class C74CalendarControl {
  public static void main(String[] args) {
    System.out.println(SAORecord.countyInstant(1996, 6, 8, 0.0, 1096));
  }
}
"""
    with tempfile.TemporaryDirectory(prefix="sao-calendar-control-") as temporary:
        work = pathlib.Path(temporary)
        source = work / "com/sao/engine/SAORecord.java"
        source.parent.mkdir(parents=True)
        source.write_text(text.replace(old, new), encoding="utf-8")
        control = work / "C74CalendarControl.java"
        control.write_text(helper, encoding="utf-8")
        classpath = os.pathsep.join([str(Evidence.Source.JAR), str(Sweep.PZ)])
        built = subprocess.run(
            [str(Sweep.JDK / "javac.exe"), "-cp", classpath, "-d", str(work),
             str(source), str(control)], capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=240)
        if built.returncode:
            return "calendar mutation did not compile: " + built.stderr[-500:]
        ran = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp",
             os.pathsep.join([str(work), classpath]), "C74CalendarControl"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=240)
        value = ran.stdout.strip()
        if ran.returncode:
            return "calendar mutation did not run: " + ran.stderr[-500:]
        if value == "1993-07-09T00:00:00":
            return "save-start-only calendar mutation did not change the verdict"
    return None


class WorldKnowledgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Sweep.build_runner(): raise RuntimeError('installed Lua runner build failed')

    def test_actual_engine_issue_metadata_reaches_completion(self):
        keys=Evidence.print_issue_keys()
        self.assertEqual(keys['info'],'Print_Media_KnoxKnews_July2_info')
        self.assertEqual(keys['text'],'Print_Text_KnoxKnews_July2_info')
        options='{info='+json.dumps(keys['info'])+',text='+json.dumps(keys['text'])+'}'
        code='SAOPrintReadFixture.read("adult",'+options+'); return SAODecisionCapture.encode({count=#__facts("adult")})'
        self.assertEqual(run(code),{'count':1})
        source=WORLD.read_text()
        anchor='Print_Media_KnoxKnews_July2_info'
        self.assertEqual(source.count(anchor),1)
        with tempfile.TemporaryDirectory() as tmp:
            mutated=Path(tmp)/WORLD.name
            mutated.write_text(source.replace(anchor,'Print_Text_KnoxKnews_July2_info'))
            self.assertEqual(run(code,mutated),{'count':0})

    def test_presence_and_time_never_grant_report(self):
        value=run('''SAO.WorldKnowledge.advanceAll(96)
            return SAODecisionCapture.encode({adult=#__facts("adult"),arrival=#__facts("arrival"),
                raw=#__records.adult.worldKnowledge.acquisitions})''')
        self.assertEqual(value,{'adult':0,'arrival':0,'raw':0})

    def test_completed_read_is_report_knowledge_at_completion_time(self):
        value=run('''assert(SAOPrintReadFixture.read("adult"))
            return SAODecisionCapture.encode({facts=__facts("adult"),other=__facts("other"),
                observation=SAO.WorldKnowledge.observe("adult",48),
                ready=SAO.WorldKnowledge.knowledgeEvidenceReady("adult")})''')
        row=value['facts'][0]
        self.assertEqual((row['path'],row['knowledgeKind'],row['acquiredHour']),('read','reported',48))
        self.assertEqual(row['sourceEvent']['resolution'],'publication-date')
        self.assertEqual(row['sourceEvent']['atHours'],-168)
        self.assertNotIn('ageAtEvent',row)
        self.assertFalse(value['other'])
        self.assertTrue(value['ready'])
        self.assertEqual(value['observation'][0]['checks']['access']['recordId'],row['receiptId'])

    def test_later_arrival_can_learn_an_earlier_report(self):
        value=run('SAOPrintReadFixture.read("arrival"); return SAODecisionCapture.encode(__facts("arrival"))')
        self.assertEqual(len(value),1)
        self.assertEqual(value[0]['acquiredHour'],48)

    def test_uncompleted_unheld_other_issue_and_missing_native_result_refuse(self):
        for options in ('{stopped=true}','{held=false}','{noNativeResult=true}',
                        '{info="Print_Text_KnoxKnews_July3_info"}',
                        '{text="Print_Text_KnoxKnews_July3_text"}',
                        '{replacePerson="other"}','{changeIssue=true}'):
            with self.subTest(options=options):
                value=run('''local before=SAODecisionCapture.encode(__records)
                    SAOPrintReadFixture.read("adult",'''+options+''')
                    return SAODecisionCapture.encode({unchanged=before==SAODecisionCapture.encode(__records),
                        claims=#__facts("adult")})''')
                self.assertEqual(value,{'unchanged':True,'claims':0})

    def test_future_issue_is_not_acquired(self):
        value=run('''__now=-180; SAOPrintReadFixture.read("adult")
            return SAODecisionCapture.encode(__facts("adult"))''')
        self.assertFalse(value)

    def test_old_grants_are_withheld_and_preserved_during_migration(self):
        value=run('''local old={schemaVersion=1,presence={},acquisitions={{claimId="legacy",path="lived",retained=true,acquiredHour=-168}}}
            __records.adult.worldKnowledge=old
            local before=SAODecisionCapture.encode(old)
            local facts=__facts("adult")
            local ordinary=SAO.Knowledge.about("adult","world")
            local ready=SAO.WorldKnowledge.knowledgeEvidenceReady("adult")
            local unchanged=before==SAODecisionCapture.encode(old)
            SAO.WorldKnowledge.advancePerson("adult")
            return SAODecisionCapture.encode({facts=#facts,ordinary=ordinary==nil,ready=ready,
                unchanged=unchanged,preserved=before==SAODecisionCapture.encode(__records.adult.worldKnowledge.legacy.state),
                after=#__facts("adult"),schema=__records.adult.worldKnowledge.schemaVersion})''')
        self.assertEqual(value,{'facts':0,'ordinary':True,'ready':False,'unchanged':True,
                              'preserved':True,'after':0,'schema':2})

    def test_migrated_person_can_acquire_supported_report(self):
        value=run('''__records.adult.worldKnowledge={schemaVersion=1,presence={},acquisitions={}}
            SAOPrintReadFixture.read("adult")
            return SAODecisionCapture.encode({count=#__facts("adult"),legacy=__records.adult.worldKnowledge.legacy.state.schemaVersion})''')
        self.assertEqual(value,{'count':1,'legacy':1})

    def test_receipt_is_idempotent_and_reader_detached(self):
        value=run('''SAOPrintReadFixture.read("adult")
            local before=SAODecisionCapture.encode(__records.adult)
            SAOPrintReadFixture.read("adult")
            local detached=__facts("adult"); detached[1].source.path="wrong"
            return SAODecisionCapture.encode({unchanged=before==SAODecisionCapture.encode(__records.adult),count=#__facts("adult")})''')
        self.assertEqual(value,{'unchanged':True,'count':1})

    def test_malformed_receipt_or_acquisition_is_withheld_everywhere(self):
        for mutation in ('r.personId="other"','r.completedHour=49','r.infoKey="wrong"',
                         'a.path="lived"','a.knowledgeKind="experienced"','a.source.sha256="wrong"',
                         'a.sourceEvent.atHours=-167','s.readReceipts[a.receiptId]=nil'):
            value=run('''SAOPrintReadFixture.read("adult")
                local s=__records.adult.worldKnowledge; local a=s.acquisitions[1]; local r=s.readReceipts[a.receiptId]
                '''+mutation+'''
                return SAODecisionCapture.encode({count=#__facts("adult"),
                    observation=#SAO.WorldKnowledge.observe("adult",48),
                    ready=SAO.WorldKnowledge.knowledgeEvidenceReady("adult"),
                    ordinary=SAO.Knowledge.about("adult","world")==nil})''')
            with self.subTest(mutation=mutation):
                self.assertEqual(value,{'count':0,'observation':0,'ready':False,'ordinary':True})

    def test_retention_and_decision_time_still_bound_access(self):
        value=run('''SAOPrintReadFixture.read("adult")
            local earlier=SAO.WorldKnowledge.claimsOf("adult",47)
            __records.adult.worldKnowledge.acquisitions[1].retained=false
            return SAODecisionCapture.encode({earlier=#earlier,current=#__facts("adult")})''')
        self.assertEqual(value,{'earlier':0,'current':0})

    def test_shipped_source_mutations_flip_named_verdicts(self):
        source=WORLD.read_text(encoding='utf-8')
        cases=[
            ('completion producer','local recorded, why = pcall(completedPrintRead, before, action, result)',
             'local recorded, why = true, nil',
             'SAOPrintReadFixture.read("adult"); return SAODecisionCapture.encode({acquired=#__facts("adult")})',
             {'acquired':1},{'acquired':0}),
            ('receipt admission','if validAcquisition(entry, state, rec, atHour)', 'if true',
             'SAOPrintReadFixture.read("adult"); __records.adult.worldKnowledge.readReceipts={}; return SAODecisionCapture.encode({acquired=#__facts("adult")})',
             {'acquired':0},{'acquired':1}),
            ('presence grants nothing','resolvePending(recordOf(person), state)\n    return 0',
             'resolvePending(recordOf(person), state)\n    state.acquisitions[1]={path="lived"}\n    return 1',
             'return SAODecisionCapture.encode({raw=#__records.adult.worldKnowledge.acquisitions})',
             {'raw':0},{'raw':1}),
        ]
        for label,old,new,code,good,bad in cases:
            with self.subTest(control=label),tempfile.TemporaryDirectory() as tmp:
                self.assertEqual(source.count(old),1)
                mutated=Path(tmp)/WORLD.name; mutated.write_text(source.replace(old,new))
                self.assertEqual(run(code),good); self.assertEqual(run(code,mutated),bad)

    def test_retired_exporter_refuses_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            target=Path(tmp)/'legacy'
            with self.assertRaisesRegex(ValueError,'exporter retired'): Evidence.generate(target)
            self.assertFalse(target.exists())

    def test_installed_calendar_remains_verified(self):
        result=Evidence.calendar_values()
        self.assertIn('recordId',result)
        self.assertIsNone(calendar_control())


if __name__=='__main__':
    if not all(p.exists() for p in (Sweep.PZ,Sweep.JDK,NATIVE)):
        print('187) report acquisition: SKIPPED - installed engine absent'); sys.exit(0)
    program=unittest.main(verbosity=1,exit=False)
    sys.exit(0 if program.result.wasSuccessful() else 1)
