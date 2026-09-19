import contextlib, copy, hashlib, importlib.util, io, json, pathlib, re, subprocess
from unittest.mock import patch
R=pathlib.Path.cwd(); m=json.loads((R/'Batches/C_RECATALOG.json').read_text())
def verify(doc):
    assert [u['batch'] for u in doc['units']]==[f'C{i}' for i in range(1,51)], 'current sequence'
    sources=[s for u in doc['units'] for s in u['sources']]
    assert [s['former'] for s in sources]==[f'C{i}' for i in range(1,128)], 'former coverage'
    for u in doc['units']:
        assert [s['former'] for s in u['sources']]==[f'C{i}' for i in range(u['start'],u['end']+1)], 'adjacency'
        text=(R/u['path']).read_text(encoding='utf-8')
        assert u['title'] in text and u['summary'] in text, 'record substance'
        assert u['date'] in pathlib.Path(u['path']).name, 'date'
    return sources
sources=verify(m)
bad=copy.deepcopy(m);bad['units'][0]['sources'].pop()
try: verify(bad)
except AssertionError as e: assert str(e)=='former coverage'
else: raise AssertionError('missing-entry control was not caught')
bad=copy.deepcopy(m);bad['units'][1]['sources'][0]=copy.deepcopy(bad['units'][0]['sources'][0])
try: verify(bad)
except AssertionError as e: assert str(e)=='former coverage'
else: raise AssertionError('duplicate-entry control was not caught')
for s in sources:
    blob=subprocess.check_output(['git','show',m['published_source_commit']+':'+s['path']])
    assert hashlib.sha256(blob).hexdigest()==s['sha256'],s['path']
spec=importlib.util.spec_from_file_location('maps',R/'tools/map_reference_test.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
with contextlib.redirect_stdout(io.StringIO()): assert mod.main()==0
original=pathlib.Path.read_text;log=R/'BATCH_LOG.md';text=original(log,encoding='utf-8')
line=next(line for line in text.splitlines() if line.startswith('| [C50]'))
mutated=text.replace(line,line.replace('| 2026-09-18 |','| 2026-09-17 |'))
assert mutated!=text
def read(path,*args,**kwargs):return mutated if path==log else original(path,*args,**kwargs)
out=io.StringIO()
with patch.object(pathlib.Path,'read_text',read),contextlib.redirect_stdout(out): verdict=mod.main()
assert verdict==1 and 'BATCH_LOG.md dates C50 2026-09-17' in out.getvalue(),out.getvalue()
assert not subprocess.check_output(['git','diff','--cached','--name-only','--','mod/42.20/media/lua','java/src']).strip(), 'runtime source changed'
print(json.dumps({'current_units':50,'former_entries':127,'exact_archive_hashes':127,'missing_control':'rejected','duplicate_control':'rejected','map_border':'passed','C50_date_control':'rejected with C50 date finding','runtime_source_changes':0},indent=2))
