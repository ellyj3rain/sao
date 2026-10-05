import importlib.util
import json
import subprocess
import hashlib
import tempfile
from pathlib import Path
import sys
import types
import uuid
from types import SimpleNamespace
from unittest.mock import patch


TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("world_lab_session", TOOLS / "world_lab_session.py")
Session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(Session)


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def recovery_credit_checks(module=Session):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'study-session.json'
        state = module.new_state('Recovery credit', 180, False)
        state.update(status='failed')
        receipt = {'status': 'completed', 'exitCode': 0, 'runtimeErrors': [],
                   'launchNumber': 1, 'lastHours': 3.2514190673828125,
                   'terminal': {'startHours': 2.0, 'endHours': 3.288463592529297,
                                'nativeSaveReturned': True, 'stopReason': 'wall-time-limit'}}
        elapsed = receipt['terminal']['endHours'] - receipt['terminal']['startHours']
        original_receipt = json.loads(json.dumps(receipt))
        module.recover_failed_save(path, state, receipt)
        check(state['accumulatedWorldHours'] == elapsed, 'newly completed attempt lost its first credit')
        check(state['attempt'] == 1 and state['worldHours'] == receipt['lastHours'],
              'completed recovery did not persist its credit cursor')
        check(module.Lab.load(path) == state, 'recovery cursor differs after reload')
        saved_bytes = path.read_bytes()
        module.recover_failed_save(path, state, receipt)
        check(path.read_bytes() == saved_bytes, 'saved recovery unexpectedly rewrote its state')
        # Reproduce a wrong command/prelaunch failure after normal native save.
        for ignored in range(2):
            state = module.Lab.load(path)
            module.save_state(path, state, status='failed', canContinue=False)
            state = module.Lab.load(path)
            module.recover_failed_save(path, state, receipt)
            check(state['accumulatedWorldHours'] == elapsed,
                  'already credited predecessor was credited again after prelaunch failure')
        # During a real new native attempt, attempt already advances before the
        # terminal receipt; worldHours remains the previous credit cursor.
        next_receipt = {**receipt, 'launchNumber': 2, 'lastHours': 3.75,
                        'terminal': {**receipt['terminal'], 'startHours': 3.288463592529297,
                                     'endHours': 3.788463592529297}}
        state.update(status='failed', canContinue=False, attempt=2)
        module.recover_failed_save(path, state, next_receipt)
        check(state['accumulatedWorldHours'] == elapsed + .5,
              'new terminal from already running attempt lost its credit')
        # Equal snapshot clocks alone do not identify the same native attempt.
        later_receipt = {**next_receipt, 'launchNumber': 3,
                         'terminal': {**next_receipt['terminal'], 'startHours': 3.788463592529297,
                                      'endHours': 4.038463592529297}}
        state.update(status='failed', canContinue=False)
        module.recover_failed_save(path, state, later_receipt)
        check(state['accumulatedWorldHours'] == elapsed + .75 and state['attempt'] == 3,
              'different attempt with equal snapshot hours was treated as already credited')
        module.save_state(path, state, status='failed', canContinue=False)
        before, retained = dict(state), path.read_bytes()
        try:
            module.recover_failed_save(path, state, receipt)
        except ValueError as error:
            check('precedes the host credit cursor' in str(error), 'stale receipt refusal differs')
        else:
            raise AssertionError('old completed receipt rewound the credit cursor')
        check(state == before and path.read_bytes() == retained, 'stale receipt changed retained state')
        module.recover_failed_save(path, state, later_receipt, qualified=True)
        check(state['accumulatedWorldHours'] == elapsed + .75
              and state['lastStopReason'] == 'saved-with-reviewed-errors',
              'reviewed recovery lost its existing exact-once boundary')
        state.update(status='failed', canContinue=False)
        qualified = {**later_receipt, 'launchNumber': 4, 'lastHours': 4.2,
                     'terminal': {**later_receipt['terminal'], 'startHours': 4.038463592529297,
                                  'endHours': 4.288463592529297}}
        module.recover_failed_save(path, state, qualified, qualified=True)
        check(state['accumulatedWorldHours'] == elapsed + 1,
              'new reviewed attempt lost its first credit')
        check(receipt == original_receipt, 'host recovery mutated native receipt evidence')


def recovery_credit_controls():
    path = Path(Session.__file__); original = path.read_text(encoding='utf-8')
    elapsed = 'elapsed = 0 if credited else max(0, terminal["endHours"] - terminal["startHours"])'
    controls = [
        ('replayed-predecessor', elapsed,
         'elapsed = max(0, terminal["endHours"] - terminal["startHours"])',
         'already credited predecessor was credited again'),
        ('discarded-fresh-credit', elapsed, 'elapsed = 0',
         'newly completed attempt lost its first credit'),
        ('missing-cursor-update', '\n                      attempt=receipt["launchNumber"], worldHours=receipt["lastHours"],',
         '\n                      worldHours=receipt["lastHours"],',
         'completed recovery did not persist its credit cursor'),
        ('rewound-cursor', '    Lab.require(state["attempt"] <= receipt["launchNumber"], "completed attempt precedes the host credit cursor")',
         '    pass', 'old completed receipt rewound the credit cursor'),
    ]
    for label, before, after, marker in controls:
        check(original.count(before) == 1, 'recovery credit source control target differs: ' + label)
        module = types.ModuleType('session_credit_control_' + label); module.__dict__['__file__'] = str(path)
        exec(compile(original.replace(before, after), '<session-credit-control>', 'exec'), module.__dict__)
        try:
            recovery_credit_checks(module)
        except AssertionError as failure:
            check(marker in str(failure), 'recovery credit control failed for another reason: ' + str(failure))
        else:
            raise AssertionError('recovery credit defect survived its control: ' + label)
        print('PASS recovery credit restored-defect control: ' + label)
    check(path.read_text(encoding='utf-8') == original, 'recovery source control changed production')


def default_video_checks(args):
    missing = SimpleNamespace(**vars(args)); del missing.video_fps
    for resume in (False, True):
        command = Session.runner_command(missing, resume, 120)
        check(command[command.index('--video-fps') + 1] == '120',
              'session forwarding default capture ceiling differs')
        check(('--refresh-observer-adapter' in command) == resume,
              'default video forwarding changed adapter refresh ownership')

    def cli(module, explicit=None):
        argv = ['world_lab_session.py', 'package', '--out', 'study', '--game', 'game', '--jdk', 'jdk',
                '--watcher', 'watcher.py', '--registry', 'registry.json', '--video-encoder', 'encoder.exe']
        if explicit is not None:
            argv.extend(('--video-fps', str(explicit)))
        with patch.object(sys, 'argv', argv), patch.object(module, 'supervise', return_value=0) as supervisor:
            check(module.main() == 0, 'session CLI did not accept video options')
        parsed = supervisor.call_args.args[0]
        expected = 120 if explicit is None else explicit
        check(parsed.video_fps == expected, 'session CLI default capture ceiling differs')
        for resume in (False, True):
            command = module.runner_command(parsed, resume, 120)
            check(command[command.index('--video-fps') + 1] == str(expected),
                  'initial or resumed session did not forward its capture ceiling')

    cli(Session)
    for explicit in (30, 60, 120):
        cli(Session, explicit)
    path = Path(Session.__file__); original = path.read_text(encoding='utf-8')
    controls = [('api', 'getattr(args, "video_fps", 120)', 'getattr(args, "video_fps", 60)'),
                ('cli', 'parser.add_argument("--video-fps", type=int, default=120,',
                 'parser.add_argument("--video-fps", type=int, default=60,')]
    for label, before, after in controls:
        check(original.count(before) == 1, 'session default source control target differs')
        module = types.ModuleType('session_default_control_' + label); module.__dict__['__file__'] = str(path)
        exec(compile(original.replace(before, after), '<session-default-control>', 'exec'), module.__dict__)
        try:
            if label == 'api':
                command = module.runner_command(missing, True, 120)
                check(command[command.index('--video-fps') + 1] == '120',
                      'session forwarding default capture ceiling differs')
            else:
                cli(module)
        except AssertionError as failure:
            check('default capture ceiling differs' in str(failure), 'session default control failed for another reason')
        else:
            raise AssertionError('old session 60 FPS default survived its assertion control')
    check(path.read_text(encoding='utf-8') == original, 'session source control changed production')
    print('PASS initial/resume session defaults use 120 capture ceiling; explicit 30/60/120 retained; two old-60 controls refused')


def video_resume_refresh_check(module=Session):
    cases = 0
    for resume in (False, True):
        for video in (False, True):
            for explicit in (None, False, True):
                args = SimpleNamespace(package=Path('package'), out=Path('study'), game=Path('game'),
                    jdk=Path('jdk'), window='hidden', mod=[], profile=None,
                    video_encoder=Path('encoder.exe') if video else None)
                if explicit is not None:
                    args.refresh_observer_adapter = explicit
                command = module.runner_command(args, resume, 180)
                expected = resume and (video or explicit is True)
                check(command.count('--refresh-observer-adapter') == int(expected),
                      'video resume adapter refresh forwarding differs: '
                      + str((resume, video, explicit)))
                check(('--resume' in command) == resume and ('--video-encoder' in command) == video,
                      'video adapter forwarding changed native mode or encoder')
                cases += 1
    # Older callers omit both optional attributes entirely.
    args = SimpleNamespace(package=Path('package'), out=Path('study'), game=Path('game'),
        jdk=Path('jdk'), window='hidden', mod=[], profile=None)
    check('--refresh-observer-adapter' not in module.runner_command(args, True, 180),
          'legacy no-video caller acquired an unsolicited adapter refresh')
    return cases + 1


def video_resume_refresh_checks():
    cases = video_resume_refresh_check()
    path = Path(Session.__file__); source = path.read_text(encoding='utf-8')
    before = 'if getattr(args, "refresh_observer_adapter", False) or getattr(args, "video_encoder", None) is not None:'
    after = 'if getattr(args, "refresh_observer_adapter", False):'
    check(source.count(before) == 1, 'video adapter control target differs')
    module = types.ModuleType('video_resume_refresh_control'); module.__file__ = str(path)
    exec(compile(source.replace(before, after), '<video-resume-refresh-control>', 'exec'), module.__dict__)
    try:
        video_resume_refresh_check(module)
    except AssertionError as error:
        check('video resume adapter refresh forwarding differs: (True, True, None)' in str(error),
              'video adapter control failed for another reason: ' + str(error))
    else:
        raise AssertionError('missing automatic video resume refresh survived its control')
    check(path.read_text(encoding='utf-8') == source, 'video adapter control changed production')
    print(f'PASS {cases} video/fresh/resume/explicit/legacy command cases; restored manual-only refresh defect refused')


def saved_continue_check(module=Session, restarted=True, gui_exited=False):
    """Exercise the real inbox and both supervise saved loops without processes."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory); out = root / 'session'
        args = SimpleNamespace(package=root/'package', out=out, game=root/'game', jdk=root/'jdk',
            watcher=root/'watcher', registry=root/'registry', profile=None, label='Saved continue',
            duration=180, auto_continue=False, view_id='target-view')
        state_path = out/'study-session.json'; run_path = out/'native-run/run.json'
        previous_id = str(uuid.uuid4()); next_id = str(uuid.uuid4())
        command_name = f'{previous_id}-0000000000000001.json'
        predecessor = {'sessionId': previous_id, 'launchNumber': 1, 'status': 'completed',
                       'exitCode': 0, 'runtimeErrors': [], 'lastHours': 3,
                       'terminal': {'startHours': 2, 'endHours': 3, 'stopReason': 'wall-time-limit'}}
        if restarted:
            state = module.new_state('Saved continue', 180, False)
            state.update(status='saved', canContinue=True, attempt=1,
                         worldHours=3, accumulatedWorldHours=1)
            module.atomic(state_path, state); module.atomic(run_path, predecessor)
        watchers, launches = [], []
        archive = SimpleNamespace(close=lambda: None)

        class Watcher:
            def __init__(self, identity):
                self.identity = identity; self.emitted = False
                self.returncode = None; self.terminations = 0; self.waits = 0
                self.args = ['fixture-watcher']

            def poll(self):
                state = module.Lab.load(state_path)
                if self.identity == previous_id and state['status'] == 'saved' and not self.emitted:
                    self.emitted = True
                    module.atomic(out/'session-commands'/command_name,
                        {'schema': module.COMMAND_SCHEMA, 'sessionId': previous_id,
                         'sequence': 1, 'action': 'continue'})
                    if gui_exited:
                        self.returncode = 0
                return self.returncode

            def terminate(self):
                check(module.Lab.load(state_path)['status'] in ('continuing', 'failed'),
                      'watcher was retired outside the saved handback or final cleanup')
                self.terminations += 1; self.returncode = 0

            def wait(self, timeout=None):
                self.waits += 1
                if self.returncode is None:
                    raise subprocess.TimeoutExpired('saved watcher needs explicit retirement', timeout)
                return self.returncode

        def launch(*unused, **kwargs):
            number = 2 if restarted else len(launches) + 1
            if number == 2:
                check(watchers[0].returncode == 0,
                      'successor launched before saved watcher retirement')
                state = module.Lab.load(state_path)
                check(state['status'] == 'continuing' and len(state['processedCommands']) == 1,
                      'successor launched before durable exact-once Continue consumption')
            process = SimpleNamespace(returncode=0 if number == 1 else 1,
                                      poll=lambda: 0 if number == 1 else 1, args=['fixture-native'], number=number)
            launches.append(process); return process

        def ready(path, process, **unused):
            receipt = predecessor if process.number == 1 else {
                **predecessor, 'sessionId': next_id, 'launchNumber': 2, 'status': 'failed', 'exitCode': 1}
            module.atomic(path, receipt); return receipt

        def start(*unused):
            watcher = Watcher(module.Lab.load(run_path)['sessionId']); watchers.append(watcher)
            # The GUI path exits only after its Continue has been written. Write
            # before the supervisor's next inbox read, as the real watcher does.
            if module.Lab.load(state_path)['status'] == 'saved':
                watcher.poll()
            return watcher, out/'feed'

        real_apply = module.apply_commands
        def apply(*arguments):
            # Simulate the GUI publishing its command before its process exit is
            # observed in the post-native saved loop too.
            if watchers and module.Lab.load(state_path)['status'] == 'saved':
                watchers[-1].poll()
            return real_apply(*arguments)

        with patch.object(module.VideoArchive, 'start', return_value=archive), \
             patch.object(module.subprocess, 'Popen', side_effect=launch), \
             patch.object(module, 'runner_command', return_value=['fixture-native']), \
             patch.object(module, 'wait_for_run', side_effect=ready), \
             patch.object(module, 'start_watcher', side_effect=start), \
             patch.object(module, 'apply_commands', side_effect=apply), \
             patch.object(module, 'open_mousecat'), patch.object(module.time, 'sleep'), \
             patch.object(module, 'wait_for_terminal_projection', return_value=True) as terminal:
            try:
                check(module.supervise(args) == 1, 'fixture successor failure was hidden')
            except subprocess.TimeoutExpired as error:
                raise AssertionError('saved watcher needs explicit retirement before Continue') from error
        check(len(launches) == (1 if restarted else 2), 'Continue duplicated the native successor')
        check(watchers[0].terminations == (0 if gui_exited else 1),
              'saved watcher retirement did not preserve the already-exited GUI path')
        check(watchers[0].waits == (0 if gui_exited else 1), 'saved watcher handback wait differs')
        check(terminal.call_count == 1 and terminal.call_args.args[-1] == 'failed',
              'successor terminal projection boundary was lost')
        final = module.Lab.load(state_path)
        check(final['processedCommands'] == [command_name]
              and final['accumulatedWorldHours'] == 1, 'Continue changed command custody or prior native credit')


def saved_continue_checks():
    for restarted in (True, False):
        for gui_exited in (False, True):
            saved_continue_check(restarted=restarted, gui_exited=gui_exited)
            print('PASS saved Continue: ' + ('restarted' if restarted else 'just-completed')
                  + ', ' + ('GUI watcher already exited' if gui_exited else 'session inbox watcher still active'))
    path = Path(Session.__file__); source = path.read_text(encoding='utf-8')
    for restarted, indent in ((True, 24), (False, 20)):
        before = '\n' + ' ' * indent + 'stop_process(watcher)\n' + ' ' * indent + 'watcher = None'
        after = '\n' + ' ' * indent + 'watcher.wait(timeout=10)\n' + ' ' * indent + 'watcher = None'
        check(source.count(before) == 1, 'saved Continue source control target differs')
        module = types.ModuleType('session_continue_control'); module.__file__ = str(path)
        exec(compile(source.replace(before, after), '<session-continue-control>', 'exec'), module.__dict__)
        try:
            saved_continue_check(module, restarted=restarted, gui_exited=False)
        except AssertionError as error:
            check('saved watcher needs explicit retirement' in str(error),
                  'saved Continue control failed elsewhere: ' + str(error))
        else:
            raise AssertionError('old saved watcher wait survived its control')
        print('PASS restored waiting-only Continue defect: ' + ('restarted' if restarted else 'just-completed'))
    check(path.read_text(encoding='utf-8') == source, 'saved Continue controls changed production')


def mousecat_supervisor_check(module):
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory)
        args=SimpleNamespace(package=root/'package',out=root/'session',game=root/'game',jdk=root/'jdk',
            watcher=root/'watcher',registry=root/'registry',profile=None,label='Exact target',duration=30,
            auto_continue=True,view_id='target-view')
        launched=[]
        def runner(*unused, **kwargs):
            process=SimpleNamespace(returncode=(1 if len(launched)==2 else 0),poll=lambda: 0,args=['runner'])
            launched.append(process);return process
        def started(path,process,**kwargs):
            receipt={'sessionId':str(uuid.uuid4()),'launchNumber':len(launched),'status':'failed' if process.returncode else 'completed',
                     'terminal':{'startHours':0,'endHours':1,'stopReason':'wall-time-limit'},'lastHours':len(launched)}
            module.atomic(path,receipt);return receipt
        watcher=SimpleNamespace(poll=lambda:0)
        with patch.object(module.subprocess,'Popen',side_effect=runner), patch.object(module,'runner_command',return_value=['runner']), \
             patch.object(module,'wait_for_run',side_effect=started), patch.object(module,'start_watcher',return_value=(watcher,root/'feed')), \
             patch.object(module,'stop_process'), patch.object(module,'wait_for_terminal_projection',return_value=True), \
             patch.object(module,'open_mousecat') as opened:
            check(module.supervise(args)==1,'mock native failure did not remain a failure')
        check(len(launched)==3 and opened.call_count==1,'desktop selection must be requested once across continuations')
        check(opened.call_args.args[1]==root/'feed' and opened.call_args.args[2], 'desktop request lost exact feed/session')


def preparation_and_attachment_checks(module=Session):
    identity, previous = str(uuid.uuid4()), str(uuid.uuid4())
    running = {'status':'running','sessionId':identity,'launchNumber':1,'pid':1234}
    process = SimpleNamespace(returncode=None, poll=lambda:None, args=['native-owner'])
    clock = [0.0]
    def sleep(seconds): clock[0] += seconds
    late = SimpleNamespace(exists=lambda:clock[0]>=188)
    with patch.object(module.time,'monotonic',side_effect=lambda:clock[0]), \
         patch.object(module.time,'sleep',side_effect=sleep), patch.object(module.Lab,'load',return_value=running):
        try: result=module.wait_for_run(late,process)
        except TimeoutError: raise AssertionError('188-second isolated preparation must reach the viewer handoff')
    check(result==running,'late preparation receipt differs')
    clock[0]=0
    with patch.object(module.time,'monotonic',side_effect=lambda:clock[0]), \
         patch.object(module.time,'sleep',side_effect=sleep), patch.object(module.Lab,'load',
             side_effect=lambda unused:running if clock[0]>=.5 else {**running,'sessionId':previous}):
        result=module.wait_for_run(SimpleNamespace(exists=lambda:True),process,timeout=1,previous_session=previous)
    check(result['sessionId']==identity and clock[0]>=.5,'stale prior running receipt was accepted')
    dead=SimpleNamespace(returncode=0,poll=lambda:0,args=['exited-owner'])
    with patch.object(module.Lab,'load',return_value=running):
        try:module.wait_for_run(SimpleNamespace(exists=lambda:True),dead)
        except subprocess.CalledProcessError:pass
        else:raise AssertionError('exited owner with running receipt was accepted')
    with patch.object(module.Lab,'load',return_value={**running,'status':'failed'}):
        try:module.wait_for_run(SimpleNamespace(exists=lambda:True),process)
        except RuntimeError:pass
        else:raise AssertionError('failed native preparation was accepted')
    clock[0]=0
    with patch.object(module.time,'monotonic',side_effect=lambda:clock[0]),patch.object(module.time,'sleep',side_effect=sleep):
        try:module.wait_for_run(SimpleNamespace(exists=lambda:False),process,timeout=.3)
        except TimeoutError:pass
        else:raise AssertionError('missing readiness was not bounded')
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);out=root/'session';state=module.new_state('Reattach',30,False)
        state_path=out/'study-session.json';run_path=out/'native-run/run.json'
        observer_path=out/'native-run/attempts/0001/observer-state.json'
        module.atomic(state_path,state);module.atomic(run_path,running)
        module.atomic(observer_path,{'status':'active','updatedAtUnixMs':100000})
        args=SimpleNamespace(out=out,attach_running_session=identity)
        with patch.object(module.time,'time',return_value=100),patch.object(module,'native_process_live',return_value=True), \
             patch.object(module.subprocess,'Popen') as spawn:
            owner,receipt=module.attach_running(args,state)
            check(owner.poll() is None and receipt==running and not spawn.called,'attachment launched or lost existing native owner')
            for label,value in [('wrong identity',{**running,'sessionId':previous}),('terminal receipt',{**running,'status':'completed'})]:
                module.atomic(run_path,value)
                try:module.attach_running(args,state)
                except ValueError:pass
                else:raise AssertionError('attachment accepted '+label)
            module.atomic(run_path,running)
            module.atomic(observer_path,{'status':'active','updatedAtUnixMs':1})
            try:module.attach_running(args,state)
            except ValueError:pass
            else:raise AssertionError('attachment accepted stale native observation')
            module.atomic(observer_path,{'status':'active','updatedAtUnixMs':100000})
            module.atomic(run_path,{**running,'sessionId':previous})
            try:owner.poll()
            except ValueError:pass
            else:raise AssertionError('attachment followed a replaced native session')
            module.atomic(run_path,running)
        with patch.object(module.time,'time',return_value=100),patch.object(module,'native_process_live',return_value=False):
            try:module.attach_running(args,state)
            except ValueError:pass
            else:raise AssertionError('attachment accepted dead native process')
        owner=module.AttachedNativeRun(run_path,identity)
        with patch.object(module,'native_process_live',return_value=False),patch.object(module.time,'monotonic',return_value=10):
            check(owner.poll() is None,'attachment skipped native post-exit validation grace')
        with patch.object(module,'native_process_live',return_value=False),patch.object(module.time,'monotonic',return_value=131):
            try:owner.poll()
            except RuntimeError:pass
            else:raise AssertionError('attachment waited forever after native owner disappeared')
        module.atomic(run_path,{**running,'status':'completed','exitCode':0})
        check(owner.poll()==0,'attachment did not yield the real terminal receipt')
    print('PASS preparation/attachment: late cache, bounded missing readiness, stale/exited/failed refusal, exact live attachment and terminal custody')


def orchestration_failure_check(module=Session):
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);args=SimpleNamespace(package=root/'package',out=root/'session',game=root/'game',jdk=root/'jdk',
            watcher=root/'watcher',registry=root/'registry',profile=None,label='Failure',duration=30,auto_continue=False)
        waited=[]
        def wait():
            state=module.Lab.load(args.out/'study-session.json')
            check(state['status']=='failed' and not state['canCheckpoint'],'orchestration failure must publish before native wait')
            check(module.Lab.load(args.out/'orchestration-failure.json')['errorType']=='TimeoutError',
                  'orchestration failure receipt missing before native wait')
            waited.append(True)
        owner=SimpleNamespace(poll=lambda:None,wait=wait,args=['owner'],returncode=None)
        with patch.object(module.subprocess,'Popen',return_value=owner),patch.object(module,'runner_command',return_value=['owner']), \
             patch.object(module,'wait_for_run',side_effect=TimeoutError('fixture preparation timeout')), \
             patch.object(module,'stop_process'),patch.object(module,'start_watcher') as watcher,patch.object(module,'open_mousecat') as opened:
            try:module.supervise(args)
            except TimeoutError:pass
            else:raise AssertionError('orchestration failure was hidden')
        check(waited==[True] and not watcher.called and not opened.called,'failed preparation claimed viewer propagation')


def attachment_supervisor_check(module=Session):
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);out=root/'session';identity=str(uuid.uuid4())
        args=SimpleNamespace(package=root/'package',out=out,game=root/'game',jdk=root/'jdk',
            watcher=root/'watcher',registry=root/'registry',profile=None,label='Attachment',duration=30,
            auto_continue=False,attach_running_session=identity)
        state=module.new_state('Attachment',30,False);module.atomic(out/'study-session.json',state)
        running={'status':'running','sessionId':identity,'launchNumber':1,'pid':1234}
        module.atomic(out/'native-run/run.json',running)
        def finish():
            module.atomic(out/'native-run/run.json',{**running,'status':'completed','exitCode':0,
                'lastHours':2.5,'terminal':{'startHours':2,'endHours':2.5,'stopReason':'wall-time-limit'}})
            return 0
        owner=SimpleNamespace(poll=finish,returncode=0)
        watcher=SimpleNamespace(poll=lambda:None)
        def saved_commands(*unused):
            current=module.Lab.load(out/'study-session.json')
            check(current['status']=='saved' and current['canContinue'] and current['worldHours']==2.5,
                  'attachment did not restore honest saved session control')
            raise KeyboardInterrupt('fixture completed persistent saved handoff')
        with patch.object(module,'attach_running',return_value=(owner,running)), \
             patch.object(module,'runner_command',return_value=['forbidden-native-run']), \
             patch.object(module.subprocess,'Popen',side_effect=AssertionError('attachment relaunched native')) as spawned, \
             patch.object(module,'start_watcher',return_value=(watcher,out/'feed')), \
             patch.object(module,'open_mousecat') as opened,patch.object(module,'apply_commands',side_effect=saved_commands), \
             patch.object(module,'stop_process'):
            try:module.supervise(args)
            except KeyboardInterrupt:pass
        check(not spawned.called and opened.call_count==1 and opened.call_args.args[2]==identity,
              'attachment relaunched native or lost the one exact viewer handoff')


def startup_checks():
    preparation_and_attachment_checks();orchestration_failure_check();attachment_supervisor_check()
    source=Path(Session.__file__).read_text()
    variants=[('short-preparation','PREPARATION_TIMEOUT_SECONDS = 900','PREPARATION_TIMEOUT_SECONDS = 180',
               preparation_and_attachment_checks,'188-second'),
              ('stale-readiness',' and value.get("sessionId") != previous_session:',':',
               preparation_and_attachment_checks,'stale prior'),
              ('silent-failure','        save_state(state_path, state, status="failed", canCheckpoint=False, canContinue=False,\n                   lastStopReason="orchestration-failed")',
               '        pass',orchestration_failure_check,'publish before native wait'),
              ('dead-attachment','Lab.require(native_process_live(receipt.get("pid")), "attachment native process is not live")',
               'Lab.require(True, "attachment native process is not live")',preparation_and_attachment_checks,'dead native'),
              ('stale-observer','and 0 <= age <= 30000','and True',preparation_and_attachment_checks,'stale native'),
              ('reattach-relaunch','            if pending_attachment is not None:',
               '            if False:',attachment_supervisor_check,'attachment relaunched native')]
    for name,before,after,check_fn,marker in variants:
        check(source.count(before)==1,'startup control source target differs: '+name)
        mutated=types.ModuleType(name);mutated.__file__=Session.__file__
        exec(compile(source.replace(before,after),'<startup-control>','exec'),mutated.__dict__)
        try:check_fn(mutated)
        except AssertionError as error:check(marker in str(error),'startup control failed elsewhere: '+str(error))
        else:raise AssertionError('startup defect control survived: '+name)
    check(Path(Session.__file__).read_text()==source,'startup controls changed production')
    print('PASS startup failure publication, existing-run saved handoff and six injected defect controls')


def mousecat_checks():
    cli=['world_lab_session.py','package','--out','study','--game','game','--jdk','jdk',
         '--watcher','watcher.py','--registry','registry.json']
    for flags,expected in (([],True),(['--no-open-mousecat'],False)):
        with patch.object(sys,'argv',cli+flags),patch.object(Session,'supervise',return_value=0) as supervisor:
            Session.main()
        check(supervisor.call_args.args[0].open_mousecat is expected,'desktop CLI default/opt-out differs')
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);args=SimpleNamespace(out=root,view_id='target-view',label='Label with spaces',registry=root/'registry.json',
                                                 review_endpoint='http://127.0.0.1:4317/mcp')
        session=str(uuid.uuid4())
        with patch.object(Session.sys,'platform','win32'),patch.object(Session.subprocess,'Popen') as spawned:
            Session.open_mousecat(args,root/'feed',session)
        command=spawned.call_args.args[0]
        check(command[command.index('-WindowStyle')+1]=='Hidden' and spawned.call_args.kwargs['creationflags']==getattr(subprocess, "CREATE_NO_WINDOW", 0),
              'desktop helper was not hidden')
        check(command[command.index('-NativeSession')+1]==session and command[command.index('-ViewId')+1]=='target-view'
              and command[command.index('-FeedDirectory')+1]==str((root/'feed').resolve()),'desktop helper identity differs')
        check(not spawned.return_value.wait.called and not spawned.return_value.poll.called,'desktop helper blocks supervisor')
        args.open_mousecat=False
        with patch.object(Session.subprocess,'Popen') as spawned:
            Session.open_mousecat(args,root/'feed',session)
        check(not spawned.called and Session.Lab.load(root/'mousecat-selection.json')['status']=='disabled','desktop opt-out launched helper')
        args.open_mousecat=True
        with patch.object(Session.sys,'platform','linux'),patch.object(Session.subprocess,'Popen') as spawned:
            Session.open_mousecat(args,root/'feed',session)
        check(not spawned.called and Session.Lab.load(root/'mousecat-selection.json')['status']=='unavailable','non-Windows launched helper')
        with patch.object(Session.sys,'platform','win32'),patch.object(Session.subprocess,'Popen',side_effect=OSError('missing PowerShell')):
            check(Session.open_mousecat(args,root/'feed',session) is None,'desktop launch failure escaped')
        check(Session.Lab.load(root/'mousecat-selection.json')['status']=='error','desktop failure claimed success')
        with patch.object(Session,'atomic',side_effect=PermissionError('receipt denied')):
            check(Session.open_mousecat(args,root/'feed',session) is None,'desktop evidence failure escaped')
    mousecat_supervisor_check(Session)
    path=Path(Session.__file__);original=path.read_text()
    for label,before,after in [('omitted','                open_mousecat(args, feed, native_session)','                pass'),
                                ('repeated','            if not mousecat_requested:','            if True:')]:
        check(original.count(before)==1,'desktop source control target differs')
        module=types.ModuleType('mousecat_'+label);module.__file__=str(path)
        exec(compile(original.replace(before,after),str(path),'exec'),module.__dict__)
        try:mousecat_supervisor_check(module)
        except AssertionError as error:check('requested once' in str(error),'desktop control failed elsewhere')
        else:raise AssertionError('broken desktop selection survived '+label)
    if sys.platform=='win32':
        helper=TOOLS/'world_lab_open_mousecat.ps1';fixture=TOOLS/'world_lab_open_mousecat_cases.ps1'
        source=helper.read_text();variants=[('production',None,None,None),
            ('ps51-array-wrapper','$rows=@($decoded)','$rows=@(Write-Output -NoEnumerate $decoded)','multi_entry_registry_selects_exact_row'),
            ('navigation-text-match','[System.Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty,$true','[System.Windows.Automation.AutomationElement]::IsEnabledProperty,$true','navigation_requires_toggle_capability'),
            ('false-success',"status='unavailable';reason='Exactly one open Mousecat window is required'",
             "status='PASS';reason='Exactly one open Mousecat window is required'",'absent_desktop_unavailable'),
            ('wrong-session','$Snapshot.view.sessionId -ceq $Request.NativeSession','$true','reject_wrong_snapshot')]
        for name,before,after,marker in variants:
            with tempfile.TemporaryDirectory() as directory:
                candidate=Path(directory)/helper.name
                check(before is None or source.count(before)==1,'UI helper source control target differs')
                candidate.write_text(source if before is None else source.replace(before,after))
                run=subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-File',str(fixture),'-Helper',str(candidate)],capture_output=True,text=True,timeout=30)
                log=run.stdout+run.stderr
                check((run.returncode!=0 and 'OPEN_MOUSECAT:'+marker in log) if marker else (run.returncode==0 and 'PASS open Mousecat helper 17' in log),log)
        print('PASS open Mousecat helper: 17 mocked workflow checks; unavailable and wrong-session controls refused')
    print('PASS desktop launch defaults/opt-out/hidden/nonblocking/failure; once across 3 attempts; omitted/repeated controls refused')


def main():
    with tempfile.TemporaryDirectory() as directory:
        destination = Path(directory) / 'state.json'
        destination.write_text('old')
        replace = Session.os.replace
        attempts = []

        def sharing_reader(source, target):
            attempts.append(source.read_bytes())
            if len(attempts) < 3:
                check(target.read_text() == 'old', 'retry exposed incomplete state')
                raise PermissionError('reader holds destination')
            return replace(source, target)

        with patch.object(Session.os, 'replace', side_effect=sharing_reader), patch.object(Session.time, 'sleep'):
            Session.atomic(destination, {'saved': True})
        check(len(attempts) == 3 and len(set(attempts)) == 1,
              'sharing retry did not retain the prepared bytes')
        check(Session.Lab.load(destination) == {'saved': True}, 'saved state not promoted')
        with patch.object(Session.os, 'replace', side_effect=PermissionError('permanent denial')) as denied, patch.object(Session.time, 'sleep'):
            try:
                Session.atomic(destination, {'saved': False})
            except PermissionError:
                check(denied.call_count == 20, 'persistent failure retry was not bounded')
            else:
                raise AssertionError('persistent state write failure was hidden')
        check(Session.Lab.load(destination) == {'saved': True}, 'failed write damaged prior state')
        print('PASS transient sharing lock retry; stable bytes; bounded persistent denial')
    args = SimpleNamespace(package=Path('package'), out=Path('study'), game=Path('game'),
                           jdk=Path('jdk'), window='hidden', mod=[], profile=None,
                           observer_layout=Path('subjects.json'), video_encoder=Path('encoder.exe'),
                           video_fps=120, refresh_observer_adapter=True)
    for resume in (False, True):
        command = Session.runner_command(args, resume, 120)
        check(command[command.index('--video-encoder') + 1] == 'encoder.exe'
              and command[command.index('--video-fps') + 1] == '120',
              'saved continuation lost its continuous-video options')
        check(('--refresh-observer-adapter' in command) == resume,
              'adapter refresh escaped verified continuation')
    default_video_checks(args)
    startup_checks()
    mousecat_checks()
    recovery_credit_checks()
    recovery_credit_controls()
    print('PASS completed recovery credit: persisted cursor, repeated prelaunch failure, fresh native credit, stale refusal and reviewed compatibility')
    saved_continue_checks()
    video_resume_refresh_checks()
    state = Session.new_state("Survival simulation", 3600, False)
    check(state["status"] == "starting" and not state["canContinue"], "new session state differs")
    with tempfile.TemporaryDirectory() as name:
        root = Path(name); commands = root / "commands"; commands.mkdir()
        state_path = root / "study-session.json"
        Session.atomic(state_path, state)
        command_id = str(uuid.uuid4())
        configure = {"schema": Session.COMMAND_SCHEMA, "sessionId": command_id, "sequence": 1,
                     "action": "configure", "attemptDurationSeconds": 7200, "autoContinue": True}
        Session.atomic(commands / f"{command_id}-0000000000000001.json", configure)
        check(not Session.apply_commands(commands, state_path, state, command_id), "configure requested continuation")
        check(state["attemptDurationSeconds"] == 7200 and state["autoContinue"], "configuration was not retained")
        state.update(status="saved", canContinue=True)
        Session.save_state(state_path, state)
        continue_id = command_id
        continuation = {"schema": Session.COMMAND_SCHEMA, "sessionId": continue_id,
                        "sequence": 2, "action": "continue"}
        Session.atomic(commands / f"{continue_id}-0000000000000002.json", continuation)
        check(Session.apply_commands(commands, state_path, state, continue_id), "saved session did not continue")
        check(len(state["processedCommands"]) == 2, "session commands were not durably consumed")
        before = dict(state)
        check(not Session.apply_commands(commands, state_path, state) and state == before,
              "processed session command replayed")
        wrong_id = str(uuid.uuid4())
        wrong = {"schema": Session.COMMAND_SCHEMA, "sessionId": wrong_id,
                 "sequence": 3, "action": "configure",
                 "attemptDurationSeconds": 3600, "autoContinue": False}
        Session.atomic(commands / f"{wrong_id}-0000000000000003.json", wrong)
        try:
            Session.apply_commands(commands, state_path, state, command_id)
        except ValueError:
            pass
        else:
            raise AssertionError("command from another native attempt was admitted")
        for bad in (29, 604801, True, 1.5):
            try:
                Session.bounded_duration(bad)
            except (ValueError, TypeError):
                pass
            else:
                raise AssertionError("invalid attempt duration admitted")
        state.update(status="failed", canContinue=False, lastStopReason="incomplete",
                     worldHours=0, accumulatedWorldHours=0)
        terminal = {"startHours": 2, "endHours": 2.25, "nativeSaveReturned": True,
                    "stopReason": "checkpoint"}
        recovered = Session.recover_failed_save(state_path, state, {
            "status": "completed", "exitCode": 0, "runtimeErrors": [],
            "terminal": terminal, "lastHours": 2.25, "launchNumber": 1})
        check(recovered["status"] == "saved" and recovered["canContinue"],
              "verified native save was not restored")
        check(recovered["worldHours"] == 2.25 and recovered["accumulatedWorldHours"] == .25,
              "recovered study clocks differ")
        feed = root / "feed"; feed.mkdir()
        Session.atomic(feed / "latest.json", {"schema": "mousecat.native-view/1",
            "sessionId": command_id, "state": "ended",
            "study": {"id": recovered["id"], "status": "saved"}})
        check(Session.wait_for_terminal_projection(feed, command_id, recovered["id"], "saved", timeout=0),
              "terminal projection acknowledgement was not recognized")
        check(Session.attempt_review_outbox(root, 3) == root / "review/0003",
              "review evidence is not bound to one native attempt")
    print("Border 210 PASS: durable study session has bounded settings, saved continuation, attempt-bound review and exact-once command consumption")


if __name__ == "__main__":
    raise SystemExit(main())
