#!/usr/bin/env python3
"""Native off-slot actor/Stats/XP/known GUID; native emission receiver is controlled."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_radio_test as base
from native_proof_preflight import installed_presence
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);args=p.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 skill=base.ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua';probe=base.ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[base.ROOT/'tools/luacheck/MovementCrossingProbe.java',base.ROOT/'tools/luacheck/ResourceApproachProbe.java',base.ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 native=[base.GAME/'media/lua/shared/ISBaseObject.lua',base.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[base.GAME/'projectzomboid.jar',*sorted((base.GAME/'jars').glob('*.jar')),base.GAME/'ZombieBuddy.jar',base.ROOT/'mod/42.20/media/java/SAO.jar']
 inputs=[Path(__file__),Path(base.__file__),base.OWNER,skill,probe,*helpers,base.HERE/'prelude.lua',base.HERE/'native-cases.lua',*native,*jars,base.GAME/'stdlib.lua',base.GAME/'media/scripts/generated/items/drainable.txt',*[base.GAME/'media/lua'/f for f in base.FILES]]
 absent=installed_presence(inputs,base.GAME,base.JDK,'D2 native radio source effects')
 if absent is not None:return absent
 receipt={'schema':'sao-d2-native-radio-effects/1','status':'INCOMPLETE','inputsBefore':{str(f):base.sha(f)for f in inputs},'runs':[],
 'boundary':'Actual installed off-slot SAOIsoPlayerShell with native Stats, native Woodwork perk/XP, actual IsoRadio/DeviceData and original source checkPlayer/doSkill/known-media callback, plus actual canonical LeisureSkill SP addXp receiver. Native emission/current capability, geometry acquisition, queue/audio/hardware and clocks remain controlled. This proof does not replace native Java weaving/distribution/visible hearing qualification.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'logSha256':base.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  manifest=out/'source-paths.tsv';manifest.write_text(''.join('native:'+f+'\t'+str(base.GAME/'media/lua'/f)+'\n'for f in base.FILES))
  enums=out/'enums.lua';enums.write_text('Perks=__nativePerks;instanceof=__nativeinstanceof\n')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class NativeRadioProbe')
  java=java.replace('{"weapon.txt","GuitarAcoustic","__guitar"}',
   '{"weapon.txt","GuitarAcoustic","__guitar"},{"drainable.txt","Battery","__nativeBattery"}')
  java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class',
   'zombie.inventory.types.DrainableComboItem.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.iso.objects.IsoRadio.class,zombie.iso.objects.IsoWaveSignal.class,zombie.radio.devices.DeviceData.class,zombie.radio.devices.DevicePresets.class,zombie.radio.devices.PresetEntry.class,\n IsoCell.class,zombie.iso.IsoGridSquare.class')
  injection='''LuaCompiler.register(env);
  var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var parts=row.split("\\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
  env.rawset("__nativePerks",env.rawget("Perks"));env.rawset("__nativeinstanceof",env.rawget("instanceof"));
  var global=new zombie.Lua.LuaManager.GlobalObject();
  env.rawset("addXp",(JavaFunction)(f,n)->{global.addXp((zombie.characters.IsoPlayer)f.get(0),(zombie.characters.skills.PerkFactory.Perk)f.get(1),((Number)f.get(2)).floatValue());return 0;});
  env.rawset("SyncXp",(JavaFunction)(f,n)->{global.SyncXp((zombie.characters.IsoPlayer)f.get(0));return 0;});
  var radio=new zombie.iso.objects.IsoRadio(cell);radio.setSquare(body.getCurrentSquare());var sprite=new zombie.iso.sprite.IsoSprite();sprite.name="appliances_radio_01_0";radio.setSprite(sprite);radio.getSquare().getObjects().add(radio);
  var device=new zombie.radio.devices.DeviceData(radio);radio.setDeviceData(device);device.setIsBatteryPowered(true);device.setPower(.8f);device.setIsTurnedOn(true);device.setDeviceVolumeRaw(.6f);device.setChannelRaw(88000);
  env.rawset("__nativeRadio",radio);
  '''.replace('MANIFEST',json.dumps(str(manifest)))
  java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
  generated=out/'NativeRadioProbe.java';generated.write_text(java)
  with tempfile.TemporaryDirectory(prefix='sao-native-radio-')as tmp:
   work=Path(tmp);shutil.copyfile(base.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[base.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   receiver=skill.read_text();receipt['controls']=[]
   owner=base.OWNER.read_text()
   battery_seam='if action.deviceData~=a.data then error("native-battery-parameter-not-exact-device")end'
   assert owner.count(battery_seam)==1
   variants=[('baseline',receiver,owner,None),
    ('omitted-native-xp',receiver.replace('addXp(body,perk,request.amount)','-- native XP removed',1),owner,'joined_native_radio_XP'),
    ('omitted-native-battery-complete',receiver,owner.replace(battery_seam,battery_seam+';action.complete=function()return true end',1),'native_battery_original_insert_power_and_custody')]
   for name,text,owner_text,marker in variants:
    variant=out/(name+'-receiver.lua');variant.write_text(text)
    owner_variant=out/(name+'-owner.lua');owner_variant.write_text(owner_text)
    code,log=run(name,[base.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'NativeRadioProbe',base.GAME,base.HERE/'prelude.lua',enums,*native,variant,owner_variant,base.HERE/'native-cases.lua'],work)
    if marker:assert code!=0 and 'D2_NATIVE_RADIO:'+marker in log,log[-6000:];receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS native source radio 'in log,log[-8500:];receipt['checks']=int(re.search(r'PASS native source radio (\d+)',log)[1])
  receipt['inputsAfter']={str(f):base.sha(f)for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'changed input during proof'
  receipt['status']='PASS';save();print('PASS native radio effects',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
