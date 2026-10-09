"""Compile native cohorts and exercise real participant code with labeled engine stubs.

Requires the installed PZ jars and JDK. This does not initialize or launch PZ.
All generated classes, fixtures, logs and agent jars belong to --output.
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_DIR','C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',str(Path.home()/'Peanut Butter/JetBrains/Java/bin')))
COHORTS={
 'participant':['StudyLoadingAgent.java','StudyParticipantInput.java','StudyParticipant.java','StudyStartContext.java','StudyNativeInteraction.java','StudyObserver.java','StudyViewCapture.java','StudyExport.java','StudyVideoCapture.java'],
 'observer':['StudyLoadingAgent.java','StudyObserver.java','StudyViewCapture.java','StudyExport.java','StudyVideoCapture.java']}
STUBS={
 'org/lwjglx/opengl/Display.java':'''package org.lwjglx.opengl; public final class Display {public static boolean active=true,fail; public static boolean isActive(){if(fail)throw new IllegalStateException("controlled focus query failure");return active;} public static void update(boolean value){} }''',
 'zombie/ZomboidFileSystem.java':'''package zombie; public final class ZomboidFileSystem {public static final ZomboidFileSystem instance=new ZomboidFileSystem();public String directory,screens;public String getCurrentSaveDir(){return directory;}public String getScreenshotDir(){return screens;}public void loadMods(String name){} }''',
 'zombie/core/Core.java':'''package zombie.core; public final class Core {public static String gameSaveWorld;public static boolean debug;public static zombie.ui.UITextEntryInterface currentTextEntryBox;public static String mode="Sandbox";private static final Core instance=new Core();public static Core getInstance(){return instance;}public String getGameMode(){return mode;}}''',
 'zombie/input/KeyboardState.java':'''package zombie.input;public final class KeyboardState {public boolean physical;public boolean isKeyDown(int key){return physical;}}''',
 'zombie/input/MouseState.java':'''package zombie.input;public final class MouseState {public boolean isButtonDown(int key){return false;}public int getX(){return 77;}public int getY(){return 88;}}''',
 'zombie/ui/UITextEntryInterface.java':'''package zombie.ui;public interface UITextEntryInterface {boolean isDoingTextEntry();}''',
 'zombie/characters/IsoPlayer.java':'''package zombie.characters;public class IsoPlayer extends IsoGameCharacter {public static final IsoPlayer[] players=new IsoPlayer[4];public int playerIndex=0,sqlId=1,num=0;public boolean dead;public float x=10,y=20,z=0;public String label="Synthetic actual body";public se.krka.kahlua.vm.KahluaTable modData;public int modDataReads;public boolean hasModData(){return modData!=null;}public se.krka.kahlua.vm.KahluaTable getModData(){modDataReads++;return modData;}public zombie.iso.IsoGridSquare square=new zombie.iso.IsoGridSquare();public int getPlayerNum(){return num;}public zombie.iso.IsoGridSquare getCurrentSquare(){return square;}public String getDisplayName(){return label;}public boolean isDead(){return dead;}public float getX(){return x;}public float getY(){return y;}public float getZ(){return z;}}''',
 'zombie/characters/IsoGameCharacter.java':'''package zombie.characters;public class IsoGameCharacter extends zombie.iso.IsoMovingObject {}''',
 'zombie/iso/IsoMovingObject.java':'''package zombie.iso;public class IsoMovingObject {}''',
 'zombie/iso/IsoGridSquare.java':'''package zombie.iso;public final class IsoGridSquare {}''',
 'zombie/iso/IsoCell.java':'''package zombie.iso;public class IsoCell {}''',
 'zombie/iso/IsoWorld.java':'''package zombie.iso;public final class IsoWorld {public static final IsoWorld instance=new IsoWorld();public IsoCell currentCell;}''',
 'zombie/GameTime.java':'''package zombie;public final class GameTime {public static double hours=25.5;private static final GameTime value=new GameTime();public static GameTime getInstance(){return value;}public double getWorldAgeHours(){return hours;}}''',
 'zombie/GameWindow.java':'''package zombie;public final class GameWindow {public static boolean closeRequested;public static void logic(){} }''',
 'zombie/Lua/LuaManager.java':'''package zombie.Lua;public final class LuaManager {public static se.krka.kahlua.vm.KahluaTable env;public static se.krka.kahlua.vm.KahluaThread thread;public static se.krka.kahlua.integration.LuaCaller caller;}''',
 'zombie/input/GameKeyboard.java':'''package zombie.input;public final class GameKeyboard {public static boolean observed;public static void update(){observed=new KeyboardState().isKeyDown(17);}}''',
 'zombie/input/Mouse.java':'''package zombie.input;public final class Mouse {public static boolean observed;public static int x,y;public static void update(){var state=new MouseState();observed=state.isButtonDown(0);x=state.getX();y=state.getY();}}''',
 'zombie/gameStates/GameLoadingState.java':'''package zombie.gameStates;public final class GameLoadingState {public boolean forceDone;public void update(){} }''',
 'zombie/core/sprite/SpriteRenderState.java':'''package zombie.core.sprite;public final class SpriteRenderState {public int numSprites;public void onReady(){} }''',
 'zombie/core/SpriteRenderer.java':'''package zombie.core;public final class SpriteRenderer {public static final SpriteRenderer instance=new SpriteRenderer();public zombie.core.sprite.SpriteRenderState getRenderingState(){return new zombie.core.sprite.SpriteRenderState();}public void postRender(){} }''',
}

def pin(path:Path):
 data=path.read_bytes();return {'path':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def run(output:Path):
 output.mkdir(parents=True,exist_ok=False)
 jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']; dependencies=[*jars,JDK/'javac.exe',JDK/'java.exe',JDK/'jar.exe']
 for p in dependencies:
  if not p.is_file():raise FileNotFoundError(p)
 production=sorted({ROOT/'tools/world_lab'/n for ns in COHORTS.values() for n in ns}|{ROOT/'tools/world_lab/StudyParticipantControlTest.java',Path(__file__).resolve()})
 before=[pin(p) for p in production];results=[]
 def command(label,args):
  with (output/(label+'.stdout.log')).open('xb') as stdout,(output/(label+'.stderr.log')).open('xb') as stderr:
   result=subprocess.run(list(map(str,args)),stdout=stdout,stderr=stderr,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
  row={'label':label,'command':list(map(str,args)),'exitCode':result.returncode,'stdout':pin(output/(label+'.stdout.log')),'stderr':pin(output/(label+'.stderr.log'))}
  results.append(row);print(json.dumps({'label':label,'exitCode':result.returncode}),flush=True);return row
 cp=os.pathsep.join(map(str,jars))
 for label,names in COHORTS.items():
  target=output/(label+'-classes');target.mkdir()
  command(label+'-compile',[JDK/'javac.exe','-cp',cp,'-d',target,*[ROOT/'tools/world_lab'/n for n in names]])
 stub_source=output/'stub-source';stub_classes=output/'stub-classes';stub_classes.mkdir()
 for name,body in STUBS.items():
  p=stub_source/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(body,encoding='utf-8')
 command('stubs-compile',[JDK/'javac.exe','-cp',cp,'-d',stub_classes,*sorted(stub_source.rglob('*.java'))])
 participant=output/'participant-classes'
 controlcp=os.pathsep.join(map(str,[stub_classes,participant,*jars]))
 command('control-compile',[JDK/'javac.exe','-cp',controlcp,'-d',stub_classes,ROOT/'tools/world_lab/StudyParticipantControlTest.java'])
 if all(r['exitCode']==0 for r in results):
  command('direct-controls',[JDK/'java.exe','-Djava.awt.headless=true','-cp',controlcp,'StudyParticipantControlTest',output/'direct-fixture'])
  manifest=output/'MANIFEST.MF';manifest.write_text('Manifest-Version: 1.0\nPremain-Class: StudyLoadingAgent\nCan-Retransform-Classes: true\n\n')
  jar=output/'participant-test-agent.jar'
  command('agent-build',[JDK/'jar.exe','cfm',jar,manifest,'-C',participant,'.'])
  fixture=output/'agent-fixture';fixture.mkdir()
  props={'study.participantInput':'true','study.participantSession':'12345678-1234-1234-1234-123456789abc','study.participantLease':fixture/'lease.json','study.participantState':fixture/'participant-state.json','study.attempt':'1','study.showWindow':'true','study.controlAgent':'true'}
  command('instrumented-controls',[JDK/'java.exe','-Djava.awt.headless=true',*[f'-D{k}={v}' for k,v in props.items()],f'-javaagent:{jar}=isolated-study','-cp',controlcp,'StudyParticipantControlTest',fixture])
 for row in results:
  if row['label'].endswith('controls'):
   text=Path(row['stdout']['path']).read_text();matches=re.findall(r'^CONTROL (PASS|FAIL) (.*)$',text,re.M)
   row['controls']=[{'status':s,'name':n} for s,n in matches];row['passed']=sum(s=='PASS' for s,n in matches);row['failed']=sum(s=='FAIL' for s,n in matches)
   row['reportedCounts']=re.findall(r'checks=(\d+); pass=(\d+); failures=(\d+)',text)
   row['fixtureSchemaChecks']=[]
   for name in ['unready-observed.json','unready-native.json','ready-state.json']:
    path=output/('agent-fixture' if row['label']=='instrumented-controls' else 'direct-fixture')/name
    if path.exists():
     data=json.loads(path.read_text());row['fixtureSchemaChecks'].append({'file':pin(path),'schema':data['schema']})
 after=[pin(p) for p in production]
 errors=[r['label'] for r in results if r['exitCode']!=0]
 receipt={'schema':'sao.participant-java-controlled-validation/1','status':'PASS' if not errors and before==after else 'FAIL','scope':'actual installed dependency compile and actual participant/ByteBuddy code under explicitly synthetic engine fixtures; no game/native acceptance','sourceBefore':before,'sourceAfter':after,'stable':before==after,'dependencies':[pin(p) for p in dependencies],'results':results,'errors':errors}
 (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'status':receipt['status'],'receipt':pin(output/'receipt.json'),'errors':errors}),flush=True)
 return 0 if receipt['status']=='PASS' else 1

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 raise SystemExit(run(args.output.resolve()))
