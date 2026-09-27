#!/usr/bin/env python3
"""Border 202: installed native orientation, hearing, gaze and head-pose checks."""
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from orienting_checks.run_checks import main


if __name__ == "__main__":
    result = main(default_root=Path(__file__).resolve().parents[1])
    print("  202) Native orientation check completed; exit", result, flush=True)
    raise SystemExit(result)
