#!/usr/bin/env python3
r"""Border 128 - a border that cannot run says so ([C56]).

The CI workflow states the design in its own comment: a border that
reads the installed game reports SKIPPED, because a check that cannot
run must never look like a check that passed. Fifteen borders did not.
They exited 1 - a finding about the repository - so `check.sh` refused
and CI would have gone red on any machine without Project Zomboid
installed, which is every machine but the operator's. The workflow's
comment said "the six that read the installed game"; that was true
when it was written and the C era added eleven more, so nobody looking
at the comment could see it had stopped being true.

Nothing had checked the property, so it drifted silently for eleven
borders. This checks it.

Every tool under `tools/` that names the installed game is imported
with its game-install paths redirected to somewhere that does not
exist - the jar, the JDK, the stdlib, vanilla's own script directory -
and then run. Each must:

  * return 0, because a missing game is not a defect in this tree; and
  * print SKIPPED, because silence would be indistinguishable from
    having run.

Paths INSIDE the repository are left alone: a tool whose own Java
source or prelude is missing is a real fault and must stay one. The
distinction is the whole point - the game is absent on CI, the
repository is not.

A tool with no `main()` is not a border and is passed over; the census
prints what it covered so a tool that stops being seen is visible.
"""
import contextlib
import importlib.util
import io
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

# Redirected by what a path IS, not by what it is called. A list of
# names was tried first and was wrong twice over: it missed the names
# a tool happened to invent (`places_test` binds GAME, `queue_drop_
# test` binds VANILLA), and it could never have caught a path DERIVED
# from one at import - `places_test` computes its Distributions.lua
# out of GAME on the line below it, so redirecting GAME afterwards
# left the derived path pointing at the real install and the tool ran
# in full. Both looked like defects in those tools and were defects
# here. Every module-level Path that points inside the install is
# redirected; every other path the tool holds is left alone, because a
# tool missing its OWN Java source is a real fault and must stay one.
INSIDE_THE_INSTALL = "ProjectZomboid"

# A tool reads the installed game when it BINDS a path into it, not
# when it mentions it. `modinfo_check` names the jar in its docstring
# to say which engine class it mirrors and never opens it; matching on
# the mention called that a border that skips wrongly.
MARKER = re.compile(
    r"^\s*[A-Z_]+\s*=\s*pathlib\.Path\(\s*r?[\"']"
    r"[^\"']*ProjectZomboid", re.M)

ABSENT = pathlib.Path("/nonexistent/no-game-installed-here")


def reads_the_game(path):
    return bool(MARKER.search(path.read_text(encoding="utf-8",
                                             errors="ignore")))


def run_absent(path):
    """(exit code, said SKIPPED) with the game made absent."""
    name = "skipprobe_" + path.stem
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    quiet = io.StringIO()
    try:
        with contextlib.redirect_stdout(quiet):
            spec.loader.exec_module(module)
    except SystemExit:
        pass
    except Exception as exc:
        return "LOAD:%s" % type(exc).__name__, False
    if not hasattr(module, "main"):
        return None, False
    redirected = 0
    for attr, held in list(vars(module).items()):
        if isinstance(held, pathlib.Path) and INSIDE_THE_INSTALL in str(held):
            setattr(module, attr, ABSENT)
            redirected += 1
    if not redirected:
        return None, False
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        try:
            code = module.main()
        except SystemExit as exc:
            code = exc.code
        except Exception as exc:
            code = "EXC:%s" % type(exc).__name__
    return code, "SKIPPED" in out.getvalue()


def main():
    faults = []
    print("=" * 74)
    print("A BORDER THAT CANNOT RUN SAYS SO")
    print("=" * 74)
    if not TOOLS.is_dir():
        print("  FAULT: no tools directory at %s" % TOOLS)
        return 1

    looked, checked, skipping = 0, 0, 0
    for path in sorted(TOOLS.glob("*.py")):
        if path.name == pathlib.Path(__file__).name:
            continue
        if not reads_the_game(path):
            continue
        looked += 1
        code, said = run_absent(path)
        if code is None:
            continue
        checked += 1
        if said:
            skipping += 1
        if code != 0:
            faults.append("%s exits %s with the game absent - a machine "
                          "without Project Zomboid is not a machine with a "
                          "defect, and this reads as the gate refusing"
                          % (path.name, code))
        elif not said:
            faults.append("%s returns 0 with the game absent and says nothing "
                          "- silence there cannot be told apart from having "
                          "run" % path.name)

    print("     %d tools name the installed game, %d of them are borders"
          % (looked, checked))
    print("     %d said SKIPPED with it absent" % skipping)
    if checked == 0:
        faults.append("no border was actually exercised; the census is not "
                      "finding them and this border proves nothing")

    workflow = ROOT / ".github" / "workflows" / "ci-verify.yml"
    text = workflow.read_text(encoding="utf-8", errors="ignore") \
        if workflow.exists() else ""
    # The comment wraps across lines with a `#` on each, so the count
    # has to be looked for with the wrapping flattened. The first
    # spelling searched line by line and missed a stale count that was
    # sitting there in two pieces.
    flat = " ".join(part.strip().lstrip("#").strip()
                    for part in text.split("\n"))
    stale = re.search(r"the (six|seven|eight|nine|ten|eleven|twelve) that "
                      r"read the installed", flat)
    if stale:
        faults.append("the workflow still says \"the %s that read the "
                      "installed game\" and there are %d - a count in prose "
                      "goes stale in silence, which is how this drifted"
                      % (stale.group(1), checked))
    print()
    ok = "yes" if text and not stale else "NO "
    print("  %s  the workflow does not carry a stale count" % ok)

    print()
    print("VERDICT:")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  128) skips cleanly: all %d borders that read the installed game "
          "return 0 and say SKIPPED without it, so CI reports what ran rather "
          "than refusing" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
