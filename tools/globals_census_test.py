#!/usr/bin/env python3
r"""Border 51 - whose namespace we are in, as the engine sees it.

This mod is going public and will share a load order with other
survivor mods. Two questions then matter and neither had an answer:
what do we reach for that is not ours, and what do we write that is
not ours.

Regex cannot answer either. `local ksData = nil` and a reference to
`ksData` fifteen hundred lines later in a different function look
identical in source and are not the same thing at all - one is a
local, the other is a global read that nobody writes. Only the
compiler knows which.

So this asks the compiler. `tools/luacheck/LuaGlobals.java` compiles
each file with Kahlua - the engine's own - and walks the bytecode for
GETGLOBAL and SETGLOBAL. The opcode numbers are verified against that
compiler rather than remembered ([B45] probed `WRITTEN = 1` and
`local x = READ_ONE` and read back op 7 and op 5). A name inside a
comment or a string is not counted; a name reached through a nested
closure is.

WHAT IT FOUND ON ITS FIRST RUN
------------------------------
`uname`, read three times in `onPlayerDeath` and declared nowhere, so
the county mourned a person called "nil" - the lesson's subject, the
log line, and the belief the walk looks up. And `ksData` at
`SAO_Harness.lua`, out of its local's scope, so a block that renders
the neighbouring mod's memorials had never run once.

Both had been in the tree for months, both read as ordinary code, and
neither was findable by grep.

THE RULES
---------
Every global we touch is classified, and the classification is exact:
a name we no longer touch must come off the list, or the list stops
describing our footprint and starts describing our history.

Every global we assign OUTRIGHT must be ours. Say precisely what that
covers, because [B45]'s lesson was about a border overstating its own
reach: `KS = {}` is a SETGLOBAL and is caught here. `KS.Notify = f` is
not - it compiles to GETGLOBAL plus SETTABLE, and the bytecode alone
does not say the table came from a global.

So the neighbour rule does not lean on that distinction. Any name in
NEIGHBOURS is another mod's namespace, and being in it AT ALL - read
or write - requires an argument, the way [B40] required one for two
reaches that shared a number and [B42] for a collision left standing.
An argument for a namespace we no longer touch is a fault in the other
direction: it has outlived what it argued about.
"""
import pathlib
import subprocess
import sys
import argparse
import hashlib
import json

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = ROOT / "tools" / "luacheck" / "LuaGlobals.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")

OURS = "ours"        # our namespace; the only outright write allowed
LUA_STD = "lua"      # the standard library, as Border 48 reads it
ENGINE = "engine"    # Project Zomboid's own globals
ENGINE_PATCH = "engine-patch"  # exact, argued engine extension seams
NEIGHBOUR = "neighbour"   # another mod's; every one needs an argument

# Why we are inside somebody else's namespace. One entry per mod, and
# the sentence has to survive being read by the person who wrote it.
NEIGHBOURS = {
    "FurniturePushPull": "C117 composes optional installed single-player relocation with exact actor, footprint and contents checks. Both physical APIs retain the installed pickup/place owner; nested delegation produces one measured result. Multiplayer passes through unchanged.",
    "FurniturePushPullClient": "C117 retains the installed shove animation with its private coordinate-only queue disabled, and owns a bounded exact-object single-player delay so stale work cannot bind a replacement object.",
    "WPIso": "C117 reads the installed barrel classifier and exact square lookup when reconciling optional WaterPipes fixture relocation; it does not emit duplicate native object events.",
    "WPServer": "C117 calls the installed authoritative barrel registration commands with the actual actor after verified empty-fixture relocation; unsupported water state refuses before physical effects.",
    "WPUtils": "C117 uses WaterPipes' own coordinate key to read and verify its registration state.",
    "GetWPModData": "C117 reads the installed WaterPipes state before movement and verifies its owning commands afterwards; registration is not inferred from an action-complete boolean.",
    "TienCoolers": "Tien's Coolers owns its installed shared item physics. "
          "C111 reads the optional API and invokes processTopLevel on the "
          "exact authenticated off-slot native inventory in single player. "
          "The installed player/server callbacks keep their authority; "
          "Body orders the owned inventory pass before native capture and "
          "retains unresolved intervals after a partial physical failure. "
          "The global and source callbacks are not replaced.",
    "KS": "Knox Survivors. [B45] holds two of its functions - "
          "`KS.Notify`, the overhead prompt, and `KS.Say`, words over "
          "an actor - because it narrates people this county does not "
          "have (\"a living voice drops to a whisper nearby\") off a "
          "58-tile scan, and the player cannot tell that from ours. "
          "The originals are kept, every held call is counted, the "
          "count reaches the Ledger, and `SAO.Neighbours.restore()` "
          "hands them back. Held, not replaced, and never its settings "
          "- its own three tickboxes still mean what they say.",
    "KnoxSurvivors": "Knox Survivors' REAL global - [C3] found `KS` is "
          "a per-file local in his tree and the [B45] hold had never "
          "engaged. Read for the hold, the profile-name law (DR-014), "
          "and the folded person-verbs. Since [C20] (DR-022, which "
          "SUPERSEDED DR-009's never-driven clause) it is also "
          "WRITTEN, at exactly two seams the absorb border holds: "
          "`SpawnActor` (his one body door, wrapped so absorbed "
          "people cannot be re-bodied) and `GetOption` (his two "
          "population caps answer large so his encounter stream is "
          "not strangled). His profile rows are mirrored, never "
          "deleted.",
    "ZAO": "Zombie Awareness Overhaul - the sister mod of this same "
          "author, the other side of the trilateral. The county READS "
          "its state surface where it is present and never writes it: "
          "the inspect panel shows a turned body's form and "
          "performance from `ZAO.State`, the pathogen seam "
          "(`SAO_PathogenEvents`) turns the county's own events into "
          "its state, `SAO_PathogenPressure` reads the pressure it "
          "reports, Perception stores the form a survivor saw, and "
          "`SAO_Integration` carries it at the world's seams. Every "
          "read is guarded by presence, so a player without it loses "
          "the crossing and nothing else - the same recognised-never-"
          "required posture the doc-pack holds for every other mod, "
          "and this one is ours.",
}

# [C89] Pharmacology is owned source. Legacy NnC save keys remain string
# data in SAO_Pharmacology; no foreign drug registry or callback is a global.

# C98 source-owns Horse execution. These two writes extend exact engine Lua
# seams and retain their originals; they are neither foreign mod namespaces nor
# SAO-owned globals. Keeping each name and reason explicit makes the bytecode
# census refuse any new engine overwrite.
ENGINE_PATCHES = {
    "ContextualActionHandlers": "Build 42 contextual animal interaction table; the Horse handler preserves and delegates to AnimalsInteraction.",
    "isPlayerDoingActionThatCanBeCancelled": "Build 42 cancellation predicate; the Horse wrapper preserves the original and adds dynamic mount-action refusal.",
}

KNOWN = {n: OURS for n in (
    "SAO", "SAOCountyWindow", "SAOInspectWindow", "SAOWire", "SAOJavaBridge",
    # [C80] the medical reading's window, ours, beside the other two.
    "SAOMedicalWindow",
    # [C35] the gesture's timed action, a vanilla-derived class of ours.
    "SAOGestureAction",
    # C102's native-derived skill-book action is source-owned.
    "SAOStudyAction",
    # Actual owned native timed-action classes, with lifecycle qualification.
    "SAONoteReadAction", "SAORecoveryTransitionAction",
    # [C98] Source-owned Horse globals required by engine recipe/registry and
    # compatibility contracts. The rest of Horse execution is require-local.
    "GetSpeeds", "HorseGlueToWoodglue", "HorseModNetMetrics",
)}
KNOWN.update({n: NEIGHBOUR for n in NEIGHBOURS})
KNOWN.update({n: ENGINE_PATCH for n in ENGINE_PATCHES})
KNOWN.update({n: LUA_STD for n in (
    "assert", "error", "getmetatable", "ipairs", "math", "pairs", "pcall", "print", "rawget", "require", "setmetatable",
    "select", "string", "table", "tonumber", "tostring", "type", "unpack", "_G",
)})
KNOWN.update({n: ENGINE for n in (
    # [C87] Installed ISInventoryPaneContextMenu.getContainers/hasOpenFlame
    # and ISInventoryPage.refreshBackpacks use these native client surfaces.
    # C112 installed shared/Util/AdjacentFreeTileFinder.lua:1 owns the window tile helper.
    "AdjacentFreeTileFinder", "ArrayList", "ISInventoryPaneContextMenu", "SafeHouse", "isClient",
    "BodyPartType", "DynamicRadio", "Events", "GameTime", "Keyboard",
    "keyBinding",
    "HaloTextHelper", "ISApplyBandage", "ISReadABook", "ISBarricadeAction",
    # Native server/XpSystem/XPSystem_SkillBook.lua supplies perk and multiplier definitions.
    "SkillBook",
    # [C35] the timed-action base the gesture action derives from.
    "ISBaseTimedAction",
    "ISCollapsableWindow", "ISDrinkFluidAction", "ISEatFoodAction",
    "ISFarmingMenu", "ISGrabItemAction", "ISHarvestPlantAction",
    "ISInventoryTransferAction", "ISPlowAction", "ISReloadWeaponAction",
    "ISSeedActionNew", "ISTakePillAction", "ISTakeWaterAction", "ISTimedActionQueue",
    "ISWaterPlantAction", "ImmutableColor", "IsoPlayer", "ItemTag",
    "ModData", "Perks", "ProceduralDistributions", "RadioBroadCast",
    "RadioLine", "SFarmingSystem", "SandboxVars", "SpawnRegionMgr",
    "SuburbsDistributions", "SurvivorFactory", "UIFont", "ZombRand",
    # [C17] LuaManager$GlobalObject.addVirtualZombie(int,int), javap-
    # verified - the engine's own hand into the native crowd, used by
    # the restitution slice and nothing else.
    # [C24] the engine's sandbox screen class (OptionScreens/
    # SandboxOptions.lua:3) - the ONE class that file exposes as a real
    # global. Its create is wrapped so the county's page panel gets its
    # prerender gated at the instance (manual fields dead until their
    # switches are on, [C22]/F-050). The panel class itself is a
    # per-file LOCAL (line 5) - [C22] hooked that name, read nil, and
    # skipped silently for a full deploy (F-053): a global is not
    # verified until the declaring line has been READ. ColorInfo is the
    # engine color carrier vanilla's own gating idiom recolors with.
    "SandboxOptionsScreen", "ColorInfo",
    # [C23] the vanilla screen that builds the sandbox settings table -
    # its getSandboxSettingsTable is wrapped so overridden neighbour
    # dials are deleted before any row is built.
    "ServerSettingsScreen",
    # [C30] the engine's stat enum (zombie.characters.CharacterStat,
    # javap-verified on 42.20): ENDURANCE, FATIGUE, PAIN, STRESS and the
    # rest, read by SAO_Age for the per-stage drift through
    # Stats.add/remove(CharacterStat, float).
    "CharacterStat",
    # [C39] the engine's trait surfaces (javap-verified on 42.20):
    # zombie.scripting.objects.CharacterTrait holds the vanilla
    # constants and `register(String)`, and
    # zombie.characters.traits.CharacterTraitDefinition builds and
    # prices the definition the creation screen reads. SAO_Traits
    # registers the county's conditions through both.
    "CharacterTrait", "CharacterTraitDefinition",
    # [C89] Native registered sensitivity keys and physical moodle readiness.
    # Both are installed zombie.scripting.objects classes, exposed by LuaManager.
    "ResourceLocation", "MoodleType",
    # Native shared/TimedActions/ISToggleStoveAction.lua:3; loaded cooking owner.
    "ISToggleStoveAction",
    # [C123] Vanilla animal care timed actions.
    "ISAddWaterToTrough", "ISFeedAnimalFromHand",
    "ISHutchGrabEgg", "ISMilkAnimal", "ISPetAnimal", "ISShearAnimal",
    "addVirtualZombie",
    "addSound", "farming_vegetableconf", "getCell", "getCellSizeInSquares", "getClimateManager",
    "getCore", "getFileWriter", "getGameTime",
    "getScriptManager", "getSpecificPlayer", "getText", "getTextManager",
    "getTimestampMs", "getWorld", "instanceof",
    # [C98] Build 42 globals used by the complete source-owned Horse physical
    # implementation. Definitions/classes/functions remain engine-owned; Horse
    # contributes behavior through require-local modules and the two exact
    # extension seams above.
    "Actions", "AnimalAvatarDefinition", "AnimalContextMenu",
    "AnimalDefinitions", "AnimalGenomeDefinitions", "AnimalPartsDefinitions",
    "AttachedLocations", "BloodBodyPartType", "BodyPartSyncPacket",
    "ClutterTables", "DebugLog", "GameVersion", "ISAddAnimalInTrailer",
    "ISAnimalUI", "ISBuildIsoEntity", "ISButcherHookUI", "ISContextMenu",
    "ISEquipWeaponAction", "ISHandcraftAction", "ISPickupAnimal",
    "ISSearchManager", "ISTransferAction", "ISUnequipAction",
    "ISVehicleAnimalUI", "ISVehicleMenu", "ISWalkToTimedActionF",
    "ISWearClothing", "ISWorldObjectContextMenu", "IsoDirections",
    "IsoFlagType", "IsoLightSource", "ItemType", "JoypadButton",
    "JoypadState", "ModelAttachment", "PZAPI", "PZMath",
    "RanchZoneDefinitions", "ScriptManager", "StoryClutter", "Vector2",
    "VehicleDistributions", "copyTable",
    "emulateAnimEventOnce", "forageSystem", "getActivatedMods", "getAnimal",
    "getClassField", "getClassFieldVal", "getControllerPovX",
    "getControllerPovY", "getDebug", "getItemNameFromFullType",
    "getItemTextureName", "getJoypadMovementAxisX", "getJoypadMovementAxisY",
    "getNumClassFields", "getOnlinePlayers", "getPlayer",
    "getPlayerByOnlineID", "getPlayerData", "getPlayerRadialMenu",
    "getSquare", "getTexture", "instanceItem", "isDebugEnabled",
    "isJoypadLTPressed", "isJoypadRTPressed", "isKeyDown", "isServer",
    "luautils", "sendClientCommand", "sendEquip",
    "sendPlayerStat", "sendRemoveItemFromContainer", "sendServerCommand",
    "syncBodyPart", "triggerEvent",
)})


def build():
    cls = OUT / "LuaGlobals.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    if done.returncode == 0:
        return True
    for line in (done.stderr or "").strip().split("\n")[:6]:
        print("    " + line)
    return False


def namespace_classifications(sites, source_writers, context_writers, inventory, native_declared, known=KNOWN, exports=None):
    touched = set(sites)
    owned = set(source_writers) - native_declared - set(known)
    owned = {name for name in owned if (exports and name in exports) or any(
        kind == 'SET' and inventory.original(path) in source_writers[name]
        and inventory.public_namespace(path, name)
        for kind, path in sites.get(name, []))}
    engine = {name for name in touched & native_declared
              if all(kind == 'GET' for kind, path in sites[name])}
    context = {name for name in touched if all(
        (kind == 'GET' and name in native_declared) or (
        (inventory.environment(path), name) in context_writers
        and (kind == 'GET' or inventory.original(path) in context_writers[(inventory.environment(path), name)]))
        for kind, path in sites[name])}
    return owned, engine, context


def local_fallback_reads(sites, inventory, compiled_files):
    from scanner_inventory import guarded_local_fallbacks
    def native_count(path, kind, name):
        row = compiled_files.get(str(path.resolve()))
        if not row:
            return -1
        return sum(line.startswith(kind + ' ' + name + ' ') for line in row['lines'])
    result = set()
    for name, accesses in sites.items():
        if any(kind != 'GET' for kind, _ in accesses):
            continue
        valid = True
        for path in {path for _, path in accesses}:
            original = inventory.original(path)
            if (not original or native_count(path, 'GET', name) != 1
                    or native_count(original, 'GET', name) != 1
                    or native_count(original, 'SET', name) != 0
                    or name not in guarded_local_fallbacks(path.read_text(encoding='utf-8', errors='ignore'))
                    or name not in guarded_local_fallbacks(original.read_text(encoding='utf-8', errors='ignore'))):
                valid = False
                break
        if valid:
            result.add(name)
    return result


def private_access_qualified(kind, path, name, inventory, context_writers):
    """Qualify the exact access, not every unrelated use of its name."""
    key = (inventory.environment(path), name)
    return bool(key[0] and key in context_writers and (
        kind == 'GET' or inventory.original(path) in context_writers[key]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', type=pathlib.Path)
    parser.add_argument('--reuse-compiler', type=pathlib.Path)
    args = parser.parse_args()
    if args.capture and args.capture.exists():
        raise ValueError('namespace evidence output already exists')
    faults = []
    print("=" * 74)
    print("WHOSE NAMESPACE WE ARE IN")
    print("=" * 74)

    files = sorted(LUA.rglob("*.lua"))
    if not (JDK.exists() and PZ.exists() and SRC.exists()):
        print("  SKIPPED - no JDK, no engine jar, or no instrument source")
        print("  51) globals census: SKIPPED, engine absent")
        return 0
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the globals instrument will not compile, so nothing "
              "read the bytecode this run. A border that cannot run is not "
              "a border that passed")
        return 1

    # Windows limits CreateProcess command lines to 32,767 characters.  Full
    # absolute paths repeated the repository prefix once per Lua file and C99
    # crossed that limit merely by adding one shipped module.  The instrument
    # resolves paths from its working directory, so pass the same inventory as
    # repository-relative paths instead of making tree size a hidden border.
    from scanner_inventory import current, declarations, engine_java_names, GAME
    inventory = current()
    digest = lambda p: hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
    authority = {'engineJar': digest(PZ), 'compilerInstrument': digest(SRC)}
    prior = json.loads(args.reuse_compiler.read_text()) if args.reuse_compiler else {}
    if prior and prior.get('compilerAuthority') != authority:
        raise ValueError('reused compiler authority differs')
    if prior and (prior.get('status') not in ('PASS', 'QUALIFIED_WITH_FINDINGS')
                  or prior.get('inputsBefore') != prior.get('inputsAfter')):
        raise ValueError('reused compiler evidence was not stable')
    reusable = prior.get('compiledFiles', {})
    compiled_files, evidence_inputs, reused_files = {}, {}, []
    for path in (pathlib.Path(__file__), ROOT / 'tools/scanner_inventory.py',
                 inventory.package / 'media/SAOSources/manifest.json', SRC, PZ, OUT / 'LuaGlobals.class'):
        evidence_inputs[str(path.resolve())] = digest(path)
    contract_path = ROOT / 'tools/source_namespace_contracts.json'
    if contract_path.is_file():
        evidence_inputs[str(contract_path.resolve())] = digest(contract_path)
        for relative in json.loads(contract_path.read_text())['qualification']['inputs']:
            path = ROOT / relative
            evidence_inputs[str(path.resolve())] = digest(path)
        evidence_inputs.update(inventory.namespace_evidence_inputs())
    def compiled(paths):
        lines = []
        pending = []
        for path in paths:
            key = str(path.resolve())
            evidence_inputs[key] = digest(path)
            old = reusable.get(key)
            if old and old['sha256'] == evidence_inputs[key]:
                compiled_files[key] = old
                reused_files.append(key)
                lines.extend(old['lines'])
            else:
                pending.append(path)
        # Bounded relative-path batches preserve native compiler authority
        # without making Windows command length depend on package growth.
        for start in range(0, len(pending), 64):
            batch = pending[start:start + 64]
            arguments = [str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p) for p in batch]
            done = subprocess.run(
                [str(JDK / "java.exe"), "-cp", f"{PZ};{OUT}", "LuaGlobals"]
                + arguments,
                cwd=ROOT, capture_output=True, text=True, timeout=60)
            if done.returncode and not done.stdout:
                raise RuntimeError('native global inventory failed: ' + done.stderr[:200])
            produced = (done.stdout or '').splitlines()
            lines.extend(produced)
            for path, argument in zip(batch, arguments):
                key = str(path.resolve())
                selected = [line for line in produced if line.endswith(' ' + argument)
                            or line.startswith('FAIL ' + argument + ':')]
                compiled_files[key] = {'sha256': evidence_inputs[key], 'lines': selected}
        return lines
    native_lines = compiled(files)
    originals = sorted({row['original'] for row in inventory.runtime.values()})
    source_writers, context_writers = {}, inventory.environment_fields()
    exports = inventory.global_exports()
    original_to_current = {row['original'].resolve(): path for path, row in inventory.runtime.items()}
    for line in compiled(originals):
        if line.startswith('FAIL '):
            faults.append(line + ' - original namespace proof failed')
        parts = line.split(' ', 2)
        if len(parts) == 3 and parts[0] == 'SET':
            original_path = pathlib.Path(ROOT / parts[2]).resolve()
            source_writers.setdefault(parts[1], set()).add(original_path)
            environment = inventory.environment(original_to_current.get(original_path)) if original_path in original_to_current else None
            if environment:
                context_writers.setdefault((environment, parts[1]), set()).add(original_path)
    native_declared = engine_java_names()
    from lua_stdlib_test import registry as native_stdlib_registry
    stdlib = native_stdlib_registry()
    if stdlib is None:
        raise RuntimeError('native standard-library namespace inventory unavailable')
    native_declared.update(stdlib)
    for name, providers in exports.items():
        source_writers.setdefault(name, set()).update(providers)
    root = str(ROOT) + "\\"

    touched, written, where, sites = set(), set(), {}, {}
    for line in native_lines:
        if line.startswith("FAIL "):
            faults.append(
                line[5:].replace(root, "").replace("\\", "/")
                + " - the instrument could not compile this file, so its "
                "globals went uncounted; an unread file is not a clean one")
            continue
        parts = line.split(" ", 2)
        if len(parts) != 3:
            continue
        kind, name, path = parts
        touched.add(name)
        sites.setdefault(name, []).append((kind, pathlib.Path(ROOT / path).resolve()))
        where.setdefault(name, path.replace(root, "").replace("\\", "/"))
        if kind == "SET":
            written.add(name)

    if not touched:
        faults.append(
            "not one global came back from the instrument, which cannot be "
            "true of ten thousand lines of Lua - the run failed silently")

    # Regex selects relevant installed provider files; only native SETGLOBAL
    # establishes a provider. A reassignment to an engine local is insufficient.
    engine_provider_files = []
    for path in (GAME / 'media/lua').rglob('*.lua'):
        if declarations(path.read_text(encoding='utf-8', errors='ignore')) & touched:
            engine_provider_files.append(path)
    for line in compiled(sorted(engine_provider_files)):
        parts = line.split(' ', 2)
        if parts[0] == 'FAIL':
            faults.append(line + ' - installed Lua provider could not be qualified')
        elif len(parts) == 3 and parts[0] == 'SET':
            native_declared.add(parts[1])

    print(f"  globals touched: {len(touched)}   written: "
          f"{len(written)}   classified: {len(KNOWN)}")
    print("  we write outright: " + ", ".join(sorted(written)))
    print("  neighbours we are inside: "
          + (", ".join(sorted(NEIGHBOURS)) or "none"))

    # An owned source name must have a real current native writer preserving
    # that exact original owner. No prefix grants custody; canonical new
    # global assignments are still checked against KNOWN.
    owned_names, source_engine_reads, context_names = namespace_classifications(
        sites, source_writers, context_writers, inventory, native_declared, exports=exports)
    fallback_names = local_fallback_reads(sites, inventory, compiled_files)
    classified = set(KNOWN) | owned_names | source_engine_reads | context_names | fallback_names
    unclassified = {name: [(kind, path) for kind, path in sites[name]
                          if not (kind == 'GET' and name in native_declared)
                          and not private_access_qualified(kind, path, name, inventory, context_writers)
                          and not inventory.qualified_namespace_access(kind, path, name)]
                    for name in sorted(touched - classified)}
    unclassified = {name: accesses for name, accesses in unclassified.items() if accesses}
    print('  exact original-owned namespaces:', len(owned_names),
          'source native Lua declarations:', len(source_engine_reads))
    print('  exact source local fallback reads:', len(fallback_names))
    for name in unclassified:
        access_path = unclassified[name][0][1].relative_to(ROOT).as_posix()
        faults.append(
            f"`{name}` is touched at {access_path} and is not classified. "
            "If it is ours, say so; if it is the engine's or the standard "
            "library's, say which. The census has no qualified provider or "
            "private environment for this access; inspect its exact source "
            "context before concluding whether it is optional or defective")

    for name in sorted(set(KNOWN) - touched):
        faults.append(
            f"`{name}` is classified here and nothing touches it any more. "
            "Delete the line: this list is what we reach for, and a list "
            "that also holds what we USED to reach for silently permits "
            "its return")

    for name in sorted(NEIGHBOURS):
        if name not in touched:
            faults.append(
                f"NEIGHBOURS argues our presence in `{name}` and nothing "
                "touches it any more. Delete the entry: an argument that "
                "outlived what it argued about describes no code")

    for name in sorted(ENGINE_PATCHES):
        if name not in written:
            faults.append(
                f"ENGINE_PATCHES argues the write to `{name}` and no write "
                "exists. Delete the entry: an engine-patch argument must "
                "describe current bytecode")

    for name in sorted(written):
        source_owned = name in owned_names and all(
            kind != 'SET' or private_access_qualified(kind, path, name, inventory, context_writers)
            or (inventory.original(path) in source_writers[name]
                and inventory.public_namespace(path, name))
            for kind, path in sites.get(name, []))
        if all(kind != 'SET' or private_access_qualified(kind, path, name, inventory, context_writers)
               or inventory.qualified_namespace_access(kind, path, name)
               for kind, path in sites.get(name, [])):
            source_owned = True
        if name in context_names:
            source_owned = True
        if KNOWN.get(name) not in (OURS, ENGINE_PATCH) and not source_owned:
            faults.append(
                f"we WRITE `{name}` without a qualified public owner or exact "
                "private environment. Native SETGLOBAL is confirmed; inspect "
                "the source context to distinguish an intentional lazy publisher "
                "from a leaked temporary or an engine/foreign overwrite")

    print()
    print("VERDICT:")
    if args.capture:
        after = {path: digest(path) for path in evidence_inputs}
        if after != evidence_inputs:
            faults.append('namespace inputs changed during qualification')
        args.capture.parent.mkdir(parents=True, exist_ok=True)
        evidence = {'schema': 'sao.source-namespace-census/1',
                    'status': 'INPUT_DRIFT' if after != evidence_inputs else ('QUALIFIED_WITH_FINDINGS' if faults else 'PASS'),
                    'compilerAuthority': authority, 'compiledFiles': compiled_files,
                    'compilerReuse': {'path': str(args.reuse_compiler.resolve()) if args.reuse_compiler else None,
                                      'sha256': digest(args.reuse_compiler) if args.reuse_compiler else None,
                                      'files': reused_files},
                    'inputsBefore': evidence_inputs, 'inputsAfter': after,
                    'touched': len(touched), 'written': len(written),
                    'sourceOwned': sorted(owned_names), 'nativeReads': sorted(source_engine_reads),
                    'privateEnvironmentNames': sorted(context_names),
                    'localFallbackReads': sorted(fallback_names),
                    'qualifiedPublisherAccesses': [{'name': name, 'kind': kind, 'path': str(path)}
                        for name, accesses in sorted(sites.items()) for kind, path in accesses
                        if inventory.qualified_namespace_access(kind, path, name)],
                    'unclassified': {name: [{'kind': kind, 'path': str(path)} for kind, path in accesses]
                                     for name, accesses in unclassified.items()},
                    'writes': {name: [{'kind': kind, 'path': str(path)} for kind, path in sites[name] if kind == 'SET']
                               for name in sorted(written)}, 'findings': faults,
                    'boundary': 'Native Kahlua compiler GET/SET, installed annotated Java/bootstrap exports and native-compiled relevant engine Lua providers. Original source pins establish provenance, not automatic namespace permission. No runtime or candidate mutation.'}
        args.capture.write_text(json.dumps(evidence, indent=2) + '\n')
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  51) globals census: all {len(touched)} globals we touch are "
          f"classified, the {len(written)} we assign outright are owned "
          "or explicitly argued engine patches, "
          f"and each of the {len(NEIGHBOURS)} foreign namespace(s) we are "
          "inside is argued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
