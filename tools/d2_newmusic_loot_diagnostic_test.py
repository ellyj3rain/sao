"""Full source controller on installed Kahlua; diagnostic lexical scope and leaf package custody."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile

import d2_source_package as package

ROOT = Path(__file__).resolve().parent.parent
MOD = ROOT / "mod/42.20"
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
PATH = "media/lua/server/NMServerSandboxLootController.lua"
OWNER = MOD / PATH
VAULT = MOD / "media/SAOSources/NewMusic" / PATH
CASES = ROOT / "tools/d2_newmusic_loot_diagnostic/cases.lua"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prelude(procedural, suburbs, ready, diagnostic, poisoned):
    return '\n'.join([
        "CHECKS=0; LOGS={}; HOOKS={}; REQUESTS=0",
        "function require(name) REQUESTS=REQUESTS+1 end",
        "SAO={SourceIntegration={active=function(id) return id=='NewMusic' end}}",
        "NMLootDiagnostics={formatRawSandboxLootSettings=function() return '' end,logSandboxLoot=function(enabled,tag,detail) assert(enabled); LOGS[#LOGS+1]={tag=tag,detail=detail} end}",
        "NMCore={isSubsystemDebugEnabled=function(name) return name=='loot' end}",
        "Events={}; for _,name in ipairs({'OnInitGlobalModData','OnPreDistributionMerge','OnPostDistributionMerge','OnFillContainer','OnTick'}) do local n=name; Events[n]={Add=function(fn) assert(HOOKS[n]==nil); HOOKS[n]=fn end,Remove=function(fn) assert(HOOKS[n]==fn); HOOKS[n]=nil end} end",
        "ProceduralDistributions="+procedural,
        "SuburbsDistributions="+suburbs,
        "ORIGINAL_PROCEDURAL=ProceduralDistributions; ORIGINAL_SUBURBS=SuburbsDistributions",
        "EXPECT_READY="+str(ready).lower()+"; EXPECT_DIAGNOSTIC="+str(diagnostic).lower(),
        "areDistributionTablesReady="+poisoned,
        "",
    ]).encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--before", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    prior = args.before.resolve()
    manifest_path = MOD / "media/SAOSources/manifest.json"
    registry_path = MOD / "media/lua/shared/SAO_SourcePackageManifest.lua"
    sentinel_path = MOD / "media/SAOSources/NewMusic/package.txt"
    jars = [GAME / "projectzomboid.jar", *sorted((GAME / "jars").glob("*.jar"))]
    inputs = [Path(__file__), CASES, ROOT / "tools/d2_source_package.py", OWNER, VAULT,
              manifest_path, registry_path, sentinel_path, ROOT / "tools/luacheck/LuaRun.java",
              ROOT / "tools/luacheck/LuaSyntax.java", GAME / "stdlib.lua", *jars,
              *sorted(prior.iterdir())]
    before = {str(p): sha(p) for p in inputs}
    receipt = {"status": "INCOMPLETE", "boundary": __doc__, "inputsBefore": before, "runs": []}
    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2)+"\n")
    try:
        old = json.loads((prior / "2-manifest.json").read_text())
        new = json.loads(manifest_path.read_text())
        different = [(a,b) for a,b in zip(old['files'],new['files']) if a != b]
        assert len(old['files']) == len(new['files']) == 89521
        assert len(different) == 1 and different[0][1]['sourceId'] == 'NewMusic' and different[0][1]['selectedPath'] == PATH
        old_row, row = different[0]
        assert {k:v for k,v in old_row.items() if k not in {'destinationSha256','bytes','adaptations'}} == {k:v for k,v in row.items() if k not in {'destinationSha256','bytes','adaptations'}}
        assert {k:v for k,v in old.items() if k not in {'sources','files'}} == {k:v for k,v in new.items() if k not in {'sources','files'}}
        assert {k:v for k,v in old['sources'].items() if k != 'NewMusic'} == {k:v for k,v in new['sources'].items() if k != 'NewMusic'}
        assert {k:v for k,v in old['sources']['NewMusic'].items() if k != 'seal'} == {k:v for k,v in new['sources']['NewMusic'].items() if k != 'seal'}
        assert sha(VAULT) == row['sourceSha256'] == sha(prior/'5-NMServerSandboxLootController.lua')
        raw, adaptations = package.adapt_lua(VAULT.read_bytes(),'NewMusic')
        assert raw == (prior/'0-NMServerSandboxLootController.lua').read_bytes()
        generated, extra = package.adapt_newmusic_loot_diagnostic(raw,PATH)
        assert generated == OWNER.read_bytes() and row['adaptations'] == adaptations + extra
        # Inverse lexical patch is byte-exact: every gameplay function/predicate,
        # source data, logging argument and event binding retains its source body.
        inverse = generated.replace(b'local logLootBootstrap\nlocal areDistributionTablesReady\n',b'local logLootBootstrap\n',1).replace(b'areDistributionTablesReady = function()',b'local function areDistributionTablesReady()',1)
        assert inverse == raw
        assert package.adapt_newmusic_loot_diagnostic(raw,'media/lua/server/unrelated.lua') == (raw,[])
        try:
            package.adapt_newmusic_loot_diagnostic(raw.replace(b'local logLootBootstrap\n',b'local renamedBootstrap\n'),PATH)
        except ValueError:
            pass
        else:
            raise AssertionError('changed source anchor did not fail closed')
        seal = package.sha(json.dumps([r for r in new['files'] if r['sourceId']=='NewMusic'],sort_keys=True,separators=(',',':')).encode())
        assert new['sources']['NewMusic']['seal'] == seal
        assert sentinel_path.read_bytes() == ('SAO-OWNED-SOURCE/1 NewMusic '+seal+'\n').encode()
        assert registry_path.read_bytes() == (prior/'3-SAO_SourcePackageManifest.lua').read_bytes().replace(old['sources']['NewMusic']['seal'].encode(),seal.encode(),1)
        receipt['package'] = {'changedRows':1,'unchangedRows':89520,'unchangedOtherFamilySeals':6,'vaultUnchanged':True,'inverseGameplayBytesExact':True,'futureImporterByteIdempotence':True,'sourceAnchorRefusal':True,'newMusicSeal':seal}
        with tempfile.TemporaryDirectory(prefix='sao-loot-diagnostic-') as temporary:
            work = Path(temporary); (work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
            # Real build_plan hook on one exact source leaf, with original metadata;
            # no whole package recopy or unrelated source-family recomputation.
            source_spec = package.SOURCES['NewMusic']
            workshop = work/'workshop'; selected = workshop/source_spec[0]/source_spec[1]
            fixture_source = selected/PATH; fixture_source.parent.mkdir(parents=True)
            fixture_source.write_bytes(VAULT.read_bytes())
            info = MOD/'media/SAOSources/NewMusic/provenance/selected-mod.info'
            (selected/'mod.info').write_bytes(info.read_bytes())
            receipt['fixtureMetadataSha256'] = sha(info)
            all_sources = package.SOURCES
            package.SOURCES = {'NewMusic':source_spec}
            try:
                plan, outputs, collisions = package.build_plan(workshop,work/'empty-mod')
                assert not collisions and outputs[PATH] == generated
                generated_row = plan['files'][0]
                assert generated_row['adaptations'] == row['adaptations']
                assert generated_row['destinationSha256'] == row['destinationSha256']
                original_adapter = package.adapt_newmusic_loot_diagnostic
                package.adapt_newmusic_loot_diagnostic = lambda payload, path:(payload,[])
                try:
                    bad_plan, bad_outputs, _ = package.build_plan(workshop,work/'empty-mod')
                    assert bad_outputs[PATH] == raw and bad_outputs[PATH] != generated
                    assert bad_plan['sources']['NewMusic']['seal'] != plan['sources']['NewMusic']['seal']
                finally:
                    package.adapt_newmusic_loot_diagnostic = original_adapter
            finally:
                package.SOURCES = all_sources
            assert package.sha(raw) != row['destinationSha256']
            assert old['sources']['NewMusic']['seal'] != seal
            receipt['package']['controls'] = ['restored-importer-hook-omission-changes-runtime-and-generated-seal','old-destination-fails-current-row-hash','old-family-seal-fails-current-row-seal']
            receipt['package']['actualBuildPlanHook'] = True
            cp = os.pathsep.join(map(str,jars))
            compile_result = subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(ROOT/'tools/luacheck/LuaRun.java'),str(ROOT/'tools/luacheck/LuaSyntax.java')],capture_output=True)
            (out/'compile.log').write_bytes(compile_result.stdout+compile_result.stderr); assert compile_result.returncode == 0
            syntax = subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'LuaSyntax',str(OWNER),str(registry_path),str(CASES)],capture_output=True,cwd=work)
            (out/'syntax.log').write_bytes(syntax.stdout+syntax.stderr); assert syntax.returncode == 0
            receipt['syntaxChecks'] = 6
            scenarios = [
                ('procedural','{list={},marker="procedural-custody"}','nil',True,'nil'),
                ('suburbs','nil','{marker="suburbs-custody"}',True,'nil'),
                ('absent','nil','nil',False,'nil'),
                ('malformed','{list=false,marker="procedural-custody"}','false',False,'nil'),
                ('poisoned-false','{list={},marker="procedural-custody"}','nil',True,'function() return false end'),
                ('poisoned-true','nil','nil',False,'function() return true end'),
            ]
            for variant in ('fixed','original','restored-defect'):
                for name,procedural,suburbs,ready,poisoned in scenarios:
                    if variant == 'restored-defect' and name != 'procedural':
                        continue
                    # Original run documents the defect separately while measuring
                    # identical actual gameplay state/callbacks in both versions.
                    diagnostic = ready if variant != 'original' else poisoned == 'function() return true end'
                    pre = out/(variant+'-'+name+'-prelude.lua'); pre.write_bytes(prelude(procedural,suburbs,ready,diagnostic,poisoned))
                    source = out/(variant+'-'+name+'-controller.lua'); source.write_bytes(generated if variant=='fixed' else inverse)
                    result = subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'LuaRun',str(pre),str(source),str(CASES),'--','RESULT'],cwd=work,capture_output=True,timeout=40)
                    log = out/(variant+'-'+name+'.log'); log.write_bytes(result.stdout+result.stderr)
                    text = log.read_text(errors='replace'); receipt['runs'].append({'variant':variant,'scenario':name,'exit':result.returncode,'logSha256':sha(log)})
                    if variant == 'restored-defect':
                        assert result.returncode != 0 and 'D2_LOOT_DIAGNOSTIC:lexical_readiness_matches_current_distribution_tables' in text, text
                    else:
                        assert result.returncode == 0 and 'PASS D2 loot diagnostic' in text, text
                        receipt['runs'][-1]['gameplayState'] = text.split(' | GAMEPLAY_STATE ',1)[1].strip()
                    save()
            for scenario in scenarios:
                states = [r['gameplayState'] for r in receipt['runs'] if r['scenario']==scenario[0] and r['variant']!='restored-defect']
                assert len(states) == 2 and states[0] == states[1]
        receipt['inputsAfter'] = {str(p):sha(p) for p in inputs}; assert before == receipt['inputsAfter']
        receipt['status']='PASS'; receipt['controls']=1; receipt['packageControls']=3; receipt['nativeRuns']=12; save()
        print('PASS 12 full-controller native runs, 1 restored lexical defect, 3 package controls, 6 syntax checks; one manifest row changed')
    except Exception as error:
        receipt['status']='FAIL'; receipt['error']=str(error); save(); raise


if __name__ == '__main__':
    main()
