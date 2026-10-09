#!/usr/bin/env python3
"""Disable the pinned Viewpoint frame-cap override in the extracted SAO bundle.

The source ON value is assigned by FrameCaps.<clinit>'s three-byte
BuildPin.supported() invocation. SAO already performs that pin independently
before activating Viewpoint. Replacing only that invocation with false keeps
the original stack height, code offsets and all other source behavior intact.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

ORIGINAL_SHA256 = "ab2bbd734428b45e02215efd056df46ab4f2d8a8cc848458f69f9227dcf7d6ac"
ADAPTED_SHA256 = "5c24be6898f4070e071f9301bddcbc9fde3c96bab25762b1b9b34cdf200537fb"
ORIGINAL = bytes.fromhex("b8 01 11 b3 01 16")
ADAPTED = bytes.fromhex("03 00 00 b3 01 16")
BYTE_OFFSET = 7322


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def adapt(value: bytes) -> bytes:
    if digest(value) != ORIGINAL_SHA256:
        raise ValueError("pinned Viewpoint FrameCaps class changed")
    if value[:4] != b"\xca\xfe\xba\xbe" or len(value) != 7446:
        raise ValueError("pinned Viewpoint FrameCaps classfile differs")
    if value[BYTE_OFFSET:BYTE_OFFSET + len(ORIGINAL)] != ORIGINAL or value.count(ORIGINAL) != 1:
        raise ValueError("pinned Viewpoint FrameCaps <clinit> assignment differs")
    result = value[:BYTE_OFFSET] + ADAPTED + value[BYTE_OFFSET + len(ORIGINAL):]
    if digest(result) != ADAPTED_SHA256:
        raise ValueError("adapted Viewpoint FrameCaps bytes differ")
    if [index for index, (before, after) in enumerate(zip(value, result)) if before != after] != [
            BYTE_OFFSET, BYTE_OFFSET + 1, BYTE_OFFSET + 2]:
        raise ValueError("adapted Viewpoint FrameCaps scope differs")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("classfile", type=Path)
    arguments = parser.parse_args()
    source = arguments.classfile
    if source.is_symlink() or not source.is_file():
        raise ValueError("extracted Viewpoint FrameCaps class is unavailable")
    source.write_bytes(adapt(source.read_bytes()))
    print("[build] adapted pinned Viewpoint FrameCaps ON=false")


if __name__ == "__main__":
    main()
