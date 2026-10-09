"""Native shell attachment predicate and production-source defect controls."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def run(tmp, GAME, JDK, *, sao_jar=None):
    work = Path(tmp).resolve() / "shell-unload-native"
    work.mkdir()
    source = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
    body = source.read_text(encoding="utf-8")
    selected_jar = Path(sao_jar) if sao_jar is not None else ROOT / "mod/42.20/media/java/SAO.jar"
    if not selected_jar.is_file():
        raise AssertionError(f"selected native SAO fixture JAR unavailable: {selected_jar}")
    classpath = os.pathsep.join(str(path) for path in (
        Path(GAME) / "projectzomboid.jar", selected_jar))
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
                 "-d", target, changed,
                 ROOT / "java/src/com/sao/engine/SAOIsoPlayerShell.java",
                 ROOT / "java/src/com/sao/engine/SAOReturnBody.java",
                 ROOT / "tools/world_lab/ShellUnloadProbe.java"], target / "compile")
        output = execute([Path(JDK) / ("java" + suffix), f"-Duser.home={target}",
                          "--enable-native-access=ALL-UNNAMED", "-cp", str(target) + os.pathsep + classpath,
                          "ShellUnloadProbe"], target / "probe", expected)
        if expected is None and "PASS native shell unload state:" not in output:
            raise AssertionError("native unload probe omitted verification receipt")
    print("PASS native shell unload predicate; 4 production-source defects rejected for their stated reasons")
    retirement_checks(work, classpath, JDK, suffix, execute)


def retirement_checks(work, classpath, JDK, suffix, execute):
    sources = {name: (ROOT / relative).read_text(encoding="utf-8") for name, relative in {
        "SAOBridge.java": "java/src/com/sao/bridge/SAOBridge.java",
        "SAOIsoPlayerShell.java": "java/src/com/sao/engine/SAOIsoPlayerShell.java",
        "SAOReturnBody.java": "java/src/com/sao/engine/SAOReturnBody.java",
    }.items()}
    shell = "SAOIsoPlayerShell.java"
    controls = [
        ("production", None, None, None, None),
        ("spawn-rollback-guard", "SAOBridge.java",
         "shell.removalPending = true;\n        try {\n            clearMovementIntent(shell);",
         "try {\n            clearMovementIntent(shell);", "spawn rollback failed descriptor retirement"),
        ("bridge-retains-root", "SAOBridge.java", "shell.retireNativeDescriptor();", "",
         "retired shell remained globally registered"),
        ("static-registry-root", shell,
         "IsoGameCharacter.getSurvivorMap().remove(ownedDescriptor.getID(), ownedDescriptor);", "",
         "retired shell remained globally registered"),
        ("world-registry-root", shell,
         "descriptorWorld.survivorDescriptors.remove(ownedDescriptor.getID(), ownedDescriptor);", "",
         "retired shell remained in world descriptor registry"),
        ("descriptor-body-root", shell, "ownedDescriptor.setInstance(null);", "",
         "retired descriptor retained body reference"),
        ("foreign-static-registration", shell,
         "IsoGameCharacter.getSurvivorMap().remove(ownedDescriptor.getID(), ownedDescriptor);",
         "IsoGameCharacter.getSurvivorMap().remove(ownedDescriptor.getID());",
         "retirement erased foreign descriptor registration"),
        ("foreign-world-registration", shell,
         "descriptorWorld.survivorDescriptors.remove(ownedDescriptor.getID(), ownedDescriptor);",
         "descriptorWorld.survivorDescriptors.remove(ownedDescriptor.getID());",
         "retirement erased foreign world descriptor registration"),
        ("rebound-descriptor", shell,
         "ownedDescriptor != null && ownedDescriptor.getInstance() == this", "ownedDescriptor != null",
         "retirement erased rebound descriptor ownership"),
        ("original-descriptor-lost", shell, "public void retireNativeDescriptor() {",
         "public void retireNativeDescriptor() { SurvivorDesc ownedDescriptor = getDescriptor();",
         "original descriptor leaked after replacement"),
        ("attached-descriptor-retired", shell,
         "!removalPending || getCurrentSquare() != null || isAddedToModelManager()\n"
         "                || (cell != null && (cell.getObjectList().contains(this)\n"
         "                    || cell.getAddList().contains(this)))", "false",
         "attached shell retired descriptor"),
        ("staged-world-root", "SAOReturnBody.java", "shell.retireNativeDescriptor();",
         "IsoGameCharacter.getSurvivorMap().remove(shell.getDescriptor().getID(), shell.getDescriptor());",
         "staged discard retained descriptor ownership"),
    ]
    for label, name, old, new, expected in controls:
        target = work / ("retirement-" + label)
        target.mkdir()
        changed = dict(sources)
        if name is not None:
            if changed[name].count(old) != 1:
                raise AssertionError("retirement mutation seam differs: " + label)
            changed[name] = changed[name].replace(old, new, 1)
        paths = []
        for filename, source in changed.items():
            path = target / filename
            path.write_text(source, encoding="utf-8")
            paths.append(path)
        execute([Path(JDK) / ("javac" + suffix), "-encoding", "UTF-8", "-cp", classpath,
                 "-d", target, *paths, ROOT / "tools/world_lab/ShellRetirementProbe.java"], target / "compile")
        output = execute([Path(JDK) / ("java" + suffix), f"-Duser.home={target}",
                          "--enable-native-access=ALL-UNNAMED", "-cp", str(target) + os.pathsep + classpath,
                          "ShellRetirementProbe"], target / "probe", expected)
        if expected is None and "PASS native shell retirement:" not in output:
            raise AssertionError("native retirement probe omitted verification receipt")
    print("PASS native shell retirement; 11 production-source defects rejected for their stated reasons")
