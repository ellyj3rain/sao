"""Focused passive native-start provenance controls using installed PZ APIs.

No native process, Lua world, save or desktop is launched. Actual current Java
cohort snapshots compile against installed jars. Engine player calls are explicit
fixtures; actual installed KahluaTableImpl objects exercise own-key semantics.
"""
from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'tools/world_lab/StudyStartContext.java'
GAME = Path(os.environ.get('PZ_DIR', 'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', str(Path.home()/'Peanut Butter/JetBrains/Java/bin')))

PLAYER = '''package zombie.characters;
import se.krka.kahlua.vm.KahluaTable;
public class IsoPlayer {
 public KahluaTable data; public boolean present=true, fail; public int dataReads, probes;
 public boolean hasModData(){probes++;if(fail)throw new IllegalStateException("fixture API failure");return present;}
 public KahluaTable getModData(){dataReads++;if(!present)throw new IllegalStateException("unexpected allocating read");return data;}
}'''
CORE = '''package zombie.core; public final class Core {public static boolean debug=false;}'''
PROBE = r'''
import java.lang.reflect.*;
import java.util.*;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;

public class StartContext04Probe {
 static KahluaTableImpl table(Object... pairs) {
  Map<Object,Object> map=new LinkedHashMap<>();
  for(int i=0;i<pairs.length;i+=2)map.put(pairs[i],pairs[i+1]);
  return new KahluaTableImpl(map);
 }
 static KahluaTableImpl scenario() {
  return table("scenario","tourist","lifecycleVersion",3.0,"kitVersion",3.0,
   "lifecycleState","ready","setupComplete",true,"setupFailed",false,
   "lifecycleProtected",false,"placementVerified",true,"startX",8497.5,"startY",14433.5,"startZ",2.0);
 }
 static KahluaTable poison() {
  return (KahluaTable)Proxy.newProxyInstance(StartContext04Probe.class.getClassLoader(),
   new Class<?>[]{KahluaTable.class},(p,m,a)->{throw new IllegalStateException("unexpected callback: "+m.getName());});
 }
 static void out(String name,IsoPlayer player) {
  String value=StudyStartContext.observe(player);
  long count=-1;
  try{count=StudyStartContext.class.getField("lookupCount").getLong(null);
      StudyStartContext.class.getField("lookupCount").setLong(null,0);}catch(ReflectiveOperationException ignored){}
  System.out.println(name+"\t{\"context\":"+value+",\"dataReads\":"+(player==null?0:player.dataReads)
   +",\"probes\":"+(player==null?0:player.probes)+",\"lookups\":"+count+"}");
 }
 static void out(String name,KahluaTable data) {IsoPlayer p=new IsoPlayer();p.data=data;out(name,p);}
 public static void main(String[]args) {
  out("unbound",(IsoPlayer)null);
  IsoPlayer empty=new IsoPlayer();empty.present=false;out("no-data",empty);
  IsoPlayer broken=new IsoPlayer();broken.fail=true;out("api-failure",broken);
  out("empty-root",table());
  out("ready",table("WhereIWas",scenario()));
  KahluaTableImpl pending=scenario();pending.delegate.put("lifecycleState","loading");
  pending.delegate.put("setupComplete",false);pending.delegate.put("lifecycleProtected",true);
  out("pending",table("WhereIWas",pending));
  KahluaTableImpl protectedReady=scenario();protectedReady.delegate.put("lifecycleProtected",true);
  out("protected-ready",table("WhereIWas",protectedReady));
  KahluaTableImpl failed=scenario();failed.delegate.put("setupFailed",true);
  failed.delegate.put("lifecycleState","restoring");failed.delegate.put("setupFailureReason","placement failed");
  out("failed",table("WhereIWas",failed));
  KahluaTableImpl legacy=scenario();legacy.delegate.remove("lifecycleProtected");
  out("legacy",table("KnoxScenarios",legacy));
  out("false-current",table("WhereIWas",false,"KnoxScenarios",scenario()));
  KahluaTableImpl precedence=scenario();precedence.delegate.put("scenario","police_response");
  out("precedence",table("WhereIWas",precedence,"KnoxScenarios",scenario()));
  out("malformed-current",table("WhereIWas",17.0,"KnoxScenarios",scenario()));
  out("tiyl-selected",table("TIYL",table("originId","rosewood","schemaVersion",2.0,
   "outcomesApplied",false,"originTraitApplied",true)));
  out("tiyl-pending",table("TIYL",table("originId","rosewood","originSpawnPending",true)));
  out("tiyl-applied",table("TIYL",table("originId","rosewood","originSpawnPending",false,
   "originSpawnApplied",true,"serverOriginRegistered",true,"originSpawnX",8052.5,
   "originSpawnY",11461.5,"originSpawnZ",1.0)));
  out("tiyl-partner",table("TIYL",table("originId","rosewood","scriptedStartId","last_goodbye",
   "scriptedStartState","partner_active","scriptedStartComplete",false)));
  Object hostile=new Object(){public String toString(){throw new AssertionError("hostile toString");}};
  Number malicious=new Number(){public int intValue(){throw new AssertionError("int callback");}
   public long longValue(){throw new AssertionError("long callback");}
   public float floatValue(){throw new AssertionError("float callback");}
   public double doubleValue(){throw new AssertionError("double callback");}};
  out("hostile-types",table("WhereIWas",table("scenario",hostile,"lifecycleVersion",malicious,
   "setupComplete",1.0,"startX",Double.NaN,"startY",Double.POSITIVE_INFINITY,"startZ",1e20)));
  out("oversized",table("WhereIWas",table("scenario","x".repeat(200000)),
   "TIYL",table("originId","y".repeat(200000))));
  KahluaTableImpl fieldMeta=scenario();fieldMeta.delegate.remove("lifecycleProtected");
  fieldMeta.setMetatable(table("lifecycleProtected",false));
  out("field-metatable",table("WhereIWas",fieldMeta));
  KahluaTableImpl rootMeta=table();rootMeta.setMetatable(table("WhereIWas",scenario()));
  out("root-metatable",rootMeta);
  KahluaTableImpl poisoned=scenario();poisoned.setMetatable(poison());
  out("poisoned-metatable",table("WhereIWas",poisoned));
  KahluaTableImpl rewritten=table();rewritten.setRewriteTable(table("WhereIWas",scenario()));
  out("rewritten",rewritten);
  out("unsupported-table",poison());
  KahluaTableImpl largeScenario=scenario(), largeLife=table("originId","rosewood");
  KahluaTableImpl large=table("WhereIWas",largeScenario,"TIYL",largeLife);
  out("small-unrelated",large);
  for(int i=0;i<15000;i++) {
   large.delegate.put("unrelated-"+i,hostile);
   largeScenario.delegate.put("unrelated-"+i,hostile);
   largeLife.delegate.put("unrelated-"+i,hostile);
  }
  out("large-unrelated",large);
  out("escaped",table("WhereIWas",table("scenario","a\"\\\n\u0000\uD800\uD83D\uDE80")));
  out("safe-escapes",table("WhereIWas",table("scenario","a\"\\\t\n\r\uD83D\uDE80"),
   "TIYL",table("originId","a\"\\\t\n\r\uD83D\uDE80")));
  String[] badSurrogates={"x\uD800y","x\uDC00y","\uDC00\uD800","x\uD83D",
   "\uD83D\uDE80\uD800","\uD800\uD800\uDC00\uDC00"};
  for(int i=0;i<badSurrogates.length;i++)out("bad-surrogate-"+i,
   table("WhereIWas",table("scenario",badSurrogates[i]),"TIYL",table("originId",badSurrogates[i])));
  for(int i=0;i<32;i++) {
   String value="a"+((char)i)+"b";
   out("control-"+i,table("WhereIWas",table("scenario",value),"TIYL",table("originId",value)));
  }
  out("astral-over-cap",table("WhereIWas",table("scenario","\uD83D\uDE80".repeat(81))));
  String longUnicode="\uD83D\uDE80".repeat(80);
  KahluaTableImpl widest=table("scenario",longUnicode,"lifecycleState",longUnicode,
   "setupFailureReason",longUnicode,"anchorName",longUnicode,"locationName",longUnicode);
  KahluaTableImpl life=table("originId",longUnicode,"scriptedStartId",longUnicode,
   "scriptedPartnerSex",longUnicode,"scriptedStartState",longUnicode,
   "scriptedStartInstanceId",longUnicode,"posterStoryId",longUnicode);
  out("maximum-escaped",table("WhereIWas",widest,"TIYL",life));
 }
}
'''

def pin(path: Path) -> dict:
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def cohorts() -> dict[str,list[str]]:
    result = {}
    tree = ast.parse((ROOT/'tools/world_lab_run.py').read_text(encoding='utf-8-sig'))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in ('OBSERVER_SOURCES','PARTICIPANT_SOURCES'):
                    result[target.id] = list(ast.literal_eval(node.value))
    if set(result) != {'OBSERVER_SOURCES','PARTICIPANT_SOURCES'}:
        raise ValueError('Actual cohort declarations unavailable')
    if HELPER.name not in result['PARTICIPANT_SOURCES']:
        result['PARTICIPANT_SOURCES'].append(HELPER.name)
    return result

class Controls(unittest.TestCase):
    samples: dict = {}
    def context(self, name): return self.samples[name]['context']

    def test_unbound_and_absent_preserve_unknown(self):
        unbound = self.context('unbound')
        self.assertFalse(unbound['observed']); self.assertFalse(unbound['available'])
        self.assertIsNone(unbound['scenarioReady'])
        empty = self.samples['no-data']
        self.assertEqual(empty['dataReads'],0); self.assertEqual(empty['probes'],1)
        self.assertEqual(empty['context']['whereIWas']['status'],'absent')
        self.assertEqual(self.context('empty-root')['tiyl']['status'],'absent')

    def test_api_failure_and_foreign_tables_are_unknown(self):
        for name in ('api-failure','unsupported-table','rewritten'):
            self.assertFalse(self.context(name)['available'])
            self.assertIsNone(self.context(name)['scenarioReady'])
        self.assertEqual(self.samples['api-failure']['dataReads'],0)

    def test_actual_ready_values_and_source_key(self):
        c = self.context('ready')
        self.assertIs(c['scenarioReady'],True)
        self.assertEqual(c['whereIWas']['sourceKey'],'WhereIWas')
        self.assertEqual(c['whereIWas']['status'],'ready')
        self.assertEqual(c['whereIWas']['values']['startX'],8497.5)
        self.assertIs(type(c['whereIWas']['values']['lifecycleVersion']),int)

    def test_pending_and_protected_ready_are_not_safe(self):
        self.assertEqual(self.context('pending')['whereIWas']['status'],'pending')
        for name in ('pending','protected-ready'):
            self.assertIs(self.context(name)['scenarioReady'],False)
        self.assertEqual(self.context('protected-ready')['whereIWas']['status'],'ready')

    def test_failed_recovery_preserves_actual_reason(self):
        c = self.context('failed')
        self.assertEqual(c['whereIWas']['status'],'failed')
        self.assertEqual(c['whereIWas']['values']['setupFailureReason'],'placement failed')
        self.assertIs(c['scenarioReady'],False)

    def test_legacy_source_keeps_missing_protection_unknown(self):
        c = self.context('legacy')
        self.assertEqual(c['whereIWas']['sourceKey'],'KnoxScenarios')
        self.assertEqual(c['whereIWas']['status'],'ready')
        self.assertIsNone(c['scenarioReady'])
        self.assertEqual(self.context('false-current')['whereIWas']['sourceKey'],'KnoxScenarios')

    def test_current_record_precedes_legacy_and_malformed_does_not_fallback(self):
        self.assertEqual(self.context('precedence')['whereIWas']['values']['scenario'],'police_response')
        c = self.context('malformed-current')
        self.assertEqual(c['whereIWas']['sourceKey'],'WhereIWas')
        self.assertEqual(c['whereIWas']['status'],'invalid')
        self.assertEqual(c['whereIWas']['invalidFields'],['$root'])
        self.assertIsNone(c['scenarioReady'])

    def test_tiyl_selection_is_not_an_applied_start(self):
        c = self.context('tiyl-selected')['tiyl']
        self.assertEqual(c['status'],'unknown')
        self.assertEqual(c['values']['originId'],'rosewood')
        self.assertIs(c['values']['outcomesApplied'],False)
        self.assertEqual(self.context('tiyl-pending')['tiyl']['status'],'pending')

    def test_tiyl_acknowledged_placement_retains_actual_coordinates(self):
        c = self.context('tiyl-applied')['tiyl']
        self.assertEqual(c['status'],'ready')
        self.assertEqual(c['values']['originSpawnX'],8052.5)
        self.assertIs(c['values']['originSpawnPending'],False)
        self.assertIsNone(self.context('tiyl-applied')['scenarioReady'])

    def test_scripted_partner_is_not_companion_or_success(self):
        c = self.context('tiyl-partner')['tiyl']
        self.assertEqual(c['status'],'unknown')
        self.assertEqual(c['values']['scriptedStartState'],'partner_active')
        self.assertIs(c['values']['scriptedStartComplete'],False)
        self.assertNotIn('companion',c['values'])

    def test_hostile_types_are_not_converted_or_claimed(self):
        c = self.context('hostile-types')['whereIWas']
        self.assertEqual(c['status'],'invalid')
        self.assertEqual(set(c['invalidFields']), {'scenario','lifecycleVersion','setupComplete','startX','startY','startZ'})
        self.assertEqual(c['values'],{})
        self.assertIsNone(self.context('hostile-types')['scenarioReady'])

    def test_oversized_values_are_rejected_with_bounded_output(self):
        for root, field in (('whereIWas','scenario'),('tiyl','originId')):
            c = self.context('oversized')[root]
            self.assertEqual(c['status'],'invalid')
            self.assertIn(field,c['invalidFields']); self.assertEqual(c['values'],{})
        self.assertLess(len(json.dumps(self.context('oversized'))),1000)

    def test_inherited_origins_and_protection_do_not_become_own_values(self):
        self.assertEqual(self.context('root-metatable')['whereIWas']['status'],'absent')
        c = self.context('field-metatable')
        self.assertNotIn('lifecycleProtected',c['whereIWas']['values'])
        self.assertIsNone(c['scenarioReady'])
        self.assertIs(self.context('poisoned-metatable')['scenarioReady'],True)

    def test_unrelated_data_is_not_enumerated_or_serialized(self):
        self.assertEqual(self.context('small-unrelated'),self.context('large-unrelated'))
        for name in ('small-unrelated','large-unrelated'):
            count=self.samples[name]['lookups']
            if count >= 0: self.assertLessEqual(count,64)
        if self.samples['small-unrelated']['lookups'] >= 0:
            self.assertEqual(self.samples['small-unrelated']['lookups'],self.samples['large-unrelated']['lookups'])

    def test_unsafe_old_text_is_invalid_omitted_and_utf8_safe(self):
        c = self.context('escaped')['whereIWas']
        self.assertEqual(c['status'],'invalid')
        self.assertEqual(c['invalidFields'],['scenario'])
        self.assertEqual(c['values'],{})
        self.assertIsNone(self.context('escaped')['scenarioReady'])
        json.dumps(self.context('escaped'),ensure_ascii=False).encode('utf-8')

    def test_unpaired_surrogates_are_rejected_in_each_source(self):
        for index in range(6):
            with self.subTest(index=index):
                c = self.context(f'bad-surrogate-{index}')
                for root,field in (('whereIWas','scenario'),('tiyl','originId')):
                    self.assertEqual(c[root]['status'],'invalid')
                    self.assertEqual(c[root]['invalidFields'],[field])
                    self.assertEqual(c[root]['values'],{})
                json.dumps(c,ensure_ascii=False).encode('utf-8')

    def test_forbidden_c0_is_rejected_and_permitted_c0_preserved(self):
        for code in range(32):
            with self.subTest(code=code):
                c = self.context(f'control-{code}')
                for root,field in (('whereIWas','scenario'),('tiyl','originId')):
                    if code in (9,10,13):
                        self.assertEqual(c[root]['values'][field],f'a{chr(code)}b')
                        self.assertEqual(c[root]['invalidFields'],[])
                    else:
                        self.assertEqual(c[root]['status'],'invalid')
                        self.assertEqual(c[root]['invalidFields'],[field])
                        self.assertEqual(c[root]['values'],{})
                json.dumps(c,ensure_ascii=False).encode('utf-8')

    def test_valid_astral_quotes_backslash_and_line_breaks_are_preserved(self):
        c = self.context('safe-escapes')
        for root,field in (('whereIWas','scenario'),('tiyl','originId')):
            self.assertEqual(c[root]['values'][field],'a"\\\t\n\r\U0001f680')
            self.assertEqual(c[root]['invalidFields'],[])
        self.assertIsNone(c['scenarioReady'])
        json.dumps(c,ensure_ascii=False).encode('utf-8')

    def test_maximum_escaped_text_keeps_utf16_cap_and_byte_bound(self):
        maximum = self.context('maximum-escaped')
        self.assertTrue(maximum['available'])
        self.assertEqual(maximum['whereIWas']['values']['scenario'],'\U0001f680'*80)
        self.assertEqual(maximum['tiyl']['values']['originId'],'\U0001f680'*80)
        self.assertLessEqual(len(json.dumps(maximum,ensure_ascii=True)),16000)
        json.dumps(maximum,ensure_ascii=False).encode('utf-8')
        self.assertEqual(self.context('astral-over-cap')['whereIWas']['invalidFields'],['scenario'])
        self.assertEqual(self.context('astral-over-cap')['whereIWas']['values'],{})

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    output=args.output.resolve()
    allowed=(ROOT/'_scratch/d2-leisure-01/participant-integration21/native-play04/start-compatibility04').resolve()
    if allowed not in output.parents or output.exists():
        raise ValueError('Use a new evidence output directory under start-compatibility04')
    output.mkdir(parents=True)
    receipt={'schema':'sao.native-start-context-qualification/1','observedAtUtc':datetime.now(timezone.utc).isoformat(),
             'nativeGameStarted':False,'actualPlayerFixture':True,'saveMutation':False,'results':[]}
    declarations=cohorts()
    dependencies=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',JDK/'javac.exe',JDK/'java.exe']
    receipt['dependencies']=[pin(p) for p in dependencies]
    files=[ROOT/'tools/world_lab'/name for name in sorted(set(sum(declarations.values(),[])))]
    files += [ROOT/'tools/world_lab_run.py',Path(__file__).resolve()]
    receipt['sourcePins']=[pin(p) for p in files]
    frozen=output/'frozen'; frozen.mkdir()
    for path in files:
        (frozen/path.name).write_bytes(path.read_bytes())
    cp=os.pathsep.join(str(path) for path in dependencies[:2])

    def command(label, argv):
        run=subprocess.run([str(x) for x in argv],text=True,encoding='utf-8',errors='replace',capture_output=True,timeout=120)
        stdout=output/f'{label}.stdout.txt'; stderr=output/f'{label}.stderr.txt'
        stdout.write_text(run.stdout,encoding='utf-8');stderr.write_text(run.stderr,encoding='utf-8')
        receipt['results'].append({'label':label,'exitCode':run.returncode,'stdout':pin(stdout),'stderr':pin(stderr)})
        if run.returncode: raise RuntimeError(f'{label} failed: {run.stderr[:1000]}')
        return run.stdout

    def controls(label, helper_source):
        target=output/label; target.mkdir()
        source=target/'source'; source.mkdir()
        (source/'StudyStartContext.java').write_text(helper_source,encoding='utf-8')
        for name,content in [('zombie/characters/IsoPlayer.java',PLAYER),('zombie/core/Core.java',CORE),('StartContext04Probe.java',PROBE)]:
            path=source/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(content,encoding='utf-8')
        classes=target/'classes';classes.mkdir()
        command(label+'-compile',[JDK/'javac.exe','-cp',cp,'-d',classes,*sorted(source.rglob('*.java'))])
        text=command(label+'-run',[JDK/'java.exe','-Djava.awt.headless=true','-cp',os.pathsep.join((str(classes),cp)),'StartContext04Probe'])
        samples=dict((name,json.loads(value)) for name,value in (line.split('\t',1) for line in text.splitlines() if '\t' in line))
        Controls.samples=samples
        log=target/'controls.txt'
        with log.open('w',encoding='utf-8') as stream:
            result=unittest.TextTestRunner(stream=stream,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
        receipt['results'].append({'label':label+'-controls','testsRun':result.testsRun,'failures':len(result.failures),
                                  'errors':len(result.errors),'skipped':len(result.skipped),'log':pin(log),
                                  'smallLookups':samples['small-unrelated']['lookups'],'largeLookups':samples['large-unrelated']['lookups']})
        return result

    try:
        for label,names in declarations.items():
            target=output/label.lower();target.mkdir()
            command(label.lower()+'-compile',[JDK/'javac.exe','-cp',cp,'-d',target,*[frozen/name for name in names]])
        original=(frozen/HELPER.name).read_text(encoding='utf-8')
        base=controls('exact-helper',original)
        if not base.wasSuccessful():raise RuntimeError('Exact helper control failure')
        counted=original.replace('private static final Object UNAVAILABLE', 'public static long lookupCount;\n    private static final Object UNAVAILABLE',1)
        counted=counted.replace('return ((KahluaTableImpl)table).delegate.get(key);', 'lookupCount++;\n            return ((KahluaTableImpl)table).delegate.get(key);',1)
        measured=controls('counted-helper',counted)
        if not measured.wasSuccessful():raise RuntimeError('Counted helper control failure')
        inverse={
            'inherited-rawget': original.replace('return ((KahluaTableImpl)table).delegate.get(key);','return table.rawget(key);',1),
            'missing-protection-guard': original.replace('if (r.yes("setupFailed") || r.yes("lifecycleProtected")) return false;',
                                                         'if (r.yes("setupFailed")) return false;',1)
                                                .replace('if (!r.no("setupFailed") || !r.no("lifecycleProtected")) return null;',
                                                         'if (!r.no("setupFailed")) return null;',1),
            'allocating-absent-data': original.replace('player.hasModData() ? player.getModData() : null','player.getModData()',1),
            'enumerating-unrelated': counted.replace('lookupCount++;\n            return ((KahluaTableImpl)table).delegate.get(key);',
                'for (Map.Entry<Object,Object> e : ((KahluaTableImpl)table).delegate.entrySet()) {\n'
                '                lookupCount++; if (key.equals(e.getKey())) return e.getValue();\n'
                '            }\n            return null;',1),
            'unsafe-text': original.replace('value instanceof String s && protocolText(s)',
                                           'value instanceof String s && s.length() <= MAX_STRING_CHARS',1),
        }
        for label,source in inverse.items():
            if source == original or label == 'enumerating-unrelated' and source == counted:
                raise ValueError(f'Inverse anchor missing: {label}')
            result=controls('inverse-'+label,source)
            if result.wasSuccessful() or result.errors:
                raise RuntimeError(f'Inverse did not fail specific assertions: {label}')
        receipt['status']='PASS'
    except Exception as error:
        receipt['status']='FAIL';receipt['error']=f'{type(error).__name__}: {error}'
    receipt['sourcePinsAfter']=[pin(p) for p in files]
    receipt['sourceUnchanged']=receipt['sourcePins']==receipt['sourcePinsAfter']
    if not receipt['sourceUnchanged']:receipt['status']='SOURCE_CHANGED'
    receipt['limits']=['Installed cohorts were compiled; engine player calls were explicit Java fixtures.',
        'Kahlua table implementation and fixed own-key reads were actual installed code; counted copy adds a lookup counter only.',
        'Inverse helpers deliberately restore isolated mistakes, not an historical production preimage.',
        'No actual start, user selection, multiplayer session, companion admission, loaded package or visual acceptance is claimed.']
    path=output/'receipt.json';path.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':receipt['status'],'receipt':str(path),'sha256':pin(path)['sha256'],
                      'sourceUnchanged':receipt['sourceUnchanged'],'error':receipt.get('error')}))
    return 0 if receipt['status']=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())
