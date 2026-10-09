"""Complete source native Kahlua proof for the separately staged Lifestyle residuals."""
import argparse,hashlib,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];FIX=ROOT/'tools/d2_source_residual_lifestyle';STAGE=ROOT/'_scratch/d2-leisure-01/residual-lifestyle-20261006';GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin');MOD=ROOT/'mod/42.20/media/lua'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
MODES={'debug':'client/ISUI/LSDebugConfirm.lua','interaction':'client/MPSocial/InteractionManager.lua','server-bag':'server/LSservercommands.lua','server-wet':'server/LSservercommands.lua','server-movable':'server/LSservercommands.lua','server-trait':'server/LSservercommands.lua','beauty':'client/Properties/Objects/beauty.lua','toilet':'shared/Hygiene/ToiletFunctions.lua','mirror':'client/ISUI/LSMirrorMenu.lua','read':'shared/TimedActions/hooks/Read.lua','soundboard':'client/ISUI/DJSoundboardOverlay.lua','playlist':'client/ISUI/PlaylistImportConfirm.lua','wardrobe':'client/ISUI/WardrobeConfirm.lua','harvester':'shared/TimedActions/LSInvHarvesterAction.lua','server-puddle':'server/LSservercmdhandler.lua','weapon':'shared/LSUtil.lua','new-menu':'client/Instruments/NewInstrumentsContextMenu.lua','vanilla-menu':'client/Instruments/VanillaInstrumentsContextMenu.lua','art-menu':'client/Painting/ArtCardContextMenu.lua'}
NAMES={'debug':['AMBT','Key'],'interaction':['adjObj'],'server-bag':['bad','mood','movableData','traitName'],'beauty':['beauty'],'toilet':['containsItem'],'mirror':['idxStatic','useTattoo'],'read':['invData'],'soundboard':['new'],'playlist':['new','target','onclick'],'wardrobe':['new','target','onclick'],'harvester':['tA'],'server-puddle':['targetFloor'],'weapon':['weapon'],'new-menu':['worldobjects'],'vanilla-menu':['worldobjects'],'art-menu':['worldobjects']}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);ap.add_argument('--modes',nargs='*');a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 stage=json.loads((STAGE/'stage-receipt.json').read_text());jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];base=GAME/'media/lua/shared/ISBaseObject.lua';action=GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua';read=GAME/'media/lua/shared/TimedActions/ISReadABook.lua';compiler=ROOT/'tools/luacheck/LuaGlobals.java'
 files=[Path(__file__),*FIX.glob('*.*'),STAGE/'stage-receipt.json',STAGE/'importer-snippet.py',base,action,read,compiler,GAME/'stdlib.lua',GAME/'media/scripts/generated/items/literature.txt',MOD/'server/Makeup/LSMirrorMenu_server.lua',MOD/'shared/LSSync.lua',*jars,*[Path(r['original'])for r in stage['files']],*[MOD/r['path']for r in stage['files']],*[STAGE/sub/r['path']for sub in ['before','proposed']for r in stage['files']]]
 pins={str(p):sha(p)for p in files};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],'controls':[],'scope':'Complete original-derived source modules in actual installed Kahlua compiler/runtime and native Event dispatch. Actual native ItemContainer/InventoryContainer, Stats, BodyDamage/BodyPart, CharacterTraits, IsoGameCharacter.modifyTraitXPBoost with controlled definition metadata, WeaponType, WornItems and DrainableComboItem.Use. Controlled scene/UI, wearer/player body and catalogue bindings. No game-frame, rendered desktop, save/MP or autonomous-use claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,args):
  r=subprocess.run(list(map(str,args)),cwd=out,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(log)});save();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
 save()
 try:
  (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());classes=out/'classes';classes.mkdir();cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-cp',cp,'-d',classes,FIX/'ResidualLifestyleProbe.java',FIX/'ResidualNativeBridge.java',FIX/'ResidualBookBridge.java',compiler]);assert code==0,log;cp=str(classes)+os.pathsep+cp
  def behavior(mode,path,label):
   args=[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',cp,'ResidualLifestyleProbe',mode,FIX/'prelude.lua',base,action,FIX/'setup.lua']
   if mode=='read':args.append(read)
   if mode=='server-bag':args.append(MOD/'shared/LSSync.lua')
   args+=['module='+str(path),FIX/'cases.lua'];
   if mode=='mirror':args.extend([FIX/'mirror.lua',MOD/'server/Makeup/LSMirrorMenu_server.lua',FIX/'mirror_mp.lua'])
   return run(label,args)
  checks={};scanned=set()
  for row in stage['files']:
   assert sha(Path(row['original']))==row['sourceSha256'] and sha(MOD/row['path'])==row['preimageSha256'],row['path']
  for mode in a.modes or MODES:
   path=MODES[mode];row=next(r for r in stage['files']if r['path']==path);new=STAGE/'proposed'/path;old=STAGE/'before'/path;assert sha(new)==row['postimageSha256'] and sha(old)==row['preimageSha256']
   if path not in scanned:
    scanmode=next(m for m in NAMES if MODES[m]==path);names=NAMES[scanmode];code,log=run(scanmode+'-globals',[JDK/'java.exe','-cp',cp,'LuaGlobals',new]);assert code==0,log;bad=[l for l in log.splitlines()if re.match('(GET|SET) ('+'|'.join(names)+') ',l)];assert not bad,(path,bad)
    code,log=run(scanmode+'-original-globals',[JDK/'java.exe','-cp',cp,'LuaGlobals',old]);assert code==0 and any(re.match('(GET|SET) ('+'|'.join(names)+') ',l)for l in log.splitlines()),(path,log);receipt['controls'].append({'name':scanmode+'-original-global-restored','names':names});scanned.add(path)
   code,log=behavior(mode,new,mode+'-proposed');assert code==0,log;checks[mode]=int(float(re.search(r'checks=([\d.]+)',log)[1]));assert checks[mode]>0,(mode,log)
   code,log=behavior(mode,old,mode+'-original-restored');assert code!=0,(mode,log);receipt['controls'].append({'name':mode+'-actual-original-defect-restored','failureTail':log[-1000:]})
  if not a.modes:
   mutations=[
    ('mirror','tattoo-never-charge','local useTattoo = MMhasTattooChange(self)','local useTattoo = false'),
    ('mirror','tattoo-client-command-unconditional','self.beardDyeItem, useTattoo and self.itemsList.MakeupTattooNeedle, self.acidBrush','self.beardDyeItem, self.itemsList.MakeupTattooNeedle, self.acidBrush'),
    ('mirror','tattoo-always-charge','local useTattoo = MMhasTattooChange(self)','local useTattoo = true'),
    ('mirror','makeup-slot-foreign','onClickMakeupPreview, makeup, makeupCat, 1, false','onClickMakeupPreview, makeup, makeupCat, idxStatic, false'),
    ('mirror','hair-slot-foreign','onClickChangeHairPreview, hairStyle, isBeard, 1, false','onClickChangeHairPreview, hairStyle, isBeard, idxStatic, false'),
    ('mirror','dye-slot-foreign','onClickDyeHairPreview, dyeItem, isBeard, 1, false','onClickDyeHairPreview, dyeItem, isBeard, idxStatic, false'),
    ('server-bag','bag-parent-container','bag and bag.getItemContainer and bag:getItemContainer()','bag and bag.getContainer and bag:getContainer()'),
    ('server-wet','wetness-wrong-installed-setter','for n=0,parts:size()-1 do parts:get(n):setWetness(value); end','bodyDamage:setWetness(value)'),
    ('server-movable','movable-owned-table-init-omitted','itemData.movableData = itemData.movableData or {}','-- omitted owned table initialization'),
    ('server-trait','trait-foreign-name','player:modifyTraitXPBoost(CharacterTrait[trait], method == "remove")','player:modifyTraitXPBoost(CharacterTrait[traitName], method == "remove")'),
    ('read','read-invalid-state-data-unchecked','if efficiency and efficiency > 0 then','if true then'),
    ('harvester','harvester-foreign-data','not LSUtil.isCooldown(self.data)','not LSUtil.isCooldown(tA.data)'),
   ]
   for mode,name,old,new in mutations:
    data=(STAGE/'proposed'/MODES[mode]).read_bytes();old=old.encode();new=new.encode();assert data.count(old)==1,(name,data.count(old));mutated=out/(name+'.lua');mutated.write_bytes(data.replace(old,new,1));code,log=behavior(mode,mutated,name);assert code!=0,(name,log);receipt['controls'].append({'name':name,'mutatedSha256':sha(mutated),'failureTail':log[-1000:]})
   for function,name in [('initialise','playlist-initialise-player-zero'),('destroy','playlist-halo-player-zero'),('onClick','playlist-write-player-zero')]:
    data=(STAGE/'proposed'/MODES['playlist']).read_bytes();start=data.index(('function PlaylistImportConfirm:'+function+'(').encode());stop=data.find(b'\nfunction ',start+10);stop=len(data)if stop<0 else stop;section=data[start:stop];old=b'local specificPlayer = self.character';assert section.count(old)==1;changed=section.replace(old,b'local specificPlayer = getSpecificPlayer(0)');mutated=out/(name+'.lua');mutated.write_bytes(data[:start]+changed+data[stop:]);code,log=behavior('playlist',mutated,name);assert code!=0,(name,log);receipt['controls'].append({'name':name,'mutatedSha256':sha(mutated),'failureTail':log[-1000:]})
  receipt['inputsAfter']={p:sha(p)for p in pins};assert receipt['inputsAfter']==pins;receipt.update(status='PASS',checksByMode=checks,checks=sum(checks.values()),sourceModuleCount=len(scanned),productionUnchanged=True);save();print('PASS',receipt['checks'],'checks',len(receipt['controls']),'controls')
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
