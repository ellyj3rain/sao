#!/usr/bin/env python3
"""Border 205: private native-capability experience in both cognitive models."""
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from capability_experience_checks.run_checks import main


if __name__ == "__main__":
    result = main(default_root=Path(__file__).resolve().parents[1])
    print("  205) Capability experience check completed; exit", result, flush=True)
    raise SystemExit(result)
