#!/usr/bin/env python3
"""Exercise rolling native retention, provenance and the actual session lifetime."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import threading
import time
import types
import uuid
from unittest.mock import patch

import world_lab_video_archive as Archive
import world_lab_session as Session

CHECKS = 0


def check(value, message):
    global CHECKS
    CHECKS += 1
    if not value:
        raise AssertionError(message)


def fixture(root, attempt=1, stream=None, run_name="native-run"):
    stream = stream or str(uuid.uuid4())
    source = root / run_name / "attempts" / f"{attempt:04d}" / "native-view"
    source.mkdir(parents=True, exist_ok=True)
    init = {"file": f"video-{stream}-init.mp4", "sha256": Archive.sha(b"init")}
    (source / init["file"]).write_bytes(b"init")
    value = {"schema": "sao-study-video/1", "streamId": stream, "state": "active", "init": init,
             "segments": [], "stats": {"capturedFrames": 0, "encodedFrames": 0, "droppedFrames": 0}}
    session = str(uuid.uuid4())
    receipt_path = root / run_name / "run.json"
    if receipt_path.exists():
        existing = json.loads(receipt_path.read_text())
        if existing.get("launchNumber") == attempt:
            session = existing["sessionId"]
    Archive.atomic(root / run_name / "run.json", {"schema": "sao-study-run/1", "sessionId": session,
        "launchNumber": attempt, "status": "running", "packageSha256": "package", "definitionSha256": "definition"})
    return source, value, session


def publish(source, value, sequences, state="active"):
    rows = []
    for seq in sequences:
        data = ("native-fragment-" + str(seq)).encode()
        file = f"video-{value['streamId']}-{seq:016d}.m4s"
        if not (source / file).exists():
            (source / file).write_bytes(data)
        rows.append({"sequence": seq, "file": file, "sha256": Archive.sha(data),
            "ptsStartMs": (seq-1)*250, "durationMs": 250, "capturedAtUnixMs": 1000+seq*250,
            "endCapturedAtUnixMs": 1249+seq*250, "observerSequence": seq, "worldHours": 2+seq/100,
            "endWorldHours": 2+(seq+.5)/100, "firstFrameSequence": seq*10,
            "lastFrameSequence": seq*10+9, "sites": [{"id": "subject-one", "slot": 0}], "crops": []})
    value.update(segments=rows, state=state)
    Archive.atomic(source / "latest-video.json", value)


def report(archive, value, attempt=1):
    return json.loads((archive.root / f"{attempt:04d}" / value["streamId"] / "stream.json").read_text())


def cases(module=Archive):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        owner = module.Archive(root, "study", min_free_bytes=0)
        owner.initialize()
        source, value, session = fixture(root)
        Archive.atomic(source.parent / "observer-state.json", {"sequence": 1, "updatedAtUnixMs": 1200,
            "sites": [{"id": "subject-one", "followPersonId": "person-a"}]})
        publish(source, value, [1, 2]); owner.poll()
        retained = owner.root / "0001" / value["streamId"]
        (source / value["segments"][0]["file"]).unlink()
        publish(source, value, [3, 4], "ended"); owner.poll()
        state = report(owner, value)
        check(state["coverage"] == "complete-published-segments" and state["retainedSegments"] == 4,
              "rollover lost full-attempt coverage")
        check((retained / f"video-{value['streamId']}-0000000000000001.m4s").read_bytes() == b"native-fragment-1",
              "first published segment was lost")
        check(state["firstSegment"]["ptsStartMs"] == 0 and state["lastSegment"]["endWorldHours"] == 2.045,
              "source timing was not preserved")
        check(state["nativeProvenance"]["sessionId"] == session, "native attempt provenance lost")
        samples = list((owner.root / "0001/observer-mapping").glob("*.json"))
        check(len(samples) == 1 and json.loads(samples[0].read_text())["sites"][0]["followPersonId"] == "person-a",
              "source-owned subject mapping lost")
        check(len(list((retained / "manifests").glob("*.json"))) == 2, "original manifests not retained")
        restarted = module.Archive(root, "study", min_free_bytes=0); restarted.initialize(); restarted.poll()
        check(report(restarted, value)["retainedSegments"] == 4, "host restart lost earlier segments")
        check(report(restarted, value)["coverage"] == "complete-published-segments"
              and not report(restarted, value)["lateAttachment"], "restore reordered terminal/opening evidence")
        second, other, other_session = fixture(root, 2)
        publish(second, other, [1], "ended"); restarted.poll()
        check(report(restarted, other, 2)["nativeProvenance"]["sessionId"] == other_session
              and report(restarted, value)["nativeProvenance"]["sessionId"] == session,
              "native attempts mixed provenance")
        replacement = copy.deepcopy(other); replacement["streamId"] = str(uuid.uuid4())
        newsource, replacement, _ = fixture(root, 2, replacement["streamId"])
        publish(newsource, replacement, [1], "ended"); restarted.poll()
        check(len(restarted.streams) == 3, "encoder streams mixed across reset")
        changed = json.loads((root / 'native-run/run.json').read_text()); changed['sessionId'] = str(uuid.uuid4())
        Archive.atomic(root / 'native-run/run.json', changed)
        try: restarted.poll()
        except ValueError as error: check('session changed' in str(error), 'native identity failed elsewhere')
        else: raise AssertionError('accepted another native session within an attempt')

    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);owner=module.Archive(root,'study',min_free_bytes=0);owner.initialize()
        source,value,_=fixture(root);publish(source,value,[1]);owner.poll()
        sample={'schema':'sao-study-live/1','save':'persistent-save','definitionSha256':'definition',
            'hours':3,'inspection':{'capturedAtUnixMs':1500,'people':[{'id':'person-a','name':'Corey','x':12,'y':14,'z':0}]},
            'people':[{'id':'person-a','name':'Corey','x':12,'y':14,'z':0}]}
        Archive.atomic(root/'native-run/cache/Lua/StudyWorldLive.json',sample);owner.poll()
        second,other,_=fixture(root,2);publish(second,other,[1]);owner.poll()
        stored=list((owner.root/'body-inspection').glob('*.json'))
        check(len(stored)==1 and json.loads(stored[0].read_text())==sample,'body identity/geometry/provenance was changed')
        check(not list((owner.root/'0002').glob('body-inspection/*')),'stale body sample assigned to new attempt')
        check(json.loads((owner.root/'archive.json').read_text())['bodyInspection']['nativeAttemptAssigned'] is False,
              'body samples claimed synchronized attempt identity')
        sample['inspection']['capturedAtUnixMs']=2000;sample['people'][0]['x']=20
        Archive.atomic(root/'native-run/cache/Lua/StudyWorldLive.json',sample);owner.poll()
        check(len(list((owner.root/'body-inspection').glob('*.json')))==2,'changed body geometry sample lost')
    for state in ('ended','failed'):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);owner=module.Archive(root,'study',min_free_bytes=0);owner.initialize()
            source,value,_=fixture(root);publish(source,value,[],state);owner.poll()
            check(report(owner,value)['coverage']=='unavailable','empty terminal video claimed recording')
    with tempfile.TemporaryDirectory() as directory:
        root=Path(directory);first=module.Archive(root,'study',min_free_bytes=0,interval=5).start()
        before=(first.root/'archive.json').read_bytes()
        second=module.Archive(root,'study',min_free_bytes=0,interval=5).start()
        refused=second.error is not None and second.thread is None
        preserved=(first.root/'archive.json').read_bytes()==before
        first.close();second.close()
        check(refused and preserved,'duplicate recorder claimed or overwrote active archive')
        restarted=module.Archive(root,'study',min_free_bytes=0,interval=5).start()
        admitted=restarted.error is None;restarted.close()
        check(admitted,'released archive lock prevented restart')
        command=[sys.executable,'-c',
            'import os,sys;from pathlib import Path;sys.path.insert(0,sys.argv[1]);import world_lab_video_archive as a;'
            'owner=a.Archive(Path(sys.argv[2]),"study",min_free_bytes=0);owner.acquire();os._exit(0)',
            str(Path(Archive.__file__).parent),str(root)]
        child=subprocess.run(command,capture_output=True,text=True,timeout=10)
        check(child.returncode==0,'crashed-owner lock fixture failed: '+child.stderr)
        recovered=module.Archive(root,'study',min_free_bytes=0,interval=5).start()
        admitted=recovered.error is None;recovered.close()
        check(admitted,'process death left stale archive ownership')

    with tempfile.TemporaryDirectory() as directory:
        owner = module.Archive(Path(directory), "study", min_free_bytes=0); owner.initialize()
        source, value, _ = fixture(Path(directory)); publish(source, value, [1]); owner.poll()
        publish(source, value, [3], "ended"); owner.poll()
        state = report(owner, value)
        check(state["coverage"] == "partial" and state["missingSequences"] == [{"first": 2, "last": 2}],
              "missing middle was claimed complete")
    with tempfile.TemporaryDirectory() as directory:
        owner = module.Archive(Path(directory), "study", min_free_bytes=0); owner.initialize()
        source, value, _ = fixture(Path(directory)); publish(source, value, [7, 8], "ended"); owner.poll()
        state = report(owner, value)
        check(state["lateAttachment"] and state["coverage"] == "partial"
              and state["missingSequences"] == [{"first": 1, "last": 6}], "late attachment hid missing opening")
    with tempfile.TemporaryDirectory() as directory:
        owner = module.Archive(Path(directory), "study", min_free_bytes=0); owner.initialize()
        source, value, _ = fixture(Path(directory)); publish(source, value, [1]); owner.poll()
        owner.finished = True; owner.publish()
        check(report(owner, value)['coverage'] == 'partial' and not report(owner, value)['tailConfirmed'],
              'unconfirmed producer tail was claimed complete')
        value['segments'][0]['ptsStartMs'] = 20
        publish(source, value, [2], 'ended'); value['segments'][0]['ptsStartMs'] = 300
        Archive.atomic(source / 'latest-video.json', value); owner.poll()
        check(report(owner, value)['ptsGaps'] and report(owner, value)['coverage'] == 'partial',
              'presentation clock gap was hidden')
    for defect in ("wrong-stream", "bad-hash", "unsafe-file", "bad-clock"):
        with tempfile.TemporaryDirectory() as directory:
            owner = module.Archive(Path(directory), "study", min_free_bytes=0); owner.initialize()
            source, value, _ = fixture(Path(directory)); publish(source, value, [1])
            row = value["segments"][0]
            if defect == "wrong-stream":
                wrong = row["file"].replace(value["streamId"], str(uuid.uuid4()))
                (source / wrong).write_bytes(b"native-fragment-1"); row["file"] = wrong
            elif defect == "bad-hash":
                row["sha256"] = "0"*64
            elif defect == "unsafe-file":
                row["file"] = "../outside.m4s"
            else:
                row["durationMs"] = -1
            Archive.atomic(source / "latest-video.json", value)
            try:
                owner.poll()
            except ValueError:
                pass
            else:
                raise AssertionError("accepted " + defect)
            check(not list(owner.root.rglob("*.m4s")), "invalid manifest admitted video bytes")
    for defect in ('manifest', 'asset', 'provenance'):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);owner=module.Archive(root,'study',min_free_bytes=0);owner.initialize()
            source,value,_=fixture(root);publish(source,value,[1],'ended');owner.poll()
            if defect == 'asset':
                path=next(owner.root.rglob('*.m4s'));path.write_bytes(b'corrupted')
            else:
                pattern='*/manifests/*.json' if defect=='manifest' else 'provenance/*.json'
                path=next((owner.root/'0001').glob(pattern));changed=json.loads(path.read_text())
                changed['unrecordedEdit']=True;path.write_bytes(Archive.encoded(changed))
            try:module.Archive(root,'study',min_free_bytes=0).initialize()
            except ValueError as error:check('hash differs' in str(error),'restored corruption failed elsewhere')
            else:raise AssertionError('restored '+defect+' corruption admitted')
    with tempfile.TemporaryDirectory() as directory:
        owner = module.Archive(Path(directory), "study", max_bytes=1, min_free_bytes=0).start()
        source, value, _ = fixture(Path(directory)); publish(source, value, [1])
        deadline = time.monotonic() + 2
        while owner.error is None and time.monotonic() < deadline:
            time.sleep(.02)
        owner.close()
        state = json.loads((owner.root / "archive.json").read_text())
        check(state["status"] == "failed" and "storage limit" in state["error"]["reason"],
              "disk bound did not visibly stop archival")
        check((source / value["segments"][0]["file"]).exists(), "archive failure changed producer")
    rolling_lifecycle(module)


def rolling_lifecycle(module=Archive, retention_timeout=5):
    # The fixture owns publication/retirement. Actual worker scheduling is not
    # an acknowledgment: retire bytes only after durable owner evidence exists.
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        owner = module.Archive(root, "study", min_free_bytes=0, interval=.01).start()
        try:
            source, value, _ = fixture(root)
            for seq in range(1, 13):
                publish(source, value, list(range(max(1, seq-2), seq+1)))
                deadline = time.monotonic() + retention_timeout
                destination = owner.root / "0001" / value["streamId"]
                state_path = destination / "stream.json"
                asset = destination / value["segments"][-1]["file"]
                while True:
                    if owner.error is not None:
                        raise AssertionError("rolling worker failed: " + str(owner.error))
                    if owner.thread is None or not owner.thread.is_alive():
                        raise AssertionError("rolling archive worker is not running")
                    if state_path.exists() and asset.exists():
                        _, state = module.read(state_path)
                        if state["retainedSegments"] == seq and state["lastSegment"]["sequence"] == seq:
                            data = module.sharing_read(asset.read_bytes)
                            check(data == ("native-fragment-" + str(seq)).encode()
                                  and module.sha(data) == value["segments"][-1]["sha256"],
                                  "rolling retained bytes do not match producer")
                            break
                    if time.monotonic() >= deadline:
                        raise AssertionError("rolling segment lacks durable retention acknowledgment: " + str(seq))
                    owner.stop_event.wait(.005)
                for path in source.glob("*.m4s"):
                    if int(path.stem.rsplit("-", 1)[1]) < seq-2:
                        path.unlink()
            publish(source, value, [10, 11, 12], "ended")
            owner.close()
            check(report(owner, value)["retainedSegments"] == 12,
                  "thread lifecycle lost acknowledged rolling segments")
            check(not owner.thread.is_alive() and owner.lock is None,
                  "thread lifecycle leaked worker or ownership lock")
            check(json.loads((owner.root / "archive.json").read_text())["status"] == "stopped",
                  "archive close lacks terminal receipt")
        finally:
            owner.close()


def host_checks(module=Session):
    for mode in ("fresh", "attachment", "saved"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); out = root / "session"
            args = types.SimpleNamespace(package=root/'package', out=out, game=root/'game', jdk=root/'jdk',
                watcher=root/'watcher', registry=root/'registry', profile=None, label='Archive', duration=30,
                auto_continue=False, attach_running_session='attached' if mode == 'attachment' else None)
            state = module.new_state('Archive',30,False)
            running = {'sessionId':str(uuid.uuid4()),'launchNumber':1,'status':'running'}
            if mode != 'fresh':
                if mode == 'saved':
                    state.update(status='saved',attempt=1,canContinue=True)
                module.atomic(out/'study-session.json',state);module.atomic(out/'native-run/run.json',running)
            events=[]
            archive=types.SimpleNamespace(close=lambda:events.append('archive-close'))
            owner=types.SimpleNamespace(args=['owner'], returncode=0, poll=lambda:0)
            def spawn(*unused):
                check(events == ['archive-start'], 'archive did not start before native preparation')
                events.append('native-start'); return owner
            def start(*unused,**kwargs):
                events.append('archive-start');return archive
            def waiting(*unused,**kwargs):
                raise KeyboardInterrupt('bounded host fixture')
            def watcher(*unused):
                check(events[0] == 'archive-start','archive did not precede saved/attached feed')
                raise KeyboardInterrupt('bounded host fixture')
            with patch.object(module.VideoArchive,'start',side_effect=start), \
                 patch.object(module.subprocess,'Popen',side_effect=spawn), \
                 patch.object(module,'runner_command',return_value=['owner']), \
                 patch.object(module,'wait_for_run',side_effect=waiting), \
                 patch.object(module,'attach_running',return_value=(owner,running)), \
                 patch.object(module,'start_watcher',side_effect=watcher),patch.object(module,'stop_process'):
                try:module.supervise(args)
                except KeyboardInterrupt:pass
            check(events[-1] == 'archive-close','archive did not close after host exit')
            check(events.count('archive-start') == 1,'archive ownership was duplicated')


def contention_cases(module=Archive):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        path = root / 'source.json'
        path.write_bytes(b'{"source":"native"}')
        original_read, original_stat = Path.read_bytes, Path.stat
        for operation in ('stat', 'read_bytes'):
            calls = [0]
            original = original_stat if operation == 'stat' else original_read
            def denied(candidate, *args, **kwargs):
                if candidate == path:
                    calls[0] += 1
                    if calls[0] <= 3:
                        raise PermissionError(13, 'transient sharing denial', str(candidate))
                return original(candidate, *args, **kwargs)
            with patch.object(Path, operation, denied):
                try:
                    raw, value = module.read(path)
                except PermissionError as error:
                    raise AssertionError('transient sharing denial killed collection') from error
            check(value == {'source':'native'} and raw == path.read_bytes() and calls[0] >= 4,
                  'transient sharing retry changed admitted metadata')
        path.write_bytes(b'invalid-json')
        with patch.object(Path, 'read_bytes', autospec=True, side_effect=original_read) as reads:
            try: module.read(path)
            except json.JSONDecodeError: pass
            else: raise AssertionError('malformed metadata was hidden')
            check(reads.call_count == 1, 'invalid metadata was retried as contention')

        if sys.platform == 'win32':
            # Actual Windows sharing violation on an owned fixture, not a
            # synthetic exception and never a live game file.
            import ctypes
            from ctypes import wintypes
            kernel = ctypes.WinDLL('kernel32', use_last_error=True)
            kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
            kernel.CreateFileW.restype = wintypes.HANDLE
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            path.write_bytes(b'{"source":"native"}')
            handle = kernel.CreateFileW(str(path), 0x80000000, 0, None, 3, 0x80, None)
            check(handle not in (None, ctypes.c_void_p(-1).value), 'Windows lock fixture admission failed')
            released = threading.Event()
            def release():
                kernel.CloseHandle(handle); released.set()
            timer = None
            try:
                try: path.read_bytes()
                except PermissionError: pass
                else: raise AssertionError('Windows fixture did not deny shared access')
                timer = threading.Timer(.05, release); timer.start()
                try: _, value = module.read(path)
                except PermissionError as error:
                    raise AssertionError('transient sharing denial killed collection') from error
                check(value['source'] == 'native', 'Windows sharing recovery changed source')
            finally:
                if timer: timer.join()
                if not released.is_set(): release()

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        owner = module.Archive(root, 'study', min_free_bytes=0)
        owner.acquire(); owner.initialize()
        source, value, _ = fixture(root); publish(source, value, [1]); owner.poll()
        retained = owner.root / '0001' / value['streamId'] / value['segments'][0]['file']
        first_bytes = retained.read_bytes()
        manifest = source / 'latest-video.json'
        calls = [0]
        def persistent(candidate):
            if candidate == manifest:
                calls[0] += 1
                raise PermissionError(13, 'persistent source access denied', str(candidate))
            return original_read(candidate)
        with patch.object(Path, 'read_bytes', persistent):
            try: owner.poll()
            except PermissionError as error: owner.fail(error)
            except BaseException:
                owner.close(); raise
            else:
                owner.close(); raise AssertionError('persistent access failure was hidden')
        owner.close()
        state = json.loads((owner.root / 'archive.json').read_text())
        check(calls[0] == module.READ_ATTEMPTS and state['status'] == 'failed'
              and state['error']['type'] == 'PermissionError', 'persistent denial did not fail within bound')
        check(report(owner, value)['coverage'] == 'partial' and not report(owner, value)['tailConfirmed'],
              'failed collector claimed active coverage')
        failed_bytes = (owner.root / 'archive.json').read_bytes()
        # The producer has retired media while collection was unavailable.
        (source / value['segments'][0]['file']).unlink()
        publish(source, value, [4], 'ended')
        restarted = module.Archive(root, 'study', min_free_bytes=0)
        restarted.acquire()
        try:
            restarted.initialize(); restarted.poll()
            failure_path = restarted.root / 'failures' / (module.sha(failed_bytes) + '.json')
            check(failure_path.exists() and failure_path.read_bytes() == failed_bytes,
                  'restart discarded original collector failure')
            state = json.loads((restarted.root / 'archive.json').read_text())
            check(state['priorFailureCount'] == 1 and state['priorFailures'][0]['sha256'] == module.sha(failed_bytes),
                  'restart lost failure provenance')
            state = report(restarted, value)
            check(state['coverage'] == 'partial' and state['missingSequences'] == [{'first':2,'last':3}]
                  and state['retainedSegments'] == 2, 'restart concealed interruption gap')
            check(retained.read_bytes() == first_bytes, 'restart changed previously retained video')
            failure_path.write_bytes(b'{"status":"failed"}')
        finally:
            restarted.close()
        try: module.Archive(root, 'study', min_free_bytes=0).initialize()
        except ValueError as error: check('failure provenance' in str(error), 'failure tampering failed elsewhere')
        else: raise AssertionError('retained failure tampering admitted')


def retired_publish(source, value, sequences, state="running", closed=False):
    """Controlled raw-byte protocol fixture, never native/encoded-media proof."""
    publish(source,value,sequences,state)
    for row in value["segments"]:row.update(observerSequence=0,sites=[],crops=[])
    value["stats"].update(capturedFrames=max(sequences,default=0)*10,encodedFrames=max(sequences,default=0)*10)
    name=(f"video-{value['streamId']}-closed.json" if closed else
          f"video-{value['streamId']}-tail-{max(sequences,default=1):016d}.json")
    Archive.atomic(source/name,value);(source/"latest-video.json").unlink()
    return source/name


def participant_retired_cases(module=Archive):
    with tempfile.TemporaryDirectory(prefix="participant-retired-protocol-") as directory:
        root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
        owner.initialize();source,value,session=fixture(root,run_name="participant-run")
        for start in (1,5,9):retired_publish(source,value,list(range(start,start+4)))
        retired_publish(source,value,[9,10,11,12],"ended",True)
        receipt=json.loads((root/"participant-run/run.json").read_text());receipt.update(status="completed")
        Archive.atomic(root/"participant-run/run.json",receipt)
        before={p.name:Archive.sha(p.read_bytes()) for p in source.iterdir() if p.is_file()}
        owner.poll();retained=owner.root/"0001"/value["streamId"]
        check((retained/"stream.json").is_file(),"participant retirement stream unavailable")
        state=report(owner,value)
        check(state["retainedSegments"]==12,"participant retirement lost more than8 total rows")
        check(state["coverage"]=="complete-published-segments" and state["tailConfirmed"],"closed participant retirement was not complete")
        check(state["missingSequences"]==[] and state["ptsGaps"]==[] and not state["lateAttachment"],"participant retirement hid opening or gaps")
        check(state["firstSegment"]["sequence"]==1 and state["lastSegment"]["sequence"]==12,"participant retirement reordered endpoints")
        check(state["manifestCount"]==4,"participant retirement lost immutable bounded manifests")
        check(state["nativeProvenance"]["sessionId"]==session,"participant retirement changed native owner")
        check(before=={p.name:Archive.sha(p.read_bytes()) for p in source.iterdir() if p.is_file()},"retired discovery mutated producer source")
        for seq in range(1,13):
            p=retained/f"video-{value['streamId']}-{seq:016d}.m4s"
            check(p.read_bytes()==("native-fragment-"+str(seq)).encode(),"participant retired source bytes changed")
        def immutable():
            return {str(p.relative_to(retained)):Archive.sha(p.read_bytes()) for p in retained.rglob("*")
                    if p.is_file() and (p.suffix in (".m4s",".mp4") or p.parent.name=="manifests")}
        retained_before=immutable()
        # Retire only owned synthetic producer files after acknowledged retention.
        for p in list(source.iterdir()):
            if p.is_file():p.unlink()
        owner.finished=True;owner.publish()
        restarted=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
        restarted.initialize();restarted.poll()
        check(report(restarted,value)["retainedSegments"]==12,"participant restart lost existing retired rows")
        check(report(restarted,value)["coverage"]=="complete-published-segments","participant restart changed terminal coverage")
        check(retained_before==immutable(),"participant restart changed immutable bytes")

    for defect in ("foreign-tail-name","wrong-tail-sequence","short-tail-sequence","ended-tail",
                   "running-closed","empty-tail","oversized-tail","malformed-json","foreign-closed-name"):
        with tempfile.TemporaryDirectory(prefix="participant-retired-refusal-") as directory:
            root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
            owner.initialize();source,value,_=fixture(root,run_name="participant-run")
            rows=list(range(1,10)) if defect=="oversized-tail" else [] if defect=="empty-tail" else [1]
            closed=defect in ("running-closed","foreign-closed-name")
            state="running" if defect=="running-closed" else "ended" if defect in ("ended-tail","foreign-closed-name") else "running"
            p=retired_publish(source,value,rows,state,closed)
            if defect=="foreign-tail-name":p=p.rename(source/f"video-{uuid.uuid4()}-tail-0000000000000001.json")
            elif defect=="wrong-tail-sequence":p=p.rename(source/f"video-{value['streamId']}-tail-0000000000000002.json")
            elif defect=="short-tail-sequence":p=p.rename(source/f"video-{value['streamId']}-tail-1.json")
            elif defect=="foreign-closed-name":p=p.rename(source/f"video-{uuid.uuid4()}-closed.json")
            elif defect=="malformed-json":p.write_bytes(b"{controlled-malformed-json")
            try:owner.poll()
            except ValueError:pass
            else:raise AssertionError("participant retired malformed admission: "+defect)
            check(not list(owner.root.rglob("*.m4s")),"malformed retired manifest admitted bytes")

    for closed in (False,True):
        with tempfile.TemporaryDirectory(prefix="participant-retired-missing-") as directory:
            root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
            owner.initialize();source,value,_=fixture(root,run_name="participant-run")
            retired_publish(source,value,[1],"ended" if closed else "running",closed)
            (source/value["segments"][0]["file"]).unlink()
            try:owner.poll()
            except FileNotFoundError:pass
            else:raise AssertionError("missing retired asset was silently skipped")
            check(not list(owner.root.rglob("*.m4s")),"missing retired asset received false bytes")

    with tempfile.TemporaryDirectory(prefix="participant-restore-missing-") as directory:
        root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
        owner.initialize();source,value,_=fixture(root,run_name="participant-run")
        retired_publish(source,value,[1],"ended",True);owner.poll()
        retained=owner.root/"0001"/value["streamId"]/value["segments"][0]["file"];retained.unlink()
        try:module.Archive(root,"study",min_free_bytes=0,run_name="participant-run").initialize()
        except ValueError as error:check("missing video bytes" in str(error),"missing retained asset failed elsewhere")
        else:raise AssertionError("participant restart salvaged missing immutable media")

    with tempfile.TemporaryDirectory(prefix="participant-retired-failed-") as directory:
        root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0,run_name="participant-run")
        owner.initialize();source,value,_=fixture(root,run_name="participant-run")
        retired_publish(source,value,[1],"failed",True);owner.poll()
        check(report(owner,value)["coverage"]=="partial","failed retired epoch claimed complete")

    with tempfile.TemporaryDirectory(prefix="observer-retired-boundary-") as directory:
        root=Path(directory);owner=module.Archive(root,"study",min_free_bytes=0)
        owner.initialize();source,value,_=fixture(root);publish(source,value,[1])
        retired=[source/f"video-{value['streamId']}-tail-0000000000000002.json",source/f"video-{value['streamId']}-closed.json"]
        for p in retired:p.write_bytes(b"{intentionally-invalid-participant-retirement")
        try:owner.poll()
        except ValueError as error:raise AssertionError("observer discovered participant retired metadata") from error
        check(report(owner,value)["retainedSegments"]==1 and report(owner,value)["manifestCount"]==1,"observer default admitted participant retirement")
        check(all(p.read_bytes()==b"{intentionally-invalid-participant-retirement" for p in retired),"observer default changed ignored files")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    paths = [Path(__file__), Path(Archive.__file__), Path(Session.__file__)]
    pins = {str(p.resolve()): Archive.sha(p.read_bytes()) for p in paths}
    cases();host_checks();contention_cases()
    original_baseline = CHECKS
    participant_retired_cases()
    participant_checks = CHECKS-original_baseline
    baseline = CHECKS
    source = Path(Archive.__file__).read_text()
    controls = [
        ('missing-middle', 'missing = gaps(rows)', 'missing = []', 'missing middle'),
        ('wrong-stream', 'if row["file"] != f"video-{stream}-{seq:016d}.m4s":', 'if False:', 'accepted wrong-stream'),
        ('wrong-hash', 'if not data or sha(data) != row["sha256"]:', 'if not data:', 'accepted bad-hash'),
        ('late-attachment', 'lateAttachment=bool(state["initialSequence"] and state["initialSequence"] > 1)',
         'lateAttachment=False', 'late attachment'),
        ('duplicate-owner', '            self.acquire()', '            pass', 'duplicate recorder'),
        ('empty-terminal', '"unavailable" if not rows and (terminal or collector_stopped or run_terminal) else ',
         '', 'empty terminal')]
    for label,before,after,marker in controls:
        check(source.count(before)==1,'control target differs: '+label)
        altered=types.ModuleType(label);altered.__file__=Archive.__file__
        exec(compile(source.replace(before,after),'<archive-control>','exec'),altered.__dict__)
        try:cases(altered)
        except AssertionError as error:check(marker in str(error),'control failed elsewhere: '+str(error))
        else:raise AssertionError('archive defect survived: '+label)
    session_source=Path(Session.__file__).read_text()
    target='    archive = VideoArchive.start(args.out, state["id"],'
    # A collector created but never started misses all early rolling segments.
    altered=types.ModuleType('host_no_start');altered.__file__=Session.__file__
    check(session_source.count(target)==1,'host control target differs')
    exec(compile(session_source.replace(target,'    archive = VideoArchive.Archive(args.out, state["id"],'),
                 '<host-control>','exec'),altered.__dict__)
    try:host_checks(altered)
    except (AssertionError, IndexError) as error:check('archive' in str(error) or isinstance(error,IndexError),'host control failed elsewhere')
    else:raise AssertionError('host autostart defect survived')
    contention_controls = [
        ('transient-read', '            time.sleep(READ_RETRY_SECONDS)', '            raise',
         'transient sharing denial killed collection'),
        ('persistent-read', '            if attempt == READ_ATTEMPTS - 1:\n                raise',
         '            if attempt == READ_ATTEMPTS - 1:\n                return b"{}"', 'persistent'),
        ('failed-coverage', 'collector_stopped = self.finished or self.error is not None',
         'collector_stopped = self.finished', 'failed collector claimed'),
        ('failure-retention', '        if old.get("status") == "failed":', '        if False:',
         'restart discarded original collector failure')]
    for label,before,after,marker in contention_controls:
        check(source.count(before)==1,'control target differs: '+label)
        altered=types.ModuleType(label);altered.__file__=Archive.__file__
        exec(compile(source.replace(before,after),'<contention-control>','exec'),altered.__dict__)
        try:contention_cases(altered)
        except (AssertionError, ValueError) as error:
            if label == 'persistent-read' and isinstance(error, ValueError):
                check('unknown native video schema' in str(error), 'persistent control failed elsewhere')
            else: check(marker in str(error),'control failed elsewhere: '+str(error))
        else:raise AssertionError('contention defect survived: '+label)
    # These faults exercise the actual lifecycle fixture, not a guessed sleep.
    lifecycle_controls = [
        ('missing-worker', 'target=self.run, name="study-video-archive"',
         'target=lambda: None, name="study-video-archive"', 'worker is not running'),
        ('missing-retention', '            self.store(target, data)',
         '            pass', 'durable retention acknowledgment')]
    for label,before,after,marker in lifecycle_controls:
        check(source.count(before)==1,'control target differs: '+label)
        altered=types.ModuleType(label);altered.__file__=Archive.__file__
        exec(compile(source.replace(before,after),'<lifecycle-control>','exec'),altered.__dict__)
        try:rolling_lifecycle(altered,retention_timeout=.2)
        except AssertionError as error:check(marker in str(error),'control failed elsewhere: '+str(error))
        else:raise AssertionError('lifecycle defect survived: '+label)
    participant_controls = [
        ('missing-participant-discovery','if self.run_name == "participant-run" else []',
         'if False else []','participant retirement stream unavailable'),
        ('retired-name-admission','if not (closed or tail):','if False:',
         'participant retired malformed admission'),
        ('observer-discovery-boundary','if self.run_name == "participant-run" else []',
         'if True else []','observer discovered participant retired metadata'),
        ('missing-retired-refusal','                    if current != manifest:\n                        raise',
         '                    if False:\n                        raise','missing retired asset was silently skipped')]
    for label,before,after,marker in participant_controls:
        check(source.count(before)==1,'control target differs: '+label)
        altered=types.ModuleType(label);altered.__file__=Archive.__file__
        exec(compile(source.replace(before,after),'<participant-retirement-control>','exec'),altered.__dict__)
        try:participant_retired_cases(altered)
        except AssertionError as error:check(marker in str(error),'control failed elsewhere: '+str(error))
        else:raise AssertionError('participant retirement defect survived: '+label)
    after = {str(p.resolve()): Archive.sha(p.read_bytes()) for p in paths}
    check(pins==after,'proof inputs changed')
    receipt={'schema':'sao.native-video-archive-proof/1','status':'PASS','baselineChecks':baseline,
             'originalBaselineChecks':original_baseline,'participantRetiredChecks':participant_checks,
             'defectControls':7+len(contention_controls)+len(lifecycle_controls)+len(participant_controls),
             'participantDefectControls':len(participant_controls),'inputs':pins,
             'changedInputs':[str(Path(__file__).resolve()),str(Path(Archive.__file__).resolve())],
             'scope':'Controlled raw-byte protocol fixtures and collector/restore/Windows-sharing code; no native game or encoded-media acceptance',
             'sharingRetry':{'attempts':Archive.READ_ATTEMPTS,'delaySeconds':Archive.READ_RETRY_SECONDS,
                             'realWindowsSharingViolation':sys.platform=='win32'}}
    if args.out:
        Archive.atomic(args.out/'receipt.json',receipt)
    print(json.dumps(receipt,indent=2))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print('FAIL native video archive: '+str(error),file=sys.stderr)
        raise SystemExit(1)
