"""Owned native-proof inputs are mandatory; installed dependencies are optional.

CLI controls use exact runner/helper bytes in a disposable tree. Other owned
files are presence fixtures, and dependency paths are deliberately absent, so
these children cannot execute native physics or recursively run proof controls.
"""
import hashlib
import os
from pathlib import Path, PureWindowsPath
import subprocess
import sys
import tempfile


OWNED_GUARD = "    if missing_owned:\n"


def presence(owned, installed, required, label):
    """Return None when ready, otherwise the classified CLI exit code."""
    missing_owned = [str(path) for path in owned if not Path(path).is_file()]
    if missing_owned:
        print(f"FAILED {label}: owned proof inputs absent: " + ", ".join(missing_owned))
        return 1
    missing_installed = [str(path) for path in installed if not Path(path).is_file()]
    if missing_installed:
        print(f"{'FAILED' if required else 'SKIPPED'} {label}: installed proof inputs absent; "
              "native proof unchecked: " + ", ".join(missing_installed))
        return 1 if required else 0
    return None


def installed_path(value):
    """Keep a Windows installation's path components meaningful on other hosts."""
    path = Path(value)
    windows = PureWindowsPath(str(value))
    if os.name != "nt" and windows.is_absolute():
        return Path(windows.as_posix())
    return path


def installed_presence(inputs, game, jdk, label, *, installed_roots=()):
    """Classify a native driver's exact input inventory before hashing it.

    Game/JDK, sibling Steam Workshop and declared source roots are installed dependencies. Repository inputs remain
    mandatory even when the engine is absent. This function never exits during
    import, so importing a native fixture cannot suppress portable checks.
    """
    game, jdk = installed_path(game).resolve(), installed_path(jdk).resolve()
    dependency_roots = [game, jdk, *[installed_path(root).resolve() for root in installed_roots]]
    if game.parent.name.lower() == "common":
        dependency_roots.append(game.parent.parent / "workshop" / "content" / "108600")
    owned, installed = [Path(__file__)], [game / 'projectzomboid.jar',
                                        jdk / 'java.exe', jdk / 'javac.exe']
    for value in inputs:
        path = installed_path(value).resolve()
        (installed if any(path.is_relative_to(root) for root in dependency_roots) else owned).append(path)
    return presence(owned, installed, False, label)


def causal_controls(root, runner, owned, child_args=(), env_updates=None, missing_owned=None):
    """Run actual default/required classification and an owned-guard omission.

Arguments/environment values may contain {absent-engine}, {absent-extension},
and {absent-jdk}; these become absent paths inside the disposable directory.
The returned receipt contains only detached scalar/list/dictionary values.
"""
    root = Path(root).resolve()
    runner = Path(runner)
    runner = (runner if runner.is_absolute() else root / runner).resolve()
    helper = Path(__file__).resolve()
    owned = [(Path(path) if Path(path).is_absolute() else root / path).resolve() for path in owned]
    relatives = [path.relative_to(root) for path in owned]
    if runner not in owned or helper not in owned:
        raise ValueError("CLI controls require the runner and shared helper in owned inputs")
    if any(not path.is_file() for path in owned):
        raise ValueError("CLI controls require a complete actual owned inventory")
    candidate = Path(missing_owned) if missing_owned is not None else next(
        path for path in owned if path not in (runner, helper))
    candidate = (candidate if candidate.is_absolute() else root / candidate).resolve()
    if candidate not in owned or candidate in (runner, helper):
        raise ValueError("Missing-owned control must name an owned non-runner/non-helper file")
    runner_rel, helper_rel = runner.relative_to(root), helper.relative_to(root)
    source_pins = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in owned}
    with tempfile.TemporaryDirectory(prefix="sao-native-preflight-") as directory:
        fixture = Path(directory).resolve() / "owned"
        fixture.mkdir()
        for source, relative in zip(owned, relatives):
            target = fixture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes() if source in (runner, helper)
                               else b"controlled owned presence fixture\n")
        tokens = {"{absent-engine}": str(fixture / "not-installed-engine"),
                  "{absent-extension}": str(fixture / "not-installed-extension"),
                  "{absent-jdk}": str(fixture / "not-installed-jdk")}
        def expand(value):
            value = str(value)
            for token, replacement in tokens.items():
                value = value.replace(token, replacement)
            return value
        args = list(map(expand, child_args))
        if "--required" in args:
            raise ValueError("CLI classification controls select required mode independently")
        env = os.environ.copy()
        env.update({"PZ_DIR": tokens["{absent-engine}"], "PZ_GAME_DIR": tokens["{absent-engine}"],
                    "SAO_TIEN_COOLERS_DIR": tokens["{absent-extension}"],
                    "JDK_BIN": tokens["{absent-jdk}"], "JAVA_HOME": tokens["{absent-jdk}"],
                    "PYTHONDONTWRITEBYTECODE": "1"})
        env.update({str(key): expand(value) for key, value in (env_updates or {}).items()})
        def invoke(required=False):
            command = [sys.executable, "-B", str(fixture / runner_rel), *args]
            if required:
                command.append("--required")
            done = subprocess.run(command, cwd=fixture, env=env, capture_output=True,
                                  text=True, encoding="utf-8", errors="replace", timeout=15)
            return {"argv": command, "required": required, "exitCode": done.returncode,
                    "stdout": done.stdout, "stderr": done.stderr}
        def installed_absent(result, required):
            prefix = "FAILED" if required else "SKIPPED"
            assert result["exitCode"] == (1 if required else 0), result
            assert prefix in result["stdout"] and "installed proof inputs absent" in result["stdout"] \
                and "unchecked" in result["stdout"], result
        default, required = invoke(), invoke(True)
        installed_absent(default, False)
        installed_absent(required, True)
        selected = fixture / candidate.relative_to(root)
        assert selected.resolve().is_relative_to(fixture)
        selected.unlink()
        missing = [invoke(), invoke(True)]
        for result in missing:
            assert result["exitCode"] == 1 and "FAILED" in result["stdout"] \
                and "owned proof inputs absent" in result["stdout"] \
                and str(selected) in result["stdout"], result
        copied_helper = fixture / helper_rel
        original = copied_helper.read_bytes()
        text = original.decode("utf-8")
        if text.count(OWNED_GUARD) != 1:
            raise RuntimeError("Owned-guard mutation anchor must occur exactly once")
        mutant = text.replace(OWNED_GUARD, "    if False:\n", 1).encode("utf-8")
        copied_helper.write_bytes(mutant)
        omission = invoke()
        installed_absent(omission, False)
        copied_helper.write_bytes(original)
        selected.write_bytes(b"controlled owned presence fixture\n")
        assert copied_helper.resolve().is_relative_to(fixture)
        copied_helper.unlink()
        bootstrap = [invoke(), invoke(True)]
        for result in bootstrap:
            assert result["exitCode"] == 1 and "FAILED" in result["stdout"] \
                and "owned proof inputs absent" in result["stdout"] \
                and str(copied_helper) in result["stdout"] \
                and "ModuleNotFoundError" not in result["stderr"], result
        copied_helper.write_bytes(original)
    if any(hashlib.sha256(Path(path).read_bytes()).hexdigest() != expected
           for path, expected in source_pins.items()):
        raise RuntimeError("Actual owned input changed during CLI classification controls")
    return {"schema": "sao-native-proof-preflight-controls/1", "sourcePins": source_pins,
            "boundary": "Exact runner/helper CLI with owned presence fixtures and absent dependencies; no native execution.",
            "classificationCases": [{"case": "complete-owned-default-installed-absence", "run": default},
                                    {"case": "complete-owned-required-installed-absence", "run": required},
                                    {"case": "missing-owned-default-and-required", "missingOwned": str(candidate), "runs": missing}],
            "missingHelperBootstrap": {"case": "missing-shared-helper-default-and-required", "runs": bootstrap},
            "ownedGuardOmission": {"case": "omit-owned-input-guard", "detectedUnsafeSkip": True,
                                   "mutantSha256": hashlib.sha256(mutant).hexdigest(), "run": omission}}
