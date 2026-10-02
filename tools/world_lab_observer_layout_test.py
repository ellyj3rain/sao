import copy
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from types import SimpleNamespace

import world_lab as Lab
import world_lab_observer_layout as Layout
import world_lab_session as Session
import world_lab_run as Run


class ObserverLayoutTests(unittest.TestCase):
    def setUp(self):
        self.definition = {"extent": dict(minCellX=13, minCellY=42, cellsX=2, cellsY=5),
                           "observation": {"sites": [dict(id="original", label="Original", x=3426, y=10910, z=0)]}}
        self.layout = {"schema": "sao-study-observer-layout/1", "sites": [
            dict(id="west", label="West residence", x=3397, y=10938, z=0),
            dict(id="east", label="East residence", x=3448, y=10912, z=0)]}

    def test_saved_layout_changes_only_observer_selection(self):
        before = copy.deepcopy(self.definition)
        receipt = dict(save="retained-world", packageSha256="same-package", mods={"original": "same"})
        original = copy.deepcopy(receipt)
        Layout.bind(receipt, self.layout)
        self.assertEqual(Layout.select(None, receipt, self.definition), self.layout)
        self.assertEqual(Layout.sites(receipt, self.definition), self.layout["sites"])
        self.assertEqual({k: receipt[k] for k in original}, original)
        self.assertEqual(self.definition, before)
        self.assertEqual(Layout.sites({}, self.definition), before["observation"]["sites"])

    def test_rejects_unsealed_or_changed_layout(self):
        receipt = {}; Layout.bind(receipt, self.layout)
        for key in ("observerLayout", "observerLayoutSha256"):
            bad = copy.deepcopy(receipt); del bad[key]
            with self.assertRaises(ValueError): Layout.from_receipt(bad, self.definition)
        receipt["observerLayout"]["sites"][0]["x"] += 1
        with self.assertRaises(ValueError): Layout.from_receipt(receipt, self.definition)

    def test_rejects_invalid_areas_even_with_new_hash(self):
        changes = [lambda x: x.update(schema="wrong"), lambda x: x.update(sites=[]),
                   lambda x: x["sites"].append(copy.deepcopy(x["sites"][0])),
                   lambda x: x["sites"][0].update(x=True),
                   lambda x: x["sites"][0].update(x=float('nan')),
                   lambda x: x["sites"][0].update(x=3840),
                   lambda x: x["sites"][0].update(x=3839.99999),
                   lambda x: x["sites"][0].update(z=32),
                   lambda x: x["sites"][0].update(label="bad\nlabel"),
                   lambda x: x["sites"][0].update(personId="not-an-area-field"),
                   lambda x: x["sites"][1].update(x=3397,y=10938,z=0),
                   lambda x: x["sites"][1].update(x=3397.00001,y=10938,z=0)]
        for change in changes:
            value = copy.deepcopy(self.layout); change(value)
            with self.subTest(value=value), self.assertRaises(ValueError): Layout.validate(value, self.definition)

    def test_resize_preserves_other_cache_options(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); path = root/'options.ini'
            path.write_text('version=8\nwidth=960\nheight=540\nsoundVolume=0\n', encoding='utf-8')
            Layout.resize(root, self.layout['sites'])
            self.assertEqual(path.read_text(), 'version=8\nwidth=1920\nheight=1080\nsoundVolume=0\n')
            Layout.resize(root, self.layout['sites'][:1])
            self.assertIn('width=960\nheight=540',path.read_text())
            path.write_text('width=960\nwidth=960\nheight=540\n')
            with self.assertRaises(ValueError): Layout.resize(root,self.layout['sites'])

    def test_session_forwards_layout_on_resume(self):
        args=SimpleNamespace(package=Path('package'),out=Path('session'),game=Path('game'),jdk=Path('jdk'),
                             window='hidden',observer_layout=Path('layout.json'))
        command=Session.runner_command(args,True,600)
        self.assertIn('--resume',command)
        self.assertEqual(command[command.index('--observer-layout')+1],'layout.json')

    def test_declared_areas_require_simultaneous_native_images(self):
        sites = [site | {'slot':i} for i,site in enumerate(self.layout['sites'])]
        evidence = {'state':{'sites':sites},'viewport':{'views':copy.deepcopy(sites)}}
        Layout.verify_evidence(self.layout,evidence)
        del evidence['viewport']['views']
        with self.assertRaisesRegex(ValueError,'native regional pixels missing'):
            Layout.verify_evidence(self.layout,evidence)
        evidence['viewport']['views']=sites
        evidence['state']['sites']=sites[:1]
        with self.assertRaisesRegex(ValueError,'native observer areas differ'):
            Layout.verify_evidence(self.layout,evidence)

    def test_production_resume_rejects_old_receipt_before_applying_replacement(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name); layout_path=root/'layout.json'
            layout_path.write_bytes(Lab.canonical(self.layout))
            saved=root/'saved-input';saved.write_bytes(b'prior-world-bytes')
            args=SimpleNamespace(package=root/'package',out=root/'run',game=root/'game',host='observer',
                                 resume=True,observer_layout=layout_path,mod=[],profile=None,
                                 enable_mod=[],disable_mod=[],refresh_observer_adapter=True)
            with patch.object(Lab,'verify_package',return_value=({},self.definition)), \
                 patch.object(Run,'verify_run',side_effect=ValueError('old receipt differs')) as verifier, \
                 patch.object(Layout,'bind') as binding, \
                 patch.object(Run,'refresh_observer_adapter') as refresh:
                with self.assertRaisesRegex(ValueError,'old receipt differs'): Run.run(args)
                verifier.assert_called_once()
                binding.assert_not_called()
                refresh.assert_not_called()
            self.assertEqual(saved.read_bytes(),b'prior-world-bytes')
            self.assertFalse((root/'run').exists())

    def test_adapter_refresh_preserves_prior_and_rejects_tampered_provenance(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name); agent=root/'StudyLoadingAgent.jar'; agent.write_bytes(b'old-host')
            attempt=root/'attempts/0004'; attempt.mkdir(parents=True)
            previous={'loadingAgentSha256':Run.digest(agent),'launchNumber':3,'save':'same-world','mods':{'same':'modules'}}
            receipt=copy.deepcopy(previous)
            def build(destination, game, jdk, source=None):
                self.assertEqual(source,destination)
                self.assertTrue((source/'StudyObserver.java').is_file())
                path=destination/'StudyLoadingAgent.jar';path.write_bytes(b'new-host');return path
            with patch.object(Run,'build_observer_adapter',side_effect=build):
                Run.refresh_observer_adapter(root,attempt,None,None,previous,receipt)
            self.assertEqual(agent.read_bytes(),b'new-host')
            self.assertEqual((attempt/'observer-adapter/previous.jar').read_bytes(),b'old-host')
            self.assertEqual(Lab.load(attempt/'observer-adapter/previous-run.json'),previous)
            self.assertEqual(receipt['save'],previous['save']);self.assertEqual(receipt['mods'],previous['mods'])
            Run.verify_observer_adapter(root,receipt)
            (attempt/'observer-adapter/StudyObserver.java').write_text('changed')
            with self.assertRaisesRegex(ValueError,'source differs'): Run.verify_observer_adapter(root,receipt)

    def test_failed_adapter_build_keeps_old_adapter_and_receipt(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);agent=root/'StudyLoadingAgent.jar';agent.write_bytes(b'old-host')
            attempt=root/'attempts/0004';attempt.mkdir(parents=True)
            previous={'loadingAgentSha256':Run.digest(agent)};receipt=copy.deepcopy(previous)
            with patch.object(Run,'build_observer_adapter',side_effect=ValueError('compiler failed')):
                with self.assertRaisesRegex(ValueError,'compiler failed'):
                    Run.refresh_attempt_adapter(root,attempt,None,None,previous,receipt)
            self.assertEqual(agent.read_bytes(),b'old-host');self.assertEqual(receipt,previous)
            self.assertFalse(attempt.exists())
            self.assertEqual(len(list((root/'adapter-failures').iterdir())),1)
            attempt.mkdir()

    def test_partial_staging_copy_does_not_damage_saved_adapter(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);agent=root/'StudyLoadingAgent.jar';agent.write_bytes(b'old-host')
            attempt=root/'attempts/0004';attempt.mkdir(parents=True)
            previous={'loadingAgentSha256':Run.digest(agent),'launchNumber':3};receipt=copy.deepcopy(previous)
            original=Run.shutil.copy2
            def copy_candidate(source,target,*args,**kwargs):
                if Path(target).name=='activate.jar':
                    Path(target).write_bytes(b'partial')
                    raise OSError('injected partial copy')
                return original(source,target,*args,**kwargs)
            def build(destination,game,jdk,source=None):
                path=destination/'StudyLoadingAgent.jar';path.write_bytes(b'new-host');return path
            with patch.object(Run,'build_observer_adapter',side_effect=build),patch.object(Run.shutil,'copy2',side_effect=copy_candidate):
                with self.assertRaisesRegex(OSError,'partial copy'):
                    Run.refresh_attempt_adapter(root,attempt,None,None,previous,receipt)
            self.assertEqual(agent.read_bytes(),b'old-host');self.assertEqual(receipt,previous)
            self.assertFalse(attempt.exists())
            self.assertEqual(len(list((root/'adapter-failures').iterdir())),1)

    def test_failed_prelaunch_restores_adapter_bootstrap_receipt_and_options(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            relative=['StudyLoadingAgent.jar','run.json',
                      'cache/mods/map/42.20/media/lua/client/ZZStudyLaunch.lua','cache/options.ini']
            for value in relative:
                path=root/value;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(value.encode())
            previous={'mapName':'map','launchNumber':3}
            with self.assertRaisesRegex(OSError,'prelaunch failed'):
                with Run.observer_resume_transaction(root,previous):
                    (root/'attempts/0004').mkdir(parents=True)
                    for value in relative: (root/value).write_bytes(b'changed')
                    raise OSError('prelaunch failed')
            for value in relative: self.assertEqual((root/value).read_bytes(),value.encode())
            self.assertFalse((root/'attempts/0004').exists())
            self.assertEqual(len(list((root/'adapter-failures').iterdir())),1)
            with Run.observer_resume_transaction(root,previous):
                (root/'attempts/0004').mkdir()
                (root/'StudyLoadingAgent.jar').write_bytes(b'accepted')
            self.assertEqual((root/'StudyLoadingAgent.jar').read_bytes(),b'accepted')

    def test_production_source_controls(self):
        source=Path(Layout.__file__).read_text(encoding='utf-8')
        controls=[('Lab.seal(value) == receipt["observerLayoutSha256"]','True','seal'),
                  ('if len(expected) > 1:','if False:','regional')]
        for before,after,kind in controls:
            self.assertEqual(source.count(before),1)
            changed=source.replace(before,after)
            self.assertNotEqual(source,changed)
            namespace={'__name__':'controlled_layout'}
            exec(compile(changed,str(Layout.__file__),'exec'),namespace)
            if kind=='seal':
                receipt={};Layout.bind(receipt,copy.deepcopy(self.layout));receipt['observerLayout']['sites'][0]['x']+=1
                with self.assertRaisesRegex(ValueError,'seal differs'): Layout.from_receipt(receipt,self.definition)
                self.assertIsNotNone(namespace['from_receipt'](receipt,self.definition))
            else:
                sites=[site|{'slot':i} for i,site in enumerate(self.layout['sites'])]
                evidence={'state':{'sites':sites},'viewport':{}}
                with self.assertRaisesRegex(ValueError,'regional pixels missing'): Layout.verify_evidence(self.layout,evidence)
                self.assertIsNone(namespace['verify_evidence'](self.layout,evidence))


if __name__ == '__main__':
    result=unittest.main(exit=False).result
    if not result.wasSuccessful(): raise SystemExit(1)
    print('Border 233: sealed independent observer layouts and recoverable adapter replacement')
