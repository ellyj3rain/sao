"""Zero-elapsed native snapshot handoff through the just-built shipping adapter."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
ENGINE = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
MOD = ROOT / "mod/42.20/media/java/SAO.jar"
DIST = ROOT / "java/dist/SAOAgent.jar"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--receipt', type=Path, help='write a new replay receipt to this path')
args = parser.parse_args()

def replace(source, old, new):
    count = source.count(old)
    if not count:
        raise ValueError('Probe adaptation seam absent: ' + old)
    return source.replace(old, new)

receipt = {"commands": [], "shipping_sha256": hashlib.sha256(MOD.read_bytes()).hexdigest(),
           "dist_sha256": hashlib.sha256(DIST.read_bytes()).hexdigest(),
           "runtime_origin": "all production classes loaded from shipping jar"}
assert receipt["shipping_sha256"] == receipt["dist_sha256"]
source = (ROOT / "tools/luacheck/PersonSnapshotProbe.java").read_text(encoding="utf-8-sig")
source = replace(source, "public final class PersonSnapshotProbe", "public final class MergedAdapterProbe")
source = replace(source, "String packed = SAONativeSnapshot.capture(source);", """
        String packed = com.sao.engine.SAOHibernation.hibernate(source);
        check(packed.startsWith("v3;"), "adapter did not capture native state");
        check(com.sao.engine.SAOHibernation.validate(packed), "adapter validation refused state");""")
source = replace(source, "check(SAONativeSnapshot.restore(restored, packed) == 6, \"item count\");", """
        String journal = com.sao.engine.SAOHibernation.awaken(restored, packed, 0.0);
        check(journal.startsWith("AWAKENED items=6 mealsDormant=0 drinksDormant=0"), journal);
        System.out.println("ADAPTER " + journal);
        check(com.sao.engine.SAOHibernation.awaken(person(), packed, -1).startsWith("AWAKEN_FAILED"),
                "adapter accepted negative elapsed time");
        check(com.sao.engine.SAOHibernation.awaken(person(), "v3;%%invalid", 0).startsWith("AWAKEN_FAILED"),
                "adapter accepted invalid snapshot");""")
source = replace(source, ".42f", ".99f")
source = replace(source, "source.getStats().set(CharacterStat.PANIC, 37f);",
        "source.getStats().set(CharacterStat.PANIC, 37f);\n"
        "        source.getStats().set(CharacterStat.THIRST, .98f);")
source = replace(source, '&& restored.getStats().get(CharacterStat.PANIC) == 37f, "native stats");',
        '&& restored.getStats().get(CharacterStat.PANIC) == 37f\n'
        '                && restored.getStats().get(CharacterStat.THIRST) == .98f, "native stats");')
source = replace(source, "try { SAONativeSnapshot.restore(person(), packed); }\n        catch (Exception expected) { refused = true; }",
        'refused = com.sao.engine.SAOHibernation.awaken(person(), packed, 0).startsWith("AWAKEN_FAILED");')
source = replace(source, "var restoredWound = restored.getBodyDamage().getBodyPart(BodyPartType.Hand_R);", """
        var bridge = com.sao.bridge.SAOBridge.INSTANCE;
        check(bridge.isInventoryOf(restored, restored.getInventory()), "root container ownership");
        check(bridge.isInventoryOf(restored, restoredBag.getInventory()), "nested container ownership");
        check(bridge.isInventoryOf(restored, restoredKey), "nested item ownership");
        check(bridge.isInventoryOf(restored, restoredRootFood), "root item ownership");
        check(!bridge.isInventoryOf(restored, key), "another person's item ownership");
        check(!bridge.isInventoryOf(restored, new zombie.inventory.ItemContainer()), "unrelated container ownership");
        check(!bridge.isInventoryOf(restored, null), "null inventory reference ownership");
        System.out.println("BRIDGE PASS root/nested item/container ownership and foreign/null refusals");
        var restoredWound = restored.getBodyDamage().getBodyPart(BodyPartType.Hand_R);""")
with tempfile.TemporaryDirectory(prefix="sao-merged-adapter-") as temp:
    work = Path(temp)
    probe = work / "MergedAdapterProbe.java"
    probe.write_text(source, encoding="utf-8")
    classpath = str(MOD) + ";" + str(ENGINE)
    for command in ([JDK / "javac.exe", "-cp", classpath, "-d", work, probe],
                    [JDK / "java.exe", "-Duser.home=" + str(work), "-cp", str(work) + ";" + classpath,
                     "MergedAdapterProbe"]):
        argv = list(map(str, command))
        result = subprocess.run(argv, cwd=work, capture_output=True, text=True, timeout=60)
        receipt["commands"].append({"argv": argv, "cwd": str(work), "exit": result.returncode,
                                    "stdout": result.stdout, "stderr": result.stderr})
        print(result.stdout, end="")
        print(result.stderr, end="")
        if result.returncode:
            receipt["status"] = "FAIL"
            break
    else:
        receipt["status"] = "PASS"
if args.receipt:
    args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print("SHIPPING ADAPTER " + receipt["status"])
raise SystemExit(0 if receipt["status"] == "PASS" else 1)
