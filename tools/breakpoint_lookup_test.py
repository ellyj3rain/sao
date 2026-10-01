"""Execute the installed Lua debugger branches with and without the study jump."""
import os
from pathlib import Path
import subprocess
import tempfile
from regional_observer_test import GAME, JDK

ROOT = Path(__file__).resolve().parents[1]

def run():
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print("SKIPPED Lua lookup: installed engine or JDK absent")
        return
    source = ROOT / "tools/world_lab"
    native = os.pathsep.join(str(GAME / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    with tempfile.TemporaryDirectory(prefix="sao-lua-lookup-") as temporary:
        work = Path(temporary)
        names = ("StudyLoadingAgent.java", "StudyObserver.java", "StudyViewCapture.java", "StudyExport.java", "NativeBreakpointLookupProbe.java")
        subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", native, "-d", str(work),
            *(str(source / name) for name in names)], check=True, cwd=GAME, timeout=60)
        def agent(name, entry):
            manifest = work / (name + ".mf")
            manifest.write_text("Manifest-Version: 1.0\nPremain-Class: " + entry + "\nCan-Retransform-Classes: true\n\n")
            jar = work / (name + ".jar")
            subprocess.run([str(JDK / "jar.exe"), "cfm", str(jar), str(manifest), "-C", str(work), "."], check=True, timeout=60)
            return jar
        study = agent("study", "StudyLoadingAgent")
        capture = agent("capture", "NativeBreakpointLookupProbe")
        for label, observer, mode in (("empty-map", True, "empty-map"), ("native", True, "native"), ("native", False, "empty-map")):
            home = work / (label + "-" + str(observer)); home.mkdir()
            result = subprocess.run([str(GAME / "jre64/bin/java.exe"), "-Djava.awt.headless=true", f"-Duser.home={home}",
                f"-Dstudy.observer={str(observer).lower()}", f"-Dstudy.luaBreakpointLookup={mode}",
                f"-javaagent:{study}=isolated-study", f"-javaagent:{capture}", "--enable-native-access=ALL-UNNAMED",
                "-cp", str(work) + os.pathsep + native, "NativeBreakpointLookupProbe", label],
                cwd=GAME, capture_output=True, text=True, timeout=60)
            if result.returncode or "PASS installed Lua lookup" not in result.stdout:
                raise AssertionError(result.stdout + result.stderr)
            print(result.stdout.split("PASS installed Lua lookup", 1)[1].strip())
        original = (source / "StudyLoadingAgent.java").read_text(encoding="utf-8")
        seam = '"isEmpty", "()Z", false'
        if original.count(seam) != 1:
            raise AssertionError("empty lookup control seam differs")
        mutation = work / "StudyLoadingAgent.java"
        mutation.write_text(original.replace(seam, '"size", "()I", false'), encoding="utf-8")
        subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(work)+os.pathsep+native,
            "-d", str(work), str(mutation)], check=True, cwd=GAME, timeout=60)
        study = agent("mutant-study", "StudyLoadingAgent")
        home = work / "control-home"; home.mkdir()
        result = subprocess.run([str(GAME / "jre64/bin/java.exe"), "-Djava.awt.headless=true", f"-Duser.home={home}",
            "-Dstudy.observer=true", f"-javaagent:{study}=isolated-study", f"-javaagent:{capture}",
            "--enable-native-access=ALL-UNNAMED", "-cp", str(work)+os.pathsep+native,
            "NativeBreakpointLookupProbe", "empty-map"], cwd=GAME, capture_output=True, text=True, timeout=60)
        if result.returncode == 0 or "empty native map still performs instruction lookups" not in result.stdout+result.stderr:
            raise AssertionError("empty lookup mutation survived or failed for another reason")
        print("PASS restored native lookup defect is rejected for actual instruction lookups")
    print("Border 223 PASS: study-only empty breakpoint lookup with native fallback and installed error controls")

if __name__ == "__main__":
    raise SystemExit(run())
