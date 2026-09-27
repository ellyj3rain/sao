#!/usr/bin/env python3
"""Border 202: exact ordinary and external owners admit private sound cues."""
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    result = subprocess.run([sys.executable,
        str(root / 'tools/orienting_policy_checks/run.py'), str(root)])
    print('  202) orienting policy verification exit:', result.returncode)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
