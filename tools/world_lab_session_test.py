import importlib.util
import tempfile
from pathlib import Path
import sys
import uuid


TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("world_lab_session", TOOLS / "world_lab_session.py")
Session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(Session)


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
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
    print("Border 210 PASS: durable study session has bounded settings, saved continuation and exact-once command consumption")


if __name__ == "__main__":
    raise SystemExit(main())
