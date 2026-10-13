"""Typed projection of actual raw C.snapshot fields; never reconstructs outcomes.
Dense arrays are converted only at source-defined Cognition array paths.
Usage: python archive_projection.py RAW_FINAL_JSON OUT_DIRECTORY
Partial producer packets remain partial regardless of encoding acceptance. Optional fourth argument names the qualified native producer receipt.
"""
from pathlib import Path
import copy,json,hashlib,sys

def dense(value,path):
    if isinstance(value,list):return value
    if not isinstance(value,dict):raise ValueError(path+": source array missing")
    expected={str(float(n)):n for n in range(1,len(value)+1)}
    if set(value)!=set(expected):raise ValueError(path+": non-dense native Lua array")
    return [value[str(float(n))]for n in range(1,len(value)+1)]

def cognition(raw):
    out=copy.deepcopy(raw)
    for key in ["episodes","models","experiences"]:
        if key in out:out[key]=dense(out[key],key)
    for episode in out["episodes"]:
        episode["proposals"]=dense(episode["proposals"],"episode.proposals")
    for model in out["models"]:
        for key in ["beliefs","hypotheses"]:model[key]=dense(model[key],"model."+key)
        for hypothesis in model["hypotheses"]:
            for key in ["parentIds","evidenceIds","missing"]:
                if key in hypothesis:hypothesis[key]=dense(hypothesis[key],"hypothesis."+key)
    # Physical source maps/false flags/numeric identity maps remain unchanged.
    return out

def main():
    source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve()
    if out.exists():raise ValueError("immutable projection output already exists")
    raw=json.loads(source.read_text(encoding="utf-8-sig"));typed=cognition(raw["cognition"])
    producer=None
    if len(sys.argv)>3:
        receipt=Path(sys.argv[3]).resolve();producer=json.loads(receipt.read_text(encoding="utf-8-sig"))
        assert producer["status"]=="PASS"and producer["inputStable"]and producer.get("consumerQualified")and producer["scenario"]=="normal"
        assert source.parent==receipt.parent and producer["projections"][source.name]==hashlib.sha256(source.read_bytes()).hexdigest()
    # Detect a genuinely sparse source-array omission rather than accepting it.
    bad=copy.deepcopy(raw["cognition"])
    if bad["episodes"]:
        bad["episodes"]["10000.0"]=bad["episodes"].pop(next(iter(bad["episodes"])))
        try:cognition(bad)
        except ValueError:control="DETECTED"
        else:raise AssertionError("sparse episode control undetected")
    else:control="NOT_APPLICABLE_EMPTY_EPISODES"
    assert raw==json.loads(source.read_text(encoding="utf-8-sig"))
    out.mkdir(parents=True);target=out/"typed-cognition.json";target.write_text(json.dumps(typed,indent=2)+"\n",encoding="utf-8")
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    (out/"receipt.json").write_text(json.dumps({"status":"PREPARED_TYPED_ACTUAL_CONSUMER_ARCHIVE"if producer else"PREPARED_TYPED_PARTIAL_ARCHIVE","rawProjection":str(source),"rawSHA":sha(source),"typedSHA":sha(target),"source":str(Path(__file__).resolve()),"sourceSHA":sha(Path(__file__)),"arrays":"Cognition episodes/models/experiences; episode proposals; model beliefs/hypotheses; hypothesis parentIds/evidenceIds/missing only","sparseArrayControl":control,"events":len(typed.get("experiences",[])),"models":len(typed["models"]),"sourceShapePreserved":True,"nativeActions":0,"producerReceipt":str(receipt)if producer else None,"producerReceiptSHA":sha(receipt)if producer else None,"captureHours":raw.get("captureHours"),"fullConsumerAcceptance":"Owning immutable native producer supplies semantic scope; typed encoding is read-only and earns no extra acceptance"},indent=2)+"\n")
    print(control,len(typed.get("experiences",[])),len(typed["models"]))
if __name__=="__main__":main()
