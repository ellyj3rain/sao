#!/usr/bin/env python3
"""Independent cognition and real native-use receipts on installed Kahlua.

All compilation and native fixture homes are private temporary directories.
Optional source overlays support candidate verification before tracked release.
The default invocation reads only this repository's production modules.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--candidate-root", type=Path)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    root = args.source_root.resolve()
    candidate = (args.candidate_root or root).resolve()
    output = (args.output or root / "_scratch/cognition-checks").resolve()
    os.environ["SAO_COGNITION_SOURCE_ROOT"] = str(root)
    os.environ["SAO_COGNITION_CANDIDATE_ROOT"] = str(candidate)
    os.environ["SAO_COGNITION_OUTPUT"] = str(output)
    if args.model:
        os.environ["SAO_COGNITION_MODEL"] = str(args.model.resolve())
    else:
        os.environ.pop("SAO_COGNITION_MODEL", None)
    # Gate invocation always executes all production-source defect controls.
    os.environ.pop("BASELINE_ONLY", None)
    sys.path.insert(0, str(Path(__file__).resolve().parent / "cognition_checks"))
    import run_checks
    import run_native_use
    import run_producers
    import run_lifecycle
    if not (run_checks.GAME / "projectzomboid.jar").is_file():
        print("SKIPPED cognition: installed PZ Kahlua/native engine absent")
        return 0
    files = [candidate / "mod/42.20/media/lua/shared/SAO_Cognition.lua",
        candidate / "mod/42.20/media/lua/shared/SAO_Perception.lua",
        candidate / "mod/42.20/media/lua/shared/SAO_WorldSources.lua",
        candidate / "mod/42.20/media/lua/client/SAO_SourceUse.lua",
        candidate / "mod/42.20/media/lua/client/SAO_Needs.lua", run_checks.MODEL,
        root / "mod/42.20/media/lua/client/SAO_Controller.lua",
        root / "mod/42.20/media/lua/shared/SAO_Identity.lua",
        root / "mod/42.20/media/lua/shared/SAO_Labor.lua"]
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    run_checks.run()
    run_producers.run()
    run_native_use.run()
    run_lifecycle.run()
    assert all(hashlib.sha256(path.read_bytes()).hexdigest() == hashes[str(path)] for path in files), "Source changed during cognition checks"
    receipts = [output / name for name in ("receipt.json", "producer-receipt.json", "native-use-receipt.json", "lifecycle-receipt.json")]
    combined = {"schema": "sao-cognition-checks/1", "sources": hashes,
        "receipts": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in receipts},
        "limits": "Installed Kahlua production modules; native shell/item/fluid effects with controlled queue/animation context. "
                  "WorldSources/SourceUse inspection and transfer adapters are controlled separately. No rendered gameplay or dataset admission."}
    (output / "combined-receipt.json").write_text(json.dumps(combined, indent=2) + "\n", encoding="utf-8")
    print("Border 201 PASS: independent cognition ledger, authentic producer joins and native use receivers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
