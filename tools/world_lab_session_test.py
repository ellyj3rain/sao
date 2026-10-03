import importlib.util
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


def main():
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
            "terminal": terminal, "lastHours": 2.25})
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
