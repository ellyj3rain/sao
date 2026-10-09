#!/usr/bin/env python3
"""Bounded projection controls. Byte fixtures are labelled synthetic, not H264."""
import copy
import json
from pathlib import Path
import tempfile
import uuid
from unittest.mock import patch
import world_lab_video_archive as A
import world_lab_video_archive_test as F

checks = []
def check(name, condition):
    checks.append({'name': name, 'passed': bool(condition)})
    assert condition, name
def refused(name, action):
    try: action()
    except (ValueError, OSError): check(name, True)
    else: check(name, False)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory); study = str(uuid.uuid4())
    owner = A.Archive(root, study, min_free_bytes=0); owner.initialize()
    source, value, session = F.fixture(root)
    receipt = json.loads((root/'native-run/run.json').read_text())
    receipt.update(packageSha256='a'*64, definitionSha256='b'*64)
    A.atomic(root/'native-run/run.json', receipt)
    value.update(mimeType='video/mp4', codecs='avc1.640033', width=2560, height=720, fps=120, message='Synthetic projection bytes')
    for number in range(1, 4):
        F.publish(source, value, list(range((number-1)*8+1, number*8+1)), 'ended' if number == 3 else 'running')
        value['stats'] = {'capturedFrames':number*80, 'encodedFrames':number*80, 'droppedFrames':0}
        A.atomic(source/'latest-video.json',value);owner.poll()
    receipt['status']='completed';A.atomic(root/'native-run/run.json',receipt);owner.poll()
    feed=root/'feeds/0001';feed.mkdir(parents=True)
    view={'schema':'mousecat.native-view/1','state':'ended','sessionId':session,
          'study':{'id':study,'attempt':1},'video':{**value,'schema':'mousecat.native-video/1'}}
    A.atomic(feed/'latest.json',view)
    before={str(p.relative_to(root)):A.sha(p.read_bytes()) for p in (root/'video-archive').rglob('*') if p.is_file()}
    original=A.sha((feed/'latest.json').read_bytes())
    result=A.project_archive(root,feed);index=json.loads((feed/'archive-index.json').read_text())
    check('three eight-descriptor pages retain all24 synthetic fragments',result['segmentCount']==24 and result['pageCount']==3)
    payload={k:v for k,v in index.items() if k!='generation'}
    check('canonical generation uses exact float64 bits excluding generation',index['generation']==A.projection_generation(payload) and index['generationAlgorithm']=='sha256-json-f64be/1')
    check('integer and float same source value have same generation',A.projection_generation({'n':1})==A.projection_generation({'n':1.0}))
    check('negative zero wire normalization has same generation',A.projection_generation({'n':-0.0})==A.projection_generation({'n':0.0}))
    check('small fractional source numbers preserve distinct exact generation',A.projection_generation({'n':1e-6})!=A.projection_generation({'n':1e-7}))
    check('integer floats normalize for Javascript',A.canonical_projection({'n':1.0})==b'{"n":1}')
    check('Javascript small fractional exponent threshold matches',A.canonical_projection({'a':.000001,'b':.00001,'c':1e-7})==b'{"a":0.000001,"b":0.00001,"c":1e-7}')
    for descriptor in index['pages']:
        raw,page=A.read(feed/descriptor['file']);check('immutable page hash '+str(descriptor['firstSequence']),A.sha(raw)==descriptor['sha256'])
        check('page source digests and exact original descriptors '+str(descriptor['firstSequence']),len(page['sourceManifestDigests'])<=8 and page['video']['segments']==[owner.streams['0001/'+value['streamId']]['segments'][n] for n in range(descriptor['firstSequence'],descriptor['lastSequence']+1)])
    check('original source/latest/archive bytes unchanged',A.sha((feed/'latest.json').read_bytes())==original and before=={str(p.relative_to(root)):A.sha(p.read_bytes()) for p in (root/'video-archive').rglob('*') if p.is_file()})
    index_bytes=(feed/'archive-index.json').read_bytes()
    second=A.project_archive(root,feed)
    check('repeat export idempotent and adds no duplicate media',second['linkedMedia']==second['copiedMedia']==0 and (feed/'archive-index.json').read_bytes()==index_bytes)
    owner.publish();check('collector automatically projects ended registered feed', (feed/'archive-index.json').read_bytes()==index_bytes)
    changed=copy.deepcopy(view);changed['sessionId']=str(uuid.uuid4());A.atomic(feed/'latest.json',changed)
    refused('foreign native session refused',lambda:A.project_archive(root,feed));check('failed export retains prior index', (feed/'archive-index.json').read_bytes()==index_bytes)
    A.atomic(feed/'latest.json',view)
    first=index['pages'][0];p=feed/first['file'];p.write_bytes(b'corrupt')
    refused('changed immutable page refuses',lambda:A.project_archive(root,feed));check('page failure retains prior index', (feed/'archive-index.json').read_bytes()==index_bytes)
    refused('feed outside session refuses',lambda:A.project_archive(root,root/'elsewhere'))
    state=copy.deepcopy(owner.streams['0001/'+value['streamId']])
    state['segments'][2]['ptsStartMs']+=1.05
    gap=owner.stream_report('0001/'+value['streamId'],state)
    check('1.05ms published gap is partial rather than complete',gap['coverage']=='partial' and gap['ptsGaps'][0]=={'afterSequence':1,'beforeSequence':2})

print(json.dumps({'schema':'sao.native-video-archive-projection-proof/1','status':'PASS','fixture':'synthetic bytes; not decoded video','checks':checks},indent=2))
