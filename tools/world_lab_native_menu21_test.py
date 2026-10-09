"""Compile real capture sources and exercise menu/body epochs under controlled stubs.

The fixture does not launch a game or encoder and never opens a user save.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import world_lab_participant_java_test as Participant

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / 'tools/world_lab/StudyNativeMenuCapture21Test.java'


def pin(path: Path) -> dict:
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    jars = [Participant.GAME / 'projectzomboid.jar', Participant.GAME / 'ZombieBuddy.jar']
    jdk = Participant.JDK
    dependencies = [*jars, jdk / 'javac.exe', jdk / 'java.exe']
    for path in dependencies:
        if not path.is_file():
            raise FileNotFoundError(path)
    sources = sorted({ROOT / 'tools/world_lab' / name
                      for cohort in Participant.COHORTS.values() for name in cohort} | {TEST, Path(__file__).resolve()})
    before = [pin(path) for path in sources]
    rows = []

    def run(label: str, command: list[Path | str]) -> int:
        command = [str(part) for part in command]
        result = subprocess.run(command, capture_output=True, text=True,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        log = output / (label + '.log')
        log.write_text(result.stdout + result.stderr, encoding='utf-8')
        row = {'label': label, 'exitCode': result.returncode, 'log': pin(log)}
        rows.append(row)
        print(json.dumps({'label': label, 'exitCode': result.returncode}), flush=True)
        return result.returncode

    jar_cp = os.pathsep.join(map(str, jars))
    classes = output / 'participant-classes'
    classes.mkdir()
    participant = [ROOT / 'tools/world_lab' / name for name in Participant.COHORTS['participant']]
    run('participant-compile', [jdk / 'javac.exe', '-cp', jar_cp, '-d', classes, *participant])
    observer_classes = output / 'observer-classes'
    observer_classes.mkdir()
    observer = [ROOT / 'tools/world_lab' / name for name in Participant.COHORTS['observer']]
    run('observer-compile', [jdk / 'javac.exe', '-cp', jar_cp, '-d', observer_classes, *observer])
    stub_source = output / 'stub-source'
    for name, body in Participant.STUBS.items():
        path = stub_source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding='utf-8')
    stub_classes = output / 'stub-classes'
    stub_classes.mkdir()
    run('stubs-compile', [jdk / 'javac.exe', '-cp', jar_cp, '-d', stub_classes,
                          *sorted(stub_source.rglob('*.java'))])
    cp = os.pathsep.join(map(str, [stub_classes, classes, *jars]))
    if all(row['exitCode'] == 0 for row in rows):
        run('menu-test-compile', [jdk / 'javac.exe', '-cp', cp, '-d', stub_classes, TEST])
    if all(row['exitCode'] == 0 for row in rows):
        fixture = output / 'fixture'
        fixture.mkdir()
        run('menu-test', [jdk / 'java.exe', '-Djava.awt.headless=true',
                          '-cp', cp, 'StudyNativeMenuCapture21Test', fixture])
        menu_log = (output / 'menu-test.log').read_text(encoding='utf-8')
        match = re.search(r'(?m)^PASS (\d+) controlled checks$', menu_log)
        rows[-1]['checks'] = int(match.group(1)) if match else 0
        if not match:
            rows[-1]['exitCode'] = 1
    after = [pin(path) for path in sources]
    errors = [row['label'] for row in rows if row['exitCode'] != 0]
    if before != after:
        errors.append('source-changed-during-validation')
    receipt = {
        'schema': 'sao.native-menu-capture-source-qualification/1',
        'status': 'PASS_SOURCE_CONTROLLED' if not errors else 'FAIL',
        'scope': 'Real Java capture sources and installed jars, synthetic engine stubs and GPU bytes; no game, encoder or save opened.',
        'sourceBefore': before,
        'sourceAfter': after,
        'dependencies': [pin(path) for path in dependencies],
        'results': rows,
        'errors': errors,
    }
    target = output / 'qualification21.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': receipt['status'], 'receipt': pin(target), 'errors': errors}), flush=True)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
