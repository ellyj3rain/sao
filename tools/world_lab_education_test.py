"""Scoped source-loading checks and restored-defect controls for native education."""
import copy
import argparse
import hashlib
import inspect
import json
import tempfile
import subprocess
import types
import unittest
from pathlib import Path
from types import SimpleNamespace

import world_lab_education as E


class EducationSourceChecks(unittest.TestCase):
    def setUp(self):
        self.world, self.bank, self.archive = 'a'*64, 'b'*64, 'c'*64
        self.registry = dict(schema='speakeasy-person-education-runtime-registry/2',
            worldDefinitionSha256=self.world,sourceBankSha256=self.bank,sourceArchiveSha256=self.archive,
            rows=[{'personId':'sao-1'}])
        self.raw=json.dumps(self.registry)
        self.source=dict(raw=self.raw,rawSha256=hashlib.sha256(self.raw.encode()).hexdigest(),
            definitionSha256=self.world,sourceBankSha256=self.bank,sourceArchiveSha256=self.archive)

    def test_source_and_legacy_schema(self):
        self.assertEqual(E.validate(self.source,self.world),self.source)
        source=dict(self.source,raw=json.dumps(dict(self.registry,schema='speakeasy-person-education-runtime-registry/1')))
        source['rawSha256']=hashlib.sha256(source['raw'].encode()).hexdigest()
        self.assertEqual(E.validate(source,self.world),source)

    def test_authored_schema_saved_source_and_unknown_version(self):
        def source_for(schema):
            raw=json.dumps(dict(self.registry,schema=schema))
            return dict(self.source,raw=raw,rawSha256=hashlib.sha256(raw.encode()).hexdigest())
        authored=source_for('speakeasy-person-education-runtime-registry/3')
        self.assertEqual(E.validate(authored,self.world),authored)
        omitted=SimpleNamespace(education_registry=None,education_bank_sha256=None,
            education_archive_sha256=None)
        self.assertEqual(E.select(omitted,self.world,{'educationSource':authored}),authored)
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'registry.json';path.write_text(authored['raw'],encoding='utf-8')
            args=SimpleNamespace(education_registry=path,education_bank_sha256=self.bank,
                education_archive_sha256=self.archive)
            self.assertEqual(E.select(args,self.world),authored)
            with self.assertRaises(ValueError,msg='saved legacy registry upgraded'):
                E.select(args,self.world,{'educationSource':self.source})
        for schema in ('speakeasy-person-education-runtime-registry/4','registry/3',None):
            with self.subTest(schema=schema),self.assertRaises(ValueError,msg='unknown schema admitted'):
                E.validate(source_for(schema),self.world)

    def test_exact_shape_and_source_identity(self):
        for bad in (dict(self.source,extra=True),None,dict(self.source,raw=False),
                    dict(self.source,definitionSha256='z'*64),dict(self.source,raw='')):
            with self.subTest(bad=bad),self.assertRaises((ValueError,TypeError)):
                E.validate(bad,self.world)
        with self.assertRaises(ValueError,msg='changed raw registry accepted'):
            E.validate(dict(self.source,rawSha256='d'*64),self.world)

    def test_world_and_independent_source_pins(self):
        with self.assertRaises(ValueError):E.validate(self.source,'d'*64)
        for field in ('sourceBankSha256','sourceArchiveSha256'):
            with self.subTest(field=field),self.assertRaises(ValueError,msg='independent source pin ignored'):
                E.validate(dict(self.source,**{field:'d'*64}),self.world)

    def test_duplicate_json_and_bound(self):
        source=dict(self.source,raw=self.raw[:-1]+',"schema":"other"}')
        source['rawSha256']=hashlib.sha256(source['raw'].encode()).hexdigest()
        with self.assertRaises(ValueError):E.validate(source,self.world)
        old_bound=E.MAX_BYTES
        try:
            E.MAX_BYTES=len(self.raw.encode())-1
            with self.assertRaises(ValueError):E.validate(self.source,self.world)
        finally:E.MAX_BYTES=old_bound

    def test_select_and_saved_continuity(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'registry.json';path.write_text(self.raw,encoding='utf-8')
            args=SimpleNamespace(education_registry=path,education_bank_sha256=self.bank,
                education_archive_sha256=self.archive)
            self.assertEqual(E.select(args,self.world),self.source)
            previous={'educationSource':copy.deepcopy(self.source)}
            self.assertEqual(E.select(args,self.world,previous),self.source)
            with self.assertRaises(ValueError,msg='saved education source changed'):
                E.select(args,self.world,{'educationSource':dict(self.source,raw='changed')})
            with self.assertRaises(ValueError):E.select(args,self.world,{})
            omitted=SimpleNamespace(education_registry=None,education_bank_sha256=None,
                education_archive_sha256=None)
            self.assertEqual(E.select(omitted,self.world,previous),self.source)
            self.assertIsNone(E.select(omitted,self.world))
            with self.assertRaises(ValueError):E.select(SimpleNamespace(education_bank_sha256=self.bank),self.world)
            args.education_archive_sha256=None
            with self.assertRaises(ValueError):E.select(args,self.world)

    def test_native_binding_is_observed(self):
        marker='[StudyWorld] education source bound='+self.source['rawSha256']+' save=fixture'
        E.verify_binding(self.source,'fixture','LOG : Lua > '+marker+'\n')
        for save,log in (('other',marker),('fixture',marker+'-suffix'),('fixture',''),('bad save',marker)):
            with self.subTest(save=save,log=log),self.assertRaises(ValueError,msg='unobserved native binding accepted'):
                E.verify_binding(self.source,save,log)

    def test_session_forwarding(self):
        import world_lab_session as Session
        args=SimpleNamespace(package=Path('package'),out=Path('out'),game=Path('game'),jdk=Path('jdk'),
            window='hidden',mod=[],profile=None,education_registry=Path('registry.json'),
            education_bank_sha256=self.bank,education_archive_sha256=self.archive)
        for resumed in (False,True):
            command=Session.runner_command(args,resumed,300)
            for flag,value in (('--education-registry','registry.json'),('--education-bank-sha256',self.bank),
                               ('--education-archive-sha256',self.archive)):
                self.assertIn(flag,command)
                self.assertEqual(command[command.index(flag)+1],value)


def suite():
    return unittest.defaultTestLoader.loadTestsFromTestCase(EducationSourceChecks)


def runtime_checks():
    import world_lab as Lab
    root=Path(__file__).resolve().parent.parent
    game=Path(r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
    jdk=Path(r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
    out=root/'_scratch/d1-shared-reasoning/background-loader'
    out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sao-background-loader-') as temporary:
        target=Path(temporary)
        compiled=subprocess.run([str(jdk/'javac.exe'),'-cp',str(game/'projectzomboid.jar'),
            '-d',str(target),str(root/'tools/luacheck/LuaRun.java')],capture_output=True,text=True)
        if compiled.returncode:raise AssertionError('native compiler failed: '+compiled.stderr)
        definition=Lab.load(root/'tools/world_lab/definition.example.json')
        manifest=Lab.build(definition,target/'package',game)
        config={**definition,'mapName':manifest['mapName'],'definitionSha256':Lab.seal(definition),
            'engineJarSha256':manifest['engine']['jar']['sha256'],'observerSha256':manifest['observerSha256']}
        source=Lab.TEMPLATE.read_text(encoding='utf-8')
        fixture=(root/'tools/world_lab/RuntimeChecks.lua').read_text(encoding='utf-8')
        controls=[('genesis owner','ok, reason = owner.stageEducationRegistry(education.raw, education.rawSha256,',
            'ok, reason = (function() return true end)(education.raw, education.rawSha256,',
            'education source was not staged before genesis'),
            ('saved binding','if newGame then\n            ok, reason = owner.stageEducationRegistry',
             'if true then\n            ok, reason = owner.stageEducationRegistry','education registry restaged on saved resume'),
            ('world identity','assert(education.definitionSha256 == Config.definitionSha256,',
             'assert(true,','foreign education study admitted'),
            ('native refusal','assert(ok, reason)\n        print("[StudyWorld] education source bound="',
             'assert(true, reason)\n        print("[StudyWorld] education source bound="','native education binding refusal was ignored')]
        rows=[]
        variants=[('baseline',source,None)]
        for label,anchor,replacement,reason in controls:
            if source.count(anchor)!=1:raise AssertionError('runtime control anchor differs: '+label)
            variants.append((label,source.replace(anchor,replacement,1),reason))
        for label,content,reason in variants:
            script=target/'checks.lua'
            script.write_text('local Config = '+Lab.lua(config)+'\n'+fixture+
                '\nlocal Study=(function()\n'+content+'\nend)()\nRESULT=RunStudyChecks(Study)\n',encoding='utf-8')
            command=[str(game/'jre64/bin/java.exe'),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                '-cp',str(game/'projectzomboid.jar')+';'+str(target),'LuaRun',str(script),'--','RESULT']
            result=subprocess.run(command,cwd=game,capture_output=True,text=True,encoding='utf-8',timeout=90)
            output=result.stdout+result.stderr
            log=out/(label.replace(' ','-')+'.log');log.write_text(output,encoding='utf-8')
            if reason is None:
                if result.returncode:raise AssertionError('native runtime baseline failed: '+output[-6000:])
            elif result.returncode==0 or reason not in output:
                raise AssertionError('runtime control did not fail for stated reason: '+label+'\n'+output[-6000:])
            rows.append(dict(case=label,exitCode=result.returncode,log=str(log),
                sha256=hashlib.sha256(log.read_bytes()).hexdigest(),reason=reason))
        inputs=[root/'tools/world_lab/StudyWorld.lua',root/'tools/world_lab/RuntimeChecks.lua',
            Path(__file__),root/'tools/luacheck/LuaRun.java',game/'projectzomboid.jar']
        receipt=dict(schema='sao.education-loader-runtime-proof/1',status='PASS',cases=rows,
            inputs=[dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()) for path in inputs],
            boundary='Actual Study.start and installed Kahlua execute; population/registry receivers are controlled. Native semantic/source admission and gameplay require separate proof.')
        (out/'runtime-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print('PASS actual study runtime fixture; 4 education handoff controls')
    return 0


def main():
    global E
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--part',choices=('source','runtime'),default='source')
    if parser.parse_args().part=='runtime':return runtime_checks()
    result=unittest.TextTestRunner(verbosity=1).run(suite())
    if not result.wasSuccessful():return 1
    original=E;source=inspect.getsource(original)
    controls=[('raw identity', 'hashlib.sha256(raw.encode("utf-8")).hexdigest() == value["rawSha256"]',
               'True', 'changed raw registry accepted'),
              ('independent source pin', 'registry.get(field) == value[field]', 'True', 'independent source pin ignored'),
              ('saved registry replacement', 'previous.get("educationSource") == value', 'True', 'saved education source changed'),
              ('native binding witness', 'any(line.rstrip().endswith(marker) for line in stdout.splitlines())',
               'True', 'unobserved native binding accepted')]
    for label,anchor,replacement,expected in controls:
        if source.count(anchor)!=1:raise AssertionError('control anchor differs: '+label)
        variant=types.ModuleType('world_lab_education_control');variant.__file__=original.__file__
        exec(compile(source.replace(anchor,replacement,1),original.__file__,'exec'),variant.__dict__)
        E=variant
        result=unittest.TestResult();suite().run(result)
        failures='\n'.join(message for _,message in result.failures)
        if result.errors or expected not in failures:raise AssertionError('wrong control failure: '+label)
        print('PASS restored-defect control: '+label)
    E=original
    print('PASS education source loader: 8 checks, 4 restored-defect controls; semantic admission remains native-owned')
    return 0


if __name__=='__main__':raise SystemExit(main())
