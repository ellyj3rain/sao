"""Production handover with installed queue/base-action Lua and controlled inventory/native-stack boundaries."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import personal_handover_test as prior
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", str(prior.PZ_DIR)))
JDK = Path(os.environ.get("JDK_BIN", str(prior.JDK)))
SOURCE = prior.HANDOVER
CASES = ROOT / "tools/handover_cancel_cases.lua"
INSTALLED = [GAME / name for name in (
    "media/lua/shared/ISBaseObject.lua", "media/lua/shared/TimedActions/ISBaseTimedAction.lua",
    "media/lua/client/TimedActions/ISTimedActionQueue.lua", "media/lua/client/TimedActions/ISInventoryTransferAction.lua")]
BOOT = '''
require=function()end
instanceof=function()return false end
Events={OnTick={Add=function()end}}
ISInventoryPage={}
for _,name in ipairs({"ClimbThroughWindowState","ClimbOverFenceState","ClimbOverWallState","ClimbSheetRopeState","ClimbDownSheetRopeState","CloseWindowState","OpenWindowState"}) do
    _G[name]={instance=function()return {}end}
end
'''


def run():
    out=ROOT/"_scratch/d1-shared-reasoning/conflict/handover"/datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    out.mkdir(parents=True)
    files=[SOURCE,CASES,Path(__file__),Path(prior.__file__),prior.RUNNER,(GAME / "projectzomboid.jar"),(GAME / "stdlib.lua"),*INSTALLED]
    files.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(files, GAME, JDK, "handover cancel")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins():
        return {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    receipt={"status":"INCOMPLETE","boundary":__doc__,"inputs":pins(),"runs":[]}
    def save(): (out/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    save()
    command=[JDK/"javac.exe","-cp",(GAME / "projectzomboid.jar"),"-d",out,prior.RUNNER]
    result=subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=60)
    assert result.returncode==0,result.stdout+result.stderr
    (out/"stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
    boot=out/"boot.lua";boot.write_text(BOOT,encoding="utf-8")
    original=SOURCE.read_text(encoding="utf-8")
    variants=[
        ("production",None,None,None),
        ("no-native-stop",'action:forceStop() end)','return end)',"current_native_owner_pending"),
        ("native-release-assumed",'if not ok or queued or native then return false, "pending" end','if not ok then return false, "pending" end',"current_native_owner_pending"),
        ("whole-queue-stop",'then q:onCompleted(self)','then q:resetQueue()',"successor_started_once"),
        ("receipt-actor-bypassed",'if not rec or rec.actorId ~= identity(actorId) then','if not rec then',"wrong_receipt_actor_refused"),
        ("replacement-body-owner",'or SAO.Body.get(id) ~= body','or false',"old_body_not_current"),
        ("replaced-action-callback",'or live.action ~= action or not action','or false or not action',"replaced_action_late_callback_blocked"),
        ("stale-token",'if not ok or token ~= live.actorToken then','if not ok then',"stale_attempt_token_refused"),
        ("physical-completion-overwritten",'    reconcileTransfer(rec, live)\n    live.cancelRequested = true','    -- defective omitted completion reconciliation\n    live.cancelRequested = true',"physical_completion_preserved"),
        ("terminal-drops-native-binding",'    retiring[tostring(rec.id)] = live\n    runtime[tostring(rec.id)] = nil','    runtime[tostring(rec.id)] = nil',"completed_native_handback"),
        ("canonical-record-generation",'and data.SAOExternalToken == person.bodyOwnerToken','and true',"record_token_only_callbacks_blocked"),
        ("foreign-owner-agreement",'and data.SAOExternalOwner == person.bodyOwner','and true',"foreign_owner_mismatch_refused"),
        ("trim-active-receipt",'and runtime[tostring(key)] == nil and retiring[tostring(key)] == nil','',"trim_preserves_native_held_terminal"),
    ]
    for name,old,new,expected in variants:
        candidate=out/(name+".lua")
        if old: assert original.count(old)==1,name
        candidate.write_text(original.replace(old,new,1) if old else original,encoding="utf-8")
        command=[JDK/"java.exe","-cp",str((GAME / "projectzomboid.jar"))+os.pathsep+str(out),"LuaRun",boot,*INSTALLED,CASES,candidate,"--","runHandoverCancelCases()"]
        result=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=60)
        log=result.stdout+result.stderr
        (out/(name+".log")).write_text(log,encoding="utf-8")
        receipt["runs"].append({"name":name,"command":list(map(str,command)),"exit":result.returncode,"expectedFailure":expected,"logSha256":hashlib.sha256(log.encode()).hexdigest()});save()
        assert (result.returncode!=0 and "HANDOVER_CANCEL:"+expected in log) if expected else (result.returncode==0 and "PASS handover cancellation" in log),log
        print(name+": "+(expected or log.strip()),flush=True)
    value,detail=prior.run_probe()
    import re
    verdicts=dict(re.findall(r"([a-z0-9_]+)=(true|false)",value or ""))
    assert set(verdicts)==prior.EXPECTED and all(v=="true" for v in verdicts.values()),detail
    controlled,detail=prior.mutation_control();assert controlled,detail
    receipt["priorRegression"]={"checks":len(verdicts),"queueCreditControl":controlled}
    receipt["inputsAfter"]=pins();assert receipt["inputsAfter"]==receipt["inputs"],"inputs changed"
    receipt["status"]="PASS";save();print("receipt="+str(out/"receipt.json"))


if __name__=="__main__":
    try:run()
    except Exception as error:
        print("FAIL handover cancellation: "+str(error),file=sys.stderr)
        raise SystemExit(1)
