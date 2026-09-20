import hashlib,json,pathlib,shutil,subprocess,sys,tempfile,time
root=pathlib.Path.cwd()
evidence=root/'artifacts/audits/20260920-0158Z-1858PST-person-continuity/native'
paths=['tools/person_snapshot_test.py','tools/person_continuity_test.py','tools/dormant_physiology_test.py','tools/menu_reach.py','tools/luacheck/PersonSnapshotProbe.java','java/src/com/sao/engine/SAONativeSnapshot.java','java/src/com/sao/engine/SAOHibernation.java','java/src/com/sao/bridge/SAOBridge.java','mod/42.20/media/lua/client/SAO_Body.lua','mod/42.20/media/lua/client/SAO_AfflictedReturn.lua']
record={'source_hashes':{},'results':[]}
with tempfile.TemporaryDirectory(prefix='sao-native-baseline-') as tmp:
    base=pathlib.Path(tmp)
    for name in paths:
        target=base/name
        target.parent.mkdir(parents=True,exist_ok=True)
        data=(root/name).read_bytes()
        target.write_bytes(data)
        record['source_hashes'][name]=hashlib.sha256(data).hexdigest()
    for name in paths[:3]:
        start=time.perf_counter()
        result=subprocess.run([sys.executable,str(base/name)],cwd=base,capture_output=True,text=True,encoding='utf-8',errors='replace')
        entry={'entry_point':name,'seconds':time.perf_counter()-start,'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
        record['results'].append(entry)
        print(name,entry['seconds'],result.returncode,flush=True)
        (evidence/'baseline.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        (evidence/(pathlib.Path(name).stem+'.baseline.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
record['total_seconds']=sum(r['seconds'] for r in record['results'])
(evidence/'baseline.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
raise SystemExit(int(any(r['returncode'] for r in record['results'])))
