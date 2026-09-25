#!/usr/bin/env python3
"""Border 122 - survivor requests use the enacted Command process."""
from __future__ import annotations

import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
COORDINATION = ROOT / "mod/42.20/media/lua/shared/SAO_Coordination.lua"
COMMAND = ROOT / "mod/42.20/media/lua/shared/SAO_Command.lua"
CHECK = ROOT / "tools/check.sh"


def evaluate(controller: str, command: str,
             coordination: str) -> dict[str, bool]:
    wrapper_match = re.search(
        r"local function onTheirWord\(giverId, id, kind, arg, act\)(.*?)\nend\n"
        r"Ctl\.onTheirWord", controller, re.S)
    wrapper = wrapper_match.group(1) if wrapper_match else ""
    external_match = re.search(
        r"function Ctl\.advanceExternalCoordination\(.*?\)(.*?)\nend\n",
        controller, re.S)
    external = external_match.group(1) if external_match else ""
    return {
        "one wrapper owns all survivor requests":
            "SAO.Command.order(giverId, id, kind, arg)" in wrapper
            and "if verdict == \"refuses\" then" in wrapper
            and "if act then act() end" in wrapper,
        "the keeper addresses each person who did not receive the warning":
            'onTheirWord(id, otherId, "rouse", nil, nil)' in controller
            and "local landed = SAO.Perception.tell(id, otherId, tickCount)" in controller,
        "the stay-put objection is an addressed request":
            'and onTheirWord(objector, id,\n                                        "hold", nil, nil) then' in controller,
        "the trespass request records desperation as the recipient response":
            'local heeds = onTheirWord(id,\n                                            trespasserId, "leave"' in controller
            and "local heeds = not desperate" not in controller
            and 'kind == "leave" and ownNeed >= 0.75' in command,
        "only delivered acceptance lets a caller act":
            "return false" in wrapper and "return true" in wrapper
            and "if heeds then" in controller,
        "old controller-local authority table is absent":
            all(anchor not in controller for anchor in (
                "heavyVoice", "local sameSide", "local formHV")),
        "responses remain visible without a second recognition projection":
            'SAO.Voice.onEvent(id, "orderNo", tickCount)' in wrapper
            and "Command.order already owns the delivered request" in wrapper,
        "external execution capability belongs to its registered owner":
            "executionUnavailable" in coordination
            and "execution.canAcquire ~= false" in coordination
            and 'executor = execution.executor' in coordination,
        "external danger pauses the same commitment and route":
            'activity ~= "coordination"' in external
            and 'SAO.Organization.pauseWork(commitment.id' in external
            and '"external-competing-activity"' in external
            and "runtime.coordinationRoute = nil" in external,
        "the gate runs this border":
            "tools/survivor_orders_test.py" in CHECK.read_text(encoding="utf-8"),
    }


def main() -> int:
    print("=" * 74)
    print("SURVIVOR REQUESTS USE THE ENACTED COMMAND PROCESS")
    print("=" * 74)
    if not (CONTROLLER.is_file() and COORDINATION.is_file()
            and COMMAND.is_file()):
        print("  FAULT: controller, coordination or command source is absent")
        return 1
    controller = CONTROLLER.read_text(encoding="utf-8-sig")
    coordination = COORDINATION.read_text(encoding="utf-8-sig")
    command = COMMAND.read_text(encoding="utf-8-sig")
    checks = evaluate(controller, command, coordination)
    faults = [name for name, result in checks.items() if not result]
    for name, result in checks.items():
        print(f"  {'yes' if result else 'NO '}  {name}")

    controls = [
        ("rouse", "controller", 'onTheirWord(id, otherId, "rouse", nil, nil)',
         'true'),
        ("hold", "controller", 'and onTheirWord(objector, id,',
         'and true -- removed request'),
        ("leave", "controller", 'local heeds = onTheirWord(id,',
         'local heeds = true -- removed request'),
        ("external capability", "coordination", "execution.canAcquire ~= false",
         "true -- external capability ignored"),
        ("external pause", "controller", "SAO.Organization.pauseWork(commitment.id,",
         "true -- external work was not paused\n            and (commitment.id,"),
    ]
    controls_ok = True
    for name, owner, old, new in controls:
        source = controller if owner == "controller" else coordination
        if source.count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutant = source.replace(old, new, 1)
        mutated_controller = mutant if owner == "controller" else controller
        mutated_coordination = mutant if owner == "coordination" else coordination
        if all(evaluate(mutated_controller, command,
                        mutated_coordination).values()):
            print(f"  FAULT: {name} routing mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (five production seams)")
    if faults or not controls_ok:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  122) rousing, stay-put and leave requests use the recipient-owned "
          "process; external owners supply capability and pause work on danger")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
