#!/usr/bin/env python3
r"""Border 116 - before the fall, an ordinary life ([C42], DR-036).

The day-zero start is the case this mod is for, and an audit of what
its switch actually reached found two things: no lessons seeded, and
only the duty trades armed. Everything else about the county was
identical before and after the world ended. The county had written
three stamps since [B1] and [B3] and read them only to print a
chronicle - not one decision consulted them - so a household in a
working world posted a sentry on its first night and people crossed
town for a better weapon on an ordinary Tuesday.

WHAT THIS HOLDS
---------------
  1. The question exists and is answerable: `S.fallHasCome`.
  2. IT IS DERIVED, NOT SWITCHED. The answer comes off the county's
     own stamps and the record's calendar, and the sandbox dial is
     not read anywhere inside it. A dial-driven answer looks
     identical in play and is a different mod: it would mean the
     county behaves the way a setting says rather than the way its
     own knowledge does. This is the check the batch exists for.
  3. Both clauses are there. The calendar alone must answer true, or
     an ordinary July 9 start spends its first minutes pretending
     nothing has happened; the stamps alone must answer true, or a
     day-zero start never notices its own first horror.
  4. Every survival-shaped decision asks it - the night watch, the
     journey for a weapon, the journey for ammunition, and scouting
     somewhere defensible to live.
  5. And the ordinary ones do NOT ask it. Eating, drinking, warmth,
     treatment, mourning, going home: gating those would be saying
     people did not eat before the world ended.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree asks nothing at all.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CHECK = ROOT / "tools" / "check.sh"

ASK = "SAO.Standing.fallHasCome()"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_comments(text):
    out = []
    for line in text.split("\n"):
        at = line.find("--")
        out.append(line[:at] if at >= 0 else line)
    return "\n".join(out)


def body_of(text, header, end):
    at = text.find(header)
    if at < 0:
        return ""
    stop = text.find(end, at + len(header))
    return text[at:stop if stop > 0 else len(text)]


def main():
    faults = []
    print("=" * 74)
    print("BEFORE THE FALL, AN ORDINARY LIFE")
    print("=" * 74)

    standing, controller = read(STANDING), read(CONTROLLER)

    # 1 + 2 + 3. The question, and what it is allowed to read.
    question = body_of(standing, "function S.fallHasCome()", "\nend\n")
    if not question:
        print("  FAULT: the county cannot be asked whether the fall has "
              "reached it, so every survival-shaped decision is made the "
              "same way in a working world and a ruined one")
        return 1
    bare = strip_comments(question)

    checks = {
        "the county's own stamps answer it":
            "s.outbreakAtHours" in bare and "s.firstTurnedAtHours" in bare
            and "s.tapsDryAtHours" in bare,
        "the record's calendar answers it":
            "recordDayToday()" in bare,
        "and the sandbox dial is not consulted":
            "SandboxVars" not in bare and "DayZero" not in bare,
        "the calendar clause can answer true on its own":
            re.search(r"day >= 0 then\n\s*return true", bare) is not None,
        "the stamps clause can answer true on its own":
            re.search(r"return true, \"seen\"", bare) is not None,
        "an unreadable clock is not read as a fallen world":
            "-90000" in bare,
    }

    # 4. Who asks.
    #
    # Two shapes, and reading both the same way was this border's own
    # first finding against correct code. Three of these are decisions
    # and the ask must come BEFORE them; the watch is a whole function
    # whose job is survival, and the ask belongs at its top, AFTER the
    # header this anchors on. A window that only looks backwards
    # reports the correct code as ungated.
    print("     asked by: %d site(s)" % controller.count(ASK))
    for what, needle in (
            ("the journey for a weapon", 'setState(agent, id, "GEARWARD"'),
            ("the journey for ammunition", 'setState(agent, id, "AMMOWARD"'),
            ("scouting somewhere defensible", 'setState(agent, id, "SETTLEWARD"')):
        at = controller.find(needle)
        if at < 0:
            faults.append("%s is gone from the controller, so this border "
                          "cannot tell whether it asks" % what)
            continue
        checks["%s asks first" % what] = ASK in controller[max(0, at - 900):at]

    keeper = body_of(controller, "local function nightKeeper(id, nightIndex)",
                     "\nend\n")
    if not keeper:
        faults.append("the night watch is gone from the controller, so this "
                      "border cannot tell whether it asks")
    else:
        checks["the night watch asks before it picks anybody"] = (
            ASK in keeper
            and keeper.index(ASK) < keeper.index("SAO.Standing.groupOf(id)"))

    # 5. And the ordinary ones do not.
    for what, needle in (("eating", 'setState(agent, id, "EAT"'),
                          ("drinking", 'setState(agent, id, "DRINK"'),
                          ("warmth", 'setState(agent, id, "WARMING"'),
                          ("treating a wound", 'setState(agent, id, "TREAT"'),
                          ("mourning", 'setState(agent, id, "MOURNING"'),
                          ("going home", 'setState(agent, id, "HOMEWARD"')):
        at = controller.find(needle)
        if at < 0:
            continue
        window = controller[max(0, at - 400):at]
        checks["%s does not ask" % what] = ASK not in window
        if ASK in window:
            faults.append(
                "%s waits on the fall having come. People ate before the "
                "world ended; gating an ordinary need on the apocalypse "
                "makes the pre-fall county a set of statues" % what)

    checks["the registry carries the goal this serves"] = (
        "## DR-036" in read(REGISTRY))
    checks["the gate runs this border"] = (
        "tools/before_the_fall_test.py" in read(CHECK))

    print()
    for k, v in checks.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v and k not in [f for f in faults]:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  116) before the fall, an ordinary life: the county can be asked, "
          "the answer is derived from the record and never from the dial, and "
          "every survival-shaped decision asks it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
