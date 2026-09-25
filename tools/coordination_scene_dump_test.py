#!/usr/bin/env python3
"""Border 191: production, not the scene harness, forms response labels."""
from __future__ import annotations

import collections
import pathlib

import coordination_scene_dump as Scenes


def fail(message: str) -> int:
    print("Border 191 FAULT: " + message)
    return 1


def main() -> int:
    installed = [Scenes.Border.PZ, Scenes.Border.STDLIB,
                 Scenes.Border.JDK / "java.exe",
                 Scenes.Border.JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 191 SKIPPED: installed game VM or JDK absent")
        return 0
    built, detail = Scenes.Border.compile_runner()
    if not built:
        return fail("Lua runner compile failed: " + detail[-1000:])
    if "expectedChoice" in Scenes.canonical(Scenes.SCENES).decode("utf-8"):
        return fail("scene catalogue assigns its own response label")
    try:
        catalogue, rows, manifest = Scenes.build()
    except Exception as error:  # the border must report the production fault
        return fail(str(error))
    for path in Scenes.evidence_paths():
        name = Scenes.source_name(path)
        if manifest["sourceHashes"].get(name) != Scenes.indexed_hash(path):
            return fail("source hash is not the exact Git index blob: " + name)
    saved = Scenes.ROOT / "artifacts/audits/c82-native-coordination-shadow-source"
    for name, data in Scenes.output_bytes(catalogue, rows, manifest).items():
        path = saved / name
        if not path.is_file() or path.read_bytes() != data:
            return fail("tracked scene evidence differs: " + name)
    if len(rows) != 20 or manifest["rowCount"] != len(rows):
        return fail("scene count differs")
    by_namespace = {tuple(row["namespace"].values()) for row in rows}
    if len(by_namespace) != len(rows):
        return fail("full scene namespaces are not unique")
    choices = collections.Counter(entry["response"] for entry in manifest["index"])
    expected = {name: 4 for name in
                ("accept", "qualify", "counter-propose", "defer", "contest")}
    if choices != expected:
        return fail("production response coverage differs: " + repr(dict(choices)))
    for split in ("train", "validation", "test"):
        observed = {entry["response"] for entry in manifest["index"]
                    if entry["split"] == split}
        if observed != set(expected):
            return fail(split + " lacks independent response coverage")
    kinds = {entry["actorKind"] for entry in manifest["index"]}
    if kinds != {"survivor", "afflicted", "crossed"}:
        return fail("survivor/Afflicted/Crossed audit coverage differs")
    for row, entry in zip(rows, manifest["index"], strict=True):
        private = row["enactedProcess"]["decisionTime"]["privateInputs"]
        later = row["enactedProcess"]["laterOutcome"]
        if entry["actorKind"] == "survivor":
            if private["executor"] != "SAO.Controller" or private["bodyOwner"] != "SAO":
                return fail("survivor execution attribution differs")
        elif private["executor"] != "ZAO.Driver" or private["bodyOwner"] != "ZAO":
            return fail("ZAO execution attribution differs")
        if any(field in private.get("constraints", {}) for field in
               ("terminalState", "pathogen", "diagnosis", "diet")):
            return fail("hidden condition truth entered private constraints")
        if later["response"].get("delivered") is not True:
            return fail("actual return-channel delivery was not observed")

    # A pressure mutation must change a production label.  If the exporter had
    # assigned the label itself, this mutant would survive.
    controller = Scenes.CONTROLLER.read_text(encoding="utf-8-sig")
    original = 'elseif ownNeed >= 0.75 then\n        choice = "qualify"'
    replacement = 'elseif ownNeed >= 0.75 then\n        choice = "accept"'
    if controller.count(original) != 1:
        return fail("controller pressure decision seam changed")
    pressure = next(item for item in Scenes.SCENES
                    if item["sceneId"] == "train-survivor-pressured")
    changed = Scenes.run_scene(
        pressure, controller_source=controller.replace(original, replacement, 1))
    if changed["choice"]["optionId"] != "coordination:accept":
        return fail("controller pressure mutation did not change captured choice")

    # Removing the registered execution owner must prevent a ZAO-owned trusted
    # person from being captured as an ordinary capable acceptor.
    zao_controller = Scenes.ZAO_CONTROLLER.read_text(encoding="utf-8-sig")
    registration = 'SAO.Communication.registerExecutionOwner("ZAO", executionAdapter)'
    if zao_controller.count(registration) != 1:
        return fail("ZAO execution registration seam changed")
    trusted = next(item for item in Scenes.SCENES
                   if item["sceneId"] == "train-crossed-trusted")
    try:
        unregistered = Scenes.run_scene(
            trusted, zao_controller_source=zao_controller.replace(
                registration, "false", 1))
    except RuntimeError:
        unregistered = None
    if unregistered and unregistered["choice"]["optionId"] == "coordination:accept":
        return fail("ZAO-owned response bypassed its registered execution owner")

    # A forged executor name must remain visible as a defect instead of being
    # normalized back to the expected owner by the capture layer.
    driver = Scenes.ZAO_DRIVER.read_text(encoding="utf-8-sig")
    executor = 'executor = "ZAO.Driver",'
    if driver.count(executor) != 1:
        return fail("ZAO driver attribution seam changed")
    forged = Scenes.run_scene(
        trusted, zao_driver_source=driver.replace(
            executor, 'executor = "SAO.Controller",', 1))
    forged_private = forged["enactedProcess"]["decisionTime"]["privateInputs"]
    if forged_private["executor"] != "SAO.Controller":
        return fail("capture hid a forged ZAO executor attribution")

    if catalogue["contentSha256"] != Scenes.digest({
            key: value for key, value in catalogue.items()
            if key != "contentSha256"}):
        return fail("scene catalogue seal differs")
    print("Border 191 PASS: 20 pre-split situations yielded five production responses across survivor, Afflicted and Crossed owners; pressure, registration and attribution mutants failed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
