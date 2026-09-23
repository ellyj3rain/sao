#!/usr/bin/env python3
"""Calendar/hash helpers and explicit refusal of the retired C74 evidence port.

C74 artifacts remain immutable historical evidence. Their county-presence
acquisition basis is unsupported and cannot be regenerated as a current claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

import county_sweep as Sweep
import source_use_test as Source


ROOT = pathlib.Path(__file__).resolve().parent.parent
RECORD = ROOT / "java/src/com/sao/engine/SAORecord.java"

def encoded(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(encoded(value)).hexdigest()


def sha256(path: pathlib.Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def source_label(path: pathlib.Path) -> str:
    """A stable manifest key; local install paths are evidence, not identity."""
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        if path.resolve() == Sweep.PZ.resolve():
            return "installed/projectzomboid.jar"
        if path.resolve() == Sweep.STDLIB.resolve():
            return "installed/stdlib.lua"
        if path.resolve().is_relative_to(Sweep.PZ.parent.resolve()):
            return "installed/" + path.resolve().relative_to(Sweep.PZ.parent.resolve()).as_posix()
        raise RuntimeError("unlabelled external evidence source: " + str(path))


def calendar_values() -> dict:
    source = """\
import com.sao.engine.SAORecord;
public final class C74CalendarEvidence {
  public static void main(String[] args) {
    System.out.println(SAORecord.countyInstant(1993, 6, 8, 0.0, 0));
    System.out.println(SAORecord.countyInstant(1993, 6, 8, 48.0, 0));
    System.out.println(SAORecord.recordHourFor(1993, 6, 8, -7, 0, false));
  }
}
"""
    with tempfile.TemporaryDirectory(prefix="sao-r12-calendar-") as temporary:
        work = pathlib.Path(temporary)
        java = work / "C74CalendarEvidence.java"
        java.write_text(source, encoding="utf-8")
        classpath = os.pathsep.join([str(Source.JAR), str(Sweep.PZ)])
        built = subprocess.run(
            [str(Sweep.JDK / "javac.exe"), "-cp", classpath, "-d", str(work), str(java)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
        if built.returncode:
            raise RuntimeError("calendar evidence compile failed: " + built.stderr[-1200:])
        ran = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp", os.pathsep.join([classpath, str(work)]),
             "C74CalendarEvidence"], capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=180)
        lines = [line.strip() for line in ran.stdout.splitlines() if line.strip()]
        if ran.returncode or lines != ["1993-07-09T00:00:00",
                                      "1993-07-11T00:00:00", "-168.0"]:
            raise RuntimeError("calendar evidence values differ: " + repr(lines))
    return {"schema": "sao-county-calendar-evidence", "schemaVersion": 1,
            "recordId": "county-calendar/shipped-1993-07-09",
            "owner": "SAORecord", "anchorHour": 0,
            "anchorAt": lines[0], "horizonHour": 48, "horizonAt": lines[1],
            "claimEventRecordDay": -7, "claimEventHour": float(lines[2]),
            "resolution": "second", "policy": "save-start-minus-history-offset"}


def print_issue_keys() -> dict:
    """Ask the installed issue producer, independently of the Lua fixture."""
    source = '''import zombie.scripting.objects.Newspaper;
public final class C77PrintIssue {
  public static void main(String[] args) {
    Newspaper paper = Newspaper.KNOX_KNEWS;
    String issue = paper.getIssues().stream().filter(s -> s.equals("KnoxKnews_July2")).findFirst().orElseThrow();
    System.out.println(paper.getTranslationInfoKey(issue));
    System.out.println(paper.getTranslationTextKey(issue));
    System.out.println(paper.toString());
  }
}'''
    with tempfile.TemporaryDirectory(prefix="sao-print-issue-") as temporary:
        work = pathlib.Path(temporary)
        java = work / "C77PrintIssue.java"
        java.write_text(source, encoding="utf-8")
        subprocess.run([str(Sweep.JDK / "javac.exe"), "-cp", str(Sweep.PZ),
                        "-d", str(work), str(java)], check=True, capture_output=True,
                       text=True, timeout=90)
        ran = subprocess.run([str(Sweep.JDK / "java.exe"), "-cp",
                              os.pathsep.join([str(Sweep.PZ), str(work)]), "C77PrintIssue"],
                             check=True, capture_output=True, text=True, timeout=90)
        lines = [line.strip() for line in ran.stdout.splitlines() if line.strip()]
        if len(lines) != 3:
            raise RuntimeError("installed newspaper metadata probe differs: " + repr(lines))
        return dict(zip(("info", "text", "mediaId"), lines))


def atomic_json(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(json.dumps(value, ensure_ascii=False, indent=2,
                                     sort_keys=True, allow_nan=False).encode("utf-8") + b"\n")
    os.replace(temporary, path)


def generate(destination: pathlib.Path) -> None:
    raise ValueError("C74 acquisition exporter retired: county presence does not prove acquisition; use evidenced conversation capture")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    args = parser.parse_args(argv)
    try:
        generate(args.out.resolve())
    except ValueError as error:
        parser.exit(2, "REFUSED: " + str(error) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
