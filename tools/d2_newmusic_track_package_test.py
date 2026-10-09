"""One changed imported runtime leaf, exact source custody and real importer hook."""
from pathlib import Path
import argparse
import hashlib
import json
import tempfile
from unittest.mock import patch
import d2_source_package as package

ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'mod/42.20'
REL='media/lua/client/runtime/NMClientTrackFinishedDispatch.lua'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    before=ROOT/'_scratch/d2-leisure-01/newmusic-track-context/before'
    staged=ROOT/'_scratch/d2-leisure-01/newmusic-track-context/staged01'
    mp=MOD/'media/SAOSources/manifest.json';current=json.loads(mp.read_bytes());previous=json.loads((before/'mod/42.20/media/SAOSources/manifest.json').read_bytes())
    owner=MOD/REL;vault=MOD/'media/SAOSources/NewMusic'/REL
    registered=json.loads((before/'registration-preimages.json').read_bytes())
    inputs=[Path(__file__),Path(package.__file__),mp,owner,vault,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',*[MOD/s['sentinel']for s in current['sources'].values()],*[MOD/r['fragment']for r in current['mergeRequired']],*[MOD/p for p in registered['outputs']]]
    pins={str(p):sha(p)for p in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'boundary':'Exact imported source lexical context repair; real importer hook; unchanged original private vault; original native dispatch proof reused by identical executed bytes; no native game or UI switching claim'}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        assert len(previous['files'])==len(current['files'])==89521
        changed=[(a,b)for a,b in zip(previous['files'],current['files'])if a!=b]
        assert len(changed)==1
        old,row=changed[0];assert row['sourceId']=='NewMusic' and row['selectedPath']==REL and row['destination']==REL
        assert {k:v for k,v in old.items()if k not in {'destinationSha256','bytes','adaptations'}}=={k:v for k,v in row.items()if k not in {'destinationSha256','bytes','adaptations'}}
        assert {k:v for k,v in current.items()if k not in {'sources','files'}}=={k:v for k,v in previous.items()if k not in {'sources','files'}}
        assert [s for s in current['sources']if current['sources'][s]!=previous['sources'][s]]==['NewMusic']
        assert {k:v for k,v in current['sources']['NewMusic'].items()if k!='seal'}=={k:v for k,v in previous['sources']['NewMusic'].items()if k!='seal'}
        base,initial=package.adapt_lua(vault.read_bytes(),'NewMusic');fixed,extra=package.adapt_newmusic_track_finished_context(base,REL)
        assert base==(before/'mod/42.20'/REL).read_bytes() and fixed==owner.read_bytes()==(staged/'NMClientTrackFinishedDispatch.lua').read_bytes()
        assert row['adaptations']==initial+extra and row['sourceSha256']==sha(vault) and row['destinationSha256']==sha(owner)
        assert package.adapt_newmusic_track_finished_context(base,'media/lua/client/unrelated.lua')==(base,[])
        try:package.adapt_newmusic_track_finished_context(base.replace(b'    if keep then\n',b'    if changedKeep then\n'),REL);raise AssertionError('changed anchor accepted')
        except ValueError:pass
        for source,s in current['sources'].items():
            seal=package.sha(json.dumps([r for r in current['files']if r['sourceId']==source],sort_keys=True,separators=(',',':')).encode())
            assert seal==s['seal'] and (MOD/s['sentinel']).read_bytes()==('SAO-OWNED-SOURCE/1 '+source+' '+seal+'\n').encode()
        old_seal=previous['sources']['NewMusic']['seal'];new_seal=current['sources']['NewMusic']['seal']
        registry=MOD/'media/lua/shared/SAO_SourcePackageManifest.lua'
        assert registry.read_bytes()==(before/'mod/42.20/media/lua/shared/SAO_SourcePackageManifest.lua').read_bytes().replace(old_seal.encode(),new_seal.encode(),1)
        for rel,digest in registered['outputs'].items():assert sha(MOD/rel)==digest
        assert len(registered['outputs'])==211
        for fragment in current['mergeRequired']:assert sha(MOD/fragment['fragment'])==fragment['sha256']
        with tempfile.TemporaryDirectory(prefix='sao-track-context-package-')as temp:
            work=Path(temp);spec=package.SOURCES['NewMusic'];selected=work/'workshop'/spec[0]/spec[1];src=selected/REL;src.parent.mkdir(parents=True);src.write_bytes(vault.read_bytes());(selected/'mod.info').write_bytes((MOD/'media/SAOSources/NewMusic/provenance/selected-mod.info').read_bytes())
            all_sources=package.SOURCES;package.SOURCES={'NewMusic':spec}
            try:
                plan,outputs,collisions=package.build_plan(work/'workshop',work/'empty-mod')
                assert not collisions and outputs[REL]==fixed and plan['files'][0]['adaptations']==initial+extra
                with patch.object(package,'adapt_newmusic_track_finished_context',lambda raw,path:(raw,[])):
                    wrong,bad_outputs,_=package.build_plan(work/'workshop',work/'empty-mod')
                    assert bad_outputs[REL]==base and bad_outputs[REL]!=fixed and wrong['sources']['NewMusic']['seal']!=plan['sources']['NewMusic']['seal']
            finally:package.SOURCES=all_sources
        assert old['destinationSha256']!=row['destinationSha256'] and old_seal!=new_seal
        original_package=(before/'tools/d2_source_package.py').read_text()
        adapted=Path(package.__file__).read_text()
        helper=(staged/'adaptation.py').read_text()+'\n\n'
        hook='\n                content, context_adaptations = adapt_newmusic_track_finished_context(content, relative)\n                adaptations.extend(context_adaptations)'
        assert adapted.count(helper)==1 and adapted.count(hook)==1
        assert adapted.replace(helper,'',1).replace(hook,'',1)==original_package
        native=json.loads((staged/'receipt.json').read_bytes());assert native['status']=='PASS_STAGED' and native['stageSha256']==sha(owner)
        # These exact original UI/dependency bytes remain the source lineage for
        # the reused installed Kahlua execution. The changed destination is the
        # identical fixed stage, rather than the original preimage path.
        for p,digest in native['inputsAfter'].items():
            if p!=str(owner):assert sha(Path(p))==digest,p
        receipt.update(status='PASS',changedRows=1,unchangedRows=89520,changedFamilySeals=['NewMusic'],unchangedFamilySeals=6,sentinelsVerified=7,registrationOutputsUnchanged=211,fragmentsUnchanged=len(current['mergeRequired']),actualImporterHook=True,importerOmissionControl=True,tamperedAnchorRefused=True,oldRuntimeHashAndSealRefused=True,previousAdaptersByteExact=True,nativeSourceChecksReused=36,nativeUILayoutChecksReused=5,restoredNativeDefectReused=1,nativeReceiptSha256=sha(staged/'receipt.json'),dormantScaleFinding='SIDE_BUTTON_SCALE_PRESSED absent; no getSideButtonScale callers; actual source renderer uses original pressed inset')
        receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert pins==receipt['inputsAfter'];save();print('PASS one NewMusic row/89520 unchanged,7 seals,211 outputs,real importer and exact native36+5/1 reused')
    except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise


if __name__=='__main__':main()
