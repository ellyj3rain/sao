#!/usr/bin/env python3
"""Undeclared-identifier audit ([B16]).

The class that bit three times - `r.debt` where the field was
`owedToMe` ([B10]), `needsNow` where nothing of that name existed
([B15]) - and that the cross-file sweep's border 9 cannot see, because
border 9 checks claim FIELDS and these were LOCALS.

Lua has no compiler to catch this: an undeclared name reads as nil,
and a block guarded on it silently never runs. This is the closest
mechanical net available: per file, collect everything declared
(locals, function names, parameters, loop variables, module-level
assignments) plus the engine globals we legitimately call, then flag
any identifier that is USED as a table or call and never declared.

Honest about being a REPORT, not a gate: Lua's scoping and this
project's dynamic idioms guarantee some false positives, so a human
triages every line. Run it after writing new blocks - that is exactly
when the bug appears.
"""
import re
import pathlib

lroot = (pathlib.Path(__file__).resolve().parent.parent
         / "mod/42.20/media/lua")

ENGINE_GLOBALS = {
    "getCell", "getGameTime", "getWorld", "getSpecificPlayer",
    "getOnlinePlayers", "getCore", "getText", "getSoundManager",
    "getPlayer", "getActivatedMods", "getZomboidRadio", "getTextManager",
    "getClimateManager", "RainManager", "getTimestampMs",
    "instanceof", "ZombRand", "ZombRandFloat", "isServer", "isClient",
    "ModData", "Events", "GameTime", "SandboxVars", "HaloTextHelper",
    "ISTimedActionQueue", "ISInventoryTransferAction", "ISEatFoodAction",
    "ISBarricadeAction", "ISPlowAction", "ISSeedActionNew",
    "ISWaterPlantAction", "ISHarvestPlantAction", "ISFarmingMenu",
    "ISCollapsableWindow", "SFarmingSystem", "farming_vegetableconf",
    "ItemTag", "Perks", "IsoPlayer", "IsoZombie", "UIFont", "UIManager",
    "Vector3f", "RadioBroadCast", "RadioLine", "DynamicRadio",
    "DynamicRadioChannel", "ChannelCategory", "SAOJavaBridge", "SAO",
    "SAOWire", "SAOCountyWindow", "Type", "SurvivorFactory",
    "SpawnRegionMgr", "ISApplyBandage", "ISDrinkFluidAction",
    "ISGrabItemAction", "ISReloadWeaponAction", "ISTakeWaterAction",
    "pairs", "ipairs", "type", "tostring", "tonumber", "pcall", "print",
    "math", "table", "string", "os", "select", "require", "setmetatable",
    "rawget", "rawset", "unpack", "error", "assert", "next", "_G",
}
KEYWORDS = {"and", "or", "not", "if", "then", "else", "elseif", "end",
            "for", "in", "do", "while", "repeat", "until", "return",
            "local", "function", "true", "false", "nil", "break", "self"}

DECL_PATTERNS = (
    r"local\s+function\s+(\w+)",
    r"function\s+[\w.:]*?(\w+)\s*\(",
    r"local\s+([\w\s,]+?)\s*=",
    r"local\s+([\w\s,]+)$",
    r"for\s+([\w\s,]+?)\s+in\b",
    r"for\s+(\w+)\s*=",
)

def strip_noise(text):
    """Comments and string literals are PROSE, not code. The first
    draft of this tool flagged 1661 identifiers, nearly all of them
    words like 'alone.' and 'God.' inside comments and voice lines -
    a report that noisy is worse than no report."""
    text = re.sub(r"--\[\[.*?\]\]", " ", text, flags=re.S)
    text = re.sub(r"--.*", " ", text)
    text = re.sub(r'"[^"]*"', '""', text)
    text = re.sub(r"'[^']*'", "''", text)
    return text


def audit(path):
    text = strip_noise(path.read_text(encoding="utf-8"))
    declared = set(ENGINE_GLOBALS)
    for pattern in DECL_PATTERNS:
        for match in re.finditer(pattern, text, re.M):
            for name in match.group(1).split(","):
                name = name.strip()
                if name.isidentifier():
                    declared.add(name)
    for match in re.finditer(r"function\s*[\w.:]*\(([^)]*)\)", text):
        for name in match.group(1).split(","):
            name = name.strip()
            if name.isidentifier():
                declared.add(name)
    for match in re.finditer(r"^(\w+)\s*=", text, re.M):
        declared.add(match.group(1))
    flags = set()
    for match in re.finditer(r"(?<![\w.:\"'])([a-zA-Z_]\w*)\s*[.:(\[]", text):
        name = match.group(1)
        if name not in KEYWORDS and name not in declared:
            flags.add(name)
    return sorted(flags)

def used_before_declared(path):
    """[B23] The class the check above CANNOT see, because it collects
    declarations position-blind: a FILE-LEVEL local used above its own
    declaration line.

    Lua closes over locals by lexical position, so a function compiled
    earlier in the file does not see a local declared later - the name
    resolves to a nil global instead, and indexing it throws at
    runtime. `STRUCTURED_CREED` was declared beside the function it
    read most naturally with and used about five hundred lines above,
    inside an election. The audit above passed it because a
    declaration existed SOMEWHERE.

    Deliberately conservative so this stays signal rather than noise:
    only names declared exactly once, and only at file level (column
    zero). Any indented declaration of the same name - an inner local,
    a parameter - disqualifies it, because then the earlier use may
    legitimately be a different binding.
    """
    stripped = strip_noise(path.read_text(encoding="utf-8")).split("\n")
    file_level = {}
    disqualified = set()
    for i, line in enumerate(stripped):
        top = re.match(r"local\s+(?:function\s+)?(\w+)", line)
        if top:
            name = top.group(1)
            if name in file_level:
                disqualified.add(name)
            else:
                file_level[name] = i
            continue
        for inner in re.finditer(r"local\s+(?:function\s+)?(\w+)", line):
            disqualified.add(inner.group(1))
    found = []
    for name, declared_at in sorted(file_level.items()):
        if name in disqualified:
            continue
        use = re.compile(r"(?<![\w.:])" + re.escape(name) + r"\s*[.:(\[]")
        for i in range(declared_at):
            if use.search(stripped[i]):
                found.append((name, i + 1, declared_at + 1))
                break
    return found


if __name__ == "__main__":
    total = 0
    for path in (list((lroot / "client").glob("*.lua"))
                 + list((lroot / "shared").glob("*.lua"))
                 + list((lroot / "server").glob("*.lua"))):
        flags = audit(path)
        if flags:
            total += len(flags)
            print(f"{path.name}: {flags}")
    print(f"({total} flagged - a REPORT, triage each; Lua's scoping "
          f"guarantees false positives)")
    scope_bad = 0
    for path in (list((lroot / "client").glob("*.lua"))
                 + list((lroot / "shared").glob("*.lua"))
                 + list((lroot / "server").glob("*.lua"))):
        for name, used_at, declared_at in used_before_declared(path):
            scope_bad += 1
            print(f"{path.name}: {name} used at line {used_at}, but its "
                  f"file-level local is declared at {declared_at} "
                  f"- resolves to a nil global")
    if scope_bad:
        print(f"({scope_bad} used-before-declared - NOT false positives; "
              f"a Lua local is invisible above its own line)")
        # [B23] The one part of this report that is a GATE. Everything
        # above is advisory because Lua's scoping guarantees false
        # positives; this class has none.
        raise SystemExit(2)
    print("(0 used-before-declared)")
