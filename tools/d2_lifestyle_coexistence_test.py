"""Actual imported global + original private source callbacks; physical/emitter hosts controlled, native Kahlua/Stats."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
import d2_leisure_lifestyle_test as base
ROOT=base.ROOT;OWNER=base.OWNER;FIX=base.FIX;GAME=base.GAME;JDK=base.JDK;MOD=ROOT/'mod/42.20'
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);args=p.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 names=re.findall(r'\["([^\"]+\.lua)"\]=\{',OWNER.read_text());vault=MOD/'media/SAOSources/LifestyleHobbies/media/lua'
 selected_menu=base.LS/'client/JukeboxContextMenu.lua'
 assert base.sha(selected_menu)=='a488db5febe4ade1e5eadc0f5767952a96817faa8166044a58a417304608b46e','selected-original-jukebox-menu-drift'
 imported=[MOD/'media/lua/client/InteractionRange.lua',MOD/'media/lua/client/LSEffectsAux.lua'];cases=FIX/'coexistence-cases.lua'
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 originals=[base.LS/n for n in names]
 inputs=[Path(__file__),OWNER,cases,FIX/'external-original-cases.lua',FIX/'prelude.lua',base.BASE/'prelude.lua',base.BASE/'MusicProbe.java',*native,*jars,GAME/'stdlib.lua',selected_menu,*imported,*[vault/n for n in names],*originals]
 before={str(p):base.sha(p)for p in inputs};receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':before,'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 controls=[('range-filter',0,'if not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true) then','if true then','operator_far_cannot_silence_owned_source'),('ending-filter',1,'if not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true) and','if true and','global_cannot_advance_owned_track'),('token',2,'or a.body:getModData().SAOExternalToken~=core.bodyToken','or false','body_token_replacement_releases_lease'),('record',2,'core.record~=r','false','record_replacement_releases_lease'),('receipt',2,'return false\nend\nfunction L.physicalSourceOwner','return true\nend\nfunction L.physicalSourceOwner','canonical_source_receipt_required'),('external-authority',2,'or not stationPhysicalEnabled()or objectFor','or false or objectFor','external_activation_releases_private_station_lease')]
 try:
  with tempfile.TemporaryDirectory(prefix='sao-jukebox-coexist-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars));r=subprocess.run(list(map(str,[JDK/'javac.exe','-cp',cp,'-d',work,base.BASE/'MusicProbe.java'])),capture_output=True);(out/'compile.log').write_bytes(r.stdout+r.stderr);assert r.returncode==0
   for name,index,old,new,marker in [('baseline',None,None,None,None)]+controls:
    texts=[p.read_text()for p in imported]+[OWNER.read_text()]
    if index is not None:assert texts[index].count(old)==1,(name,texts[index].count(old));texts[index]=texts[index].replace(old,new,1)
    targets=[]
    for n,text in enumerate(texts):q=out/(name+'-'+str(n)+'.lua');q.write_text(text);targets.append(q)
    manifest=out/(name+'-sources.tsv');rows=[('LifestyleHobbies:'+n,vault/n)for n in names]+[('Owned:InteractionRange',targets[0]),('Owned:LSEffectsAux',targets[1])];manifest.write_text(''.join(k+'\t'+str(v)+'\n'for k,v in rows))
    cmd=[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,base.BASE/'prelude.lua',*native,vault/'shared/LSUtil.lua',FIX/'prelude.lua',targets[2],cases]
    r=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);text=log.read_text(errors='replace');receipt['runs'].append({'name':name,'exit':r.returncode,'logSha256':base.sha(log),'marker':marker});save()
    if marker:assert r.returncode!=0 and 'D2_COEXISTENCE:'+marker in text,(name,text[-5000:])
    else:assert r.returncode==0 and 'PASS D2 coexistence 'in text,text[-7000:];receipt['checks']=int(re.search(r'PASS D2 coexistence (\d+)',text)[1])
   original_manifest=out/'selected-original-sources.tsv'
   original_manifest.write_text(''.join('LifestyleHobbies:'+n+'\t'+str(base.LS/n)+'\n'for n in names)
    +'LifestyleHobbies:client/JukeboxContextMenu.lua\t'+str(selected_menu)+'\n')
   cmd=[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+cp,'MusicProbe',original_manifest,base.BASE/'prelude.lua',*native,base.LS/'shared/LSUtil.lua',FIX/'prelude.lua',OWNER,FIX/'external-original-cases.lua']
   r=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90)
   log=out/'selected-original.log';log.write_bytes(r.stdout+r.stderr)
   text=log.read_text(errors='replace')
   receipt['runs'].append({'name':'selected-original','exit':r.returncode,'logSha256':base.sha(log)})
   save()
   assert r.returncode==0 and 'PASS D2 external original ' in text,text[-7000:]
   receipt['externalOriginalChecks']=int(re.search(r'PASS D2 external original (\d+)',text)[1])
   external_controls=[
    ('external-live-menu-shape','if (name=="onPlay"or name=="onTurnOnOff")and type(menu[name])~="function"',
     'if type(menu[name])~="function"',
     'private_physical_offer_with_external'),
    ('external-range-guard','chunk(env,"client/InteractionRange.lua",guardRange)',
     'chunk(env,"client/InteractionRange.lua",function(code)return code end)',
     'far_operator_cannot_silence_private_station'),
    ('external-ending-guard','chunk(env,"client/LSEffectsAux.lua",guardEnding)',
     'chunk(env,"client/LSEffectsAux.lua",function(code)return code end)',
     'external_cannot_advance_private_ending'),
    ('external-player-handoff','if leased(object)then L.releasePhysicalStation(object,"operator-jukebox-control")end',
     'if false then L.releasePhysicalStation(object,"operator-jukebox-control")end',
     'operator_action_receives_released_station'),
    ('external-lifecycle-rewrap','  maintainExternalBridge()\n  for key,core in pairs(physicalOwners)do',
     '  if false then maintainExternalBridge()end\n  for key,core in pairs(physicalOwners)do',
     'lifecycle_rewrap_restores_claim'),
   ]
   for name,old,new,marker in external_controls:
    source=OWNER.read_text();assert source.count(old)==1,(name,source.count(old))
    variant=out/(name+'-owner.lua');variant.write_text(source.replace(old,new,1))
    cmd[-2]=variant
    r=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90)
    log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
    text=log.read_text(errors='replace')
    receipt['runs'].append({'name':name,'exit':r.returncode,'logSha256':base.sha(log),'marker':marker})
    save()
    assert r.returncode!=0 and 'D2_EXTERNAL_ORIGINAL:'+marker in text,(name,text[-5000:])
   receipt['externalInverses']=len(external_controls)
  receipt['inputsAfter']={str(p):base.sha(p)for p in inputs};assert receipt['inputsAfter']==before;receipt['status']='PASS';save();print('PASS',receipt['checks'],len(controls))
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':main()
