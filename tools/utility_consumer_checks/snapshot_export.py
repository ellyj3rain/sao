"""Restore saved native45 plain person data and invoke original C snapshot APIs only."""
from pathlib import Path
import sys,json,re,hashlib,subprocess,os,importlib.util,argparse
H=Path(__file__).resolve().parent;S=H.parents[1];G=Path(os.environ.get("PZ_DIR",r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"));J=Path(os.environ.get("JDK_BIN",r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--out",type=Path,required=True);parser.add_argument("--producer",type=Path,required=True);parser.add_argument("--required",action="store_true");args=parser.parse_args()
out=args.out.resolve();out.mkdir(exist_ok=False);(out/"classes").mkdir()
owned=[Path(__file__),H/"SnapshotDataExport.java",H/"archive_projection.py",args.producer.resolve()]
native=[G/"projectzomboid.jar",G/"ZombieBuddy.jar",J/"java.exe",J/"javac.exe",Path(sys.executable)]
missingOwned=[str(p)for p in owned if not p.is_file()];missingNative=[str(p)for p in native if not p.is_file()]
def unavailable(status,reason,missing_owned=None,missing_native=None):
 (out/"receipt.json").write_text(json.dumps({"schema":"sao-d323-native-snapshot-export/1","status":status,"reason":reason,"missingOwned":missing_owned or [],"missingNative":missing_native or [],"required":args.required,"executedChecks":0},indent=2)+"\n");print(status);raise SystemExit(1 if status=="FAIL"or args.required else 0)
if missingOwned:unavailable("FAIL","missing-owned-source-or-producer",missingOwned,missingNative)
producerPath=args.producer.resolve();capturedProducerPath=producerPath;semantic=False
try:
 producer=json.loads(producerPath.read_text());assert isinstance(producer,dict)and producer.get("schema")in ["sao-d323-native-utility-consumer/1","sao-native-utility-consumer-semantic-qualification/1"]and producer.get("scenario")=="normal"and producer.get("control")is None;semantic=producer.get("schema")=="sao-native-utility-consumer-semantic-qualification/1"
 if producer.get("status")=="NATIVE_UNAVAILABLE":
  assert producer.get("executedChecks")==0 and producer.get("missingOwned")==[] and isinstance(producer.get("missingNative"),list)and producer["missingNative"]and all(isinstance(v,str)for v in producer["missingNative"])
  unavailable("NATIVE_UNAVAILABLE","original-normal-producer-native-unavailable",[],producer["missingNative"])
 assert producer.get("status")=="PASS"and producer.get("inputStable")is True and producer.get("consumerQualified")is True
 if semantic:
  assert producer.get("qualificationMode")=="DATA_ONLY_OF_IMMUTABLE_NATIVE_CHAIN"and all(producer["checks"].values())
  raw=Path(producer["rawProjection"]["path"]);assert sha(raw)==producer["rawProjection"]["sha256"];original=json.loads(raw.read_text());actual={"record":original["record"],"cognition":original["full"],"boundedCognition":original["bounded"],"captureHours":original["captureHours"]}
  capturedProducerPath=Path(producer["rawNativeReceipt"]["path"]);assert sha(capturedProducerPath)==producer["rawNativeReceipt"]["sha256"];capturedProducer=json.loads(capturedProducerPath.read_text());assert capturedProducer.get("inputStable")is True
 else:
  raw=producerPath.parent/"consumer-final.json";assert raw.is_file()and sha(raw)==producer["projections"][raw.name];actual=json.loads(raw.read_text());capturedProducer=producer
 assert isinstance(actual,dict)and isinstance(actual.get("record"),dict)and isinstance(actual.get("cognition"),dict)and actual["record"].get("id")==actual["cognition"].get("actorId")and isinstance(actual.get("captureHours"),(float,int))
except (OSError,ValueError,KeyError,AssertionError,TypeError):unavailable("FAIL","invalid-normal-producer-status-schema-or-record",[],missingNative)
sourcePins={}
for suffix in ["-SAO_Identity.lua","-SAO_CognitiveModels.lua","-SAO_Cognition.lua"]:
 matched=[k for k in capturedProducer.get("capturedFiles",{})if isinstance(k,str)and k.endswith(suffix)]
 if len(matched)!=1:unavailable("FAIL","missing-or-ambiguous-captured-snapshot-source",[],missingNative)
 source=capturedProducerPath.parent/matched[0]
 if not source.is_file()or sha(source)!=capturedProducer["capturedFiles"][matched[0]]:unavailable("FAIL","missing-or-changed-captured-source",[str(source)],missingNative)
 sourcePins[str(source)]=sha(source)
stdlib=capturedProducerPath.parent/"stdlib.lua"
if not stdlib.is_file():unavailable("FAIL","missing-owned-producer-stdlib",[str(stdlib)],missingNative)
if missingNative:unavailable("NATIVE_UNAVAILABLE","native-snapshot-runtime-unavailable",[],missingNative)
plan={"clock":actual["captureHours"],"sourcePins":sourcePins,"projectionArrayFamilies":["alternatives","beliefOrder","completedSteps","consequences","episodes","eventOrder","events","evidenceIds","experiences","generatorOutcomes","generatorReadingOutcomes","hypotheses","missing","models","order","parentIds","predictions","projects","proposals","ranked","resultReceipts","revisions","roots","samples","steps","worldInspectionReceipts"]}
plan["projectionArrayFamilies"].extend(["resourceProductionOutcomes","inputBaselines","inputEffects","inputs","outputs","recipeInputs","slots","skills","itemTypes","itemAlternatives","fluids","energies","tags","unsupported","unmet","items","selectedItemTypes","beliefIds","concerns","commitments","contacts","alternatives","heldItems","nativeFacts","supply","requirements","worldSourceReceipts","children","omittedEvidence"])
arrays=set(plan["projectionArrayFamilies"]);arrayPaths=[]
def literal(v,path):
 if v is None:return "nil"
 if v is True:return "true"
 if v is False:return "false"
 if isinstance(v,(int,float)):return repr(v)
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 assert isinstance(v,dict),path
 numeric=any(re.fullmatch(r"\d+\.0",k)for k in v)
 if numeric:
  assert path.rsplit(".",1)[-1]in arrays,path
  assert set(v)=={str(float(i))for i in range(1,len(v)+1)},path
  arrayPaths.append(path)
 return "{"+",".join("["+(str(int(float(k)))if numeric else json.dumps(k,ensure_ascii=False))+"]="+literal(x,path+"."+k)for k,x in v.items())+"}"
recordLiteral=literal(actual["record"],"record")
restore=out/"restore.lua";restore.write_text("require=function()end\nSAO={History={countyHours=function()return "+repr(plan["clock"])+" end}}\n__record="+recordLiteral+"\nlocal stores={SurvivorAwareness_Records={records={[__record.id]=__record},nextId=1},SurvivorAwareness_Cognition={settings="+literal(actual["cognition"]["settings"],"settings")+"}}\nModData={get=function(k)return stores[k]end,getOrCreate=function(k)assert(stores[k],k);return stores[k]end}\n__exportPlain('imported-record',__record)\n__record=__savedNativeRoundTrip(__record);stores.SurvivorAwareness_Records.records[__record.id]=__record\n__exportPlain('roundtrip-record',__record)\n",encoding="utf-8")
query=out/"query.lua";query.write_text("local c=SAO.Cognition;__exportPlain('actual-full',assert(c.snapshot(__record.id,true)));__exportPlain('actual-bounded',assert(c.snapshot(__record.id,false)));__exportPlain('after-record',__record)\n")
sources=[]
for path,pin in plan["sourcePins"].items():
 p=Path(path);assert sha(p)==pin;sources.append(p)
inputs=[raw,producerPath,H/"SnapshotDataExport.java",Path(__file__),*sources,G/"projectzomboid.jar",G/"ZombieBuddy.jar",stdlib,restore,query];pins={str(p):sha(p)for p in inputs}
cp=os.pathsep.join(map(str,[G/"projectzomboid.jar",G/"ZombieBuddy.jar"]));compile=[str(J/"javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(out/"classes"),str(H/"SnapshotDataExport.java")];r=subprocess.run(compile,text=True,capture_output=True);(out/"compile.log").write_text(r.stdout+r.stderr)
(out/"stdlib.lua").write_bytes((stdlib).read_bytes());command=[str(J/"java.exe"),"-Djava.awt.headless=true","-Duser.home="+str(out),"-cp",str(out/"classes")+os.pathsep+cp,"SnapshotDataExport",str(restore),*map(str,sources),str(query)];a=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=30)if r.returncode==0 else r;(out/"run.log").write_text(a.stdout+a.stderr)
if r.returncode or a.returncode:print(a.stdout,a.stderr);raise SystemExit(1)
for name in ["imported-record","roundtrip-record","after-record"]:assert json.loads((out/(name+".json")).read_text())==actual["record"],name
full=json.loads((out/"actual-full.json").read_text());assert full==actual["cognition"],"original full snapshot differs"
spec=importlib.util.spec_from_file_location("typed",H/"archive_projection.py");module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);bounded=module.cognition(json.loads((out/"actual-bounded.json").read_text()));assert "experiences"not in bounded and len(bounded["episodes"])<=8 and all(len(m["hypotheses"])<=12 for m in bounded["models"])
if "boundedCognition"in actual:assert json.loads((out/"actual-bounded.json").read_text())==actual["boundedCognition"],"original bounded differs from retained live snapshot"
(out/"typed-bounded.json").write_text(json.dumps(bounded,indent=2)+"\n");assert pins=={str(p):sha(p)for p in inputs}
receipt={"status":"PASS_DATA_ONLY_ORIGINAL_FULL_AND_BOUNDED_EXPORT","pins":pins,"classPins":{str(p.relative_to(out/"classes")):sha(p)for p in (out/"classes").rglob("*.class")},"command":command,"compileCommand":compile,"compileExit":r.returncode,"exitCode":a.returncode,"clock":plan["clock"],"sourceArrayPaths":arrayPaths,"sourceArrayFamilies":sorted(arrays),"recordPreservedBeforeNativeRoundtripAfterBothSnapshots":True,"actualFullEquality":True,"actualBoundedSourceAPI":"SAO.Cognition.snapshot(id,false)","fullEvents":len(module.cognition(full)["experiences"]),"models":len(bounded["models"]),"boundedEpisodes":len(bounded["episodes"]),"boundedHypotheses":[len(m["hypotheses"])for m in bounded["models"]],"outputs":{p.name:sha(p)for p in out.glob("*.json")},"nativeBinary":sha(out/"saved-person-native.bin"),"nativeActions":0,"retainedOriginalBoundedEquality": "boundedCognition"in actual,"producerReceiptSHA":sha(producerPath),"semanticQualification":semantic,"boundary":"Exact supplied immutable actual consumer person/clock/settings restored to real native Kahlua, actualIdentity/C/M readonly snapshots. Full equality required; no body/world/physical replay/inference/model/knowledge grant; oldfull45 immutable."};(out/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n");print(receipt["status"],receipt["boundedHypotheses"],sha(out/"receipt.json"))
