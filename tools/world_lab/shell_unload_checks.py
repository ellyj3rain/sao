"""Native shell attachment predicate and production-source defect controls."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def run(tmp, GAME, JDK):
    work = Path(tmp).resolve() / "shell-unload-native"
    work.mkdir()
    source = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
    body = source.read_text(encoding="utf-8")
    classpath = os.pathsep.join(str(path) for path in (
        Path(GAME) / "projectzomboid.jar", ROOT / "mod/42.20/media/java/SAO.jar"))
    suffix = ".exe" if os.name == "nt" else ""

    def execute(args, label, expected=None):
        result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=60)
        label.with_suffix(".stdout.log").write_text(result.stdout, encoding="utf-8")
        label.with_suffix(".stderr.log").write_text(result.stderr, encoding="utf-8")
        output = result.stdout + result.stderr
        if expected is None:
            if result.returncode:
                raise AssertionError(f"native unload probe failed: {label}\n{output}")
        elif result.returncode == 0 or expected not in output:
            raise AssertionError(f"native unload defect survived or failed differently: {label}\n{output}")
        return output

    variants = [("production", None, None, None),
        ("missing-object-membership", "!cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell)",
         "!cell.getAddList().contains(shell)", "admitted null-square shell misclassified as unloaded"),
        ("missing-queued-membership", "!cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell)",
         "!cell.getObjectList().contains(shell)", "queued null-square shell misclassified as unloaded"),
        ("missing-current-square", "|| shell.removalPending || shell.getCurrentSquare() != null",
         "|| shell.removalPending", "remaining current square ignored"),
        ("missing-transaction-guard", "|| shell.removalPending || shell.getCurrentSquare() != null",
         "|| shell.getCurrentSquare() != null", "staged return shell misclassified as unloaded")]
    for name, old, new, expected in variants:
        target = work / name
        target.mkdir()
        if old is not None and body.count(old) != 1:
            raise AssertionError(f"native unload control seam differs: {name}")
        changed = target / "SAOBridge.java"
        changed.write_text(body if old is None else body.replace(old, new), encoding="utf-8")
        execute([Path(JDK) / ("javac" + suffix), "-encoding", "UTF-8", "-cp", classpath,
                 "-d", target, changed, ROOT / "tools/world_lab/ShellUnloadProbe.java"], target / "compile")
        output = execute([Path(JDK) / ("java" + suffix), f"-Duser.home={target}",
                          "--enable-native-access=ALL-UNNAMED", "-cp", str(target) + os.pathsep + classpath,
                          "ShellUnloadProbe"], target / "probe", expected)
        if expected is None and "PASS native shell unload state:" not in output:
            raise AssertionError("native unload probe omitted verification receipt")
    print("PASS native shell unload predicate; 4 production-source defects rejected for their stated reasons")
