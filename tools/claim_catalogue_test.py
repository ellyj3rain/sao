#!/usr/bin/env python3
"""Border 188: typed snapshot claims and selection-bounded fencing."""

from __future__ import annotations

import pathlib
import shutil
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parents[1]
HERE = ROOT / "tools"
KNOWLEDGE = ROOT / "mod/42.20/media/lua/shared/SAO_Knowledge.lua"
BASE = HERE / "luacheck/probe_knowledge.lua"
CASES = HERE / "luacheck/probe_claim_catalogue.lua"
RUNNER = HERE / "luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
CHECK = HERE / "check.sh"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


def build() -> bool:
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= RUNNER.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300,
    )
    return done.returncode == 0


def probe(expression: str, knowledge: pathlib.Path = KNOWLEDGE) -> str:
    with tempfile.TemporaryDirectory() as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for compiled in OUT.glob("*.class"):
            shutil.copy2(compiled, work / compiled.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(BASE), str(knowledge), str(CASES), "--", expression],
            cwd=work, capture_output=True, text=True, timeout=120,
        )
    return (done.stdout or "").strip().splitlines()[-1] if done.stdout else ""


def mutation_result(source: str, old: str, new: str, expression: str) -> str:
    if source.count(old) != 1:
        return "CONTROL SOURCE MISMATCH"
    with tempfile.TemporaryDirectory() as temporary:
        mutated = pathlib.Path(temporary) / KNOWLEDGE.name
        mutated.write_text(source.replace(old, new), encoding="utf-8")
        return probe(expression, mutated)


def main() -> int:
    faults: list[str] = []
    print("=" * 74)
    print("TYPED CLAIM CATALOGUES AND SELECTED FENCING")
    print("=" * 74)

    for path in (KNOWLEDGE, BASE, CASES, RUNNER, CHECK):
        if not path.exists():
            faults.append(f"required file missing: {path}")

    if faults:
        for fault in faults:
            print(f"  FAULT: {fault}")
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists()):
        print("  188) claim catalogue: SKIPPED - engine or JDK absent")
        return 0
    if not build():
        print("  FAULT: Kahlua runner did not compile")
        return 1

    first = probe("ClaimCatalogueProbe.summary(false)")
    reversed_people = probe("ClaimCatalogueProbe.summary(true)")
    checks = {
        "map insertion order cannot move a claim reference":
            first == reversed_people and first.startswith("VALUE event-order/claim/"),
        "known people enter the catalogue":
            probe("ClaimCatalogueProbe.personCount()") == "VALUE 2",
        "the protected world identifier survives inside its entry":
            probe("ClaimCatalogueProbe.worldClaimId()") ==
            "VALUE knox-telecommunications-outage-1993-07-02",
        "references are unique inside the snapshot":
            probe("tostring(ClaimCatalogueProbe.uniqueRefs())") == "VALUE true",
        "the factual fence contains only the selected claim":
            probe("tostring(ClaimCatalogueProbe.selectedFenceIsNarrow())") ==
            "VALUE true",
        "an empty selection has an empty factual fence":
            probe("ClaimCatalogueProbe.emptyFence()") == "VALUE",
        "an unknown reference refuses":
            probe("ClaimCatalogueProbe.unknownReason()") ==
            "VALUE selection-reference-unknown",
        "a duplicate reference refuses":
            probe("ClaimCatalogueProbe.duplicateReason()") ==
            "VALUE selection-reference-duplicate",
        "a foreign snapshot refuses":
            probe("ClaimCatalogueProbe.foreignReason()") ==
            "VALUE selection-snapshot-mismatch",
        "a returned selection is detached":
            probe("tostring(ClaimCatalogueProbe.selectionDetached())") ==
            "VALUE true",
        "the catalogue is detached from its source stores":
            probe("tostring(ClaimCatalogueProbe.catalogueDetached())") ==
            "VALUE true",
        "selection output follows catalogue order":
            probe("tostring(ClaimCatalogueProbe.selectionKeepsCatalogueOrder())") ==
            "VALUE true",
        "duplicate requested topics refuse":
            probe("ClaimCatalogueProbe.duplicateTopicReason()") ==
            "VALUE duplicate-topic",
        "cyclic source values refuse":
            probe("ClaimCatalogueProbe.cyclicReason()") ==
            "VALUE cyclic-value",
        "non-finite source numbers refuse":
            probe("ClaimCatalogueProbe.nonFiniteReason()") ==
            "VALUE non-finite-number",
        "over-deep source values refuse":
            probe("ClaimCatalogueProbe.deepReason()") ==
            "VALUE catalogue-too-deep",
        "the value budget covers the complete catalogue":
            probe("ClaimCatalogueProbe.totalBudgetReason()") ==
            "VALUE catalogue-too-large",
        "one canonical table cannot exceed the safe sort width":
            probe("ClaimCatalogueProbe.tableWidthReason()") ==
            "VALUE catalogue-table-too-wide",
        "known-person enumeration is bounded before sorting":
            probe("ClaimCatalogueProbe.knownPeopleLimitReason()") ==
            "VALUE too-many-known-people",
        "the full claim list is bounded before sorting":
            probe("ClaimCatalogueProbe.claimLimitReason()") ==
            "VALUE catalogue-too-many-claims",
        "the selected fence is bounded before sorting":
            probe("ClaimCatalogueProbe.selectedFenceLimitReason()") ==
            "VALUE selected-fence-too-large",
        "removing a protected source identifier invalidates the entry":
            probe("ClaimCatalogueProbe.tamperedWorldSourceReason()") ==
            "VALUE catalogue-entry-unreadable",
        "missing conditioning invalidates the catalogue":
            probe("ClaimCatalogueProbe.missingConditioningReason()") ==
            "VALUE catalogue-conditioning-unreadable",
        "the repository gate runs this border":
            "tools/claim_catalogue_test.py" in CHECK.read_text(encoding="utf-8"),
    }
    for name, passed in checks.items():
        print(f"  {'yes' if passed else 'NO '}  {name}")
        if not passed:
            faults.append(name)

    source = KNOWLEDGE.read_text(encoding="utf-8")
    controls = {
        "snapshot mismatch control": mutation_result(
            source,
            '        or selection.snapshotRef ~= catalogue.snapshotRef then',
            '        or false then',
            "ClaimCatalogueProbe.foreignReason()",
        ) != "VALUE selection-snapshot-mismatch",
        "selected-only fence control": mutation_result(
            source,
            "    for _, entry in ipairs(selected.claims) do",
            "    for _, entry in ipairs(catalogue.claims) do",
            "tostring(ClaimCatalogueProbe.selectedFenceIsNarrow())",
        ) != "VALUE true",
        "catalogue-wide budget control": mutation_result(
            source,
            "detach(rows[rowIndex], budget)",
            "detach(rows[rowIndex])",
            "ClaimCatalogueProbe.totalBudgetReason()",
        ) != "VALUE catalogue-too-large",
    }
    for name, discriminates in controls.items():
        print(f"  {'yes' if discriminates else 'NO '}  {name} detects its mutation")
        if not discriminates:
            faults.append(f"{name} did not detect its mutation")

    if faults:
        print("\nVERDICT:")
        for fault in faults:
            print(f"  FAULT: {fault}")
        return 1
    print("\n  188) PASS - typed claim catalogues and selected fencing")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
