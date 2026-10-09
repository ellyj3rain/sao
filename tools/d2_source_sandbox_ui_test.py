"""SAO source sandbox grouping and dual-mod screen controls in native Kahlua."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile
import d2_leisure_lifestyle_test as base

ROOT=base.ROOT
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_Sandbox.lua'
CATALOG=ROOT/'mod/42.20/media/lua/shared/SAO_SourceSandboxPages.lua'
WEEKONE_CATALOG=ROOT/'mod/42.20/media/lua/shared/SAO_WeekOneSandboxPages.lua'
FIXTURE=ROOT/'tools/d2_source_sandbox_ui/fixture.lua'
JAVA=base.BASE/'MusicProbe.java'
GAME=base.GAME
JDK=base.JDK
VANILLA=[GAME/'media/lua/client/OptionScreens/SandboxOptions.lua',
         GAME/'media/lua/client/OptionScreens/ServerSettingsScreen.lua',
         GAME/'media/lua/client/ISUI/ISScrollingListBox.lua']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);args=p.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),OWNER,CATALOG,WEEKONE_CATALOG,FIXTURE,JAVA,GAME/'stdlib.lua',*VANILLA,*jars]
 before={str(path):sha(path)for path in inputs}
 receipt={'status':'INCOMPLETE','boundary':'Native Kahlua source screen wrapper with controlled SP/server screen objects; installed 42.20 UI source pinned. No rendered desktop claim.','inputsBefore':before,'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 controls=[
  ('solo-duplicate-filter','local selected, sourceRemoved = coalesceSourcePages(pages)',
   'local selected, sourceRemoved = pages, 0','solo_single_Text.DividerMusicNew'),
  ('server-duplicate-filter','local selected, removed = coalesceSourcePages(pages)',
   'local selected, removed = pages, 0','server_single_Text.DividerMusicNew'),
  ('effective-page-owner','if row.pageId == selected then keep = row end',
   'if row.pageId ~= selected then keep = row end','solo_effective_page_Text.DividerMusicNew'),
  ('server-visible-control-binding','controls[setting.name] = panel.controls[setting.name]',
   'controls[setting.name] = controls[setting.name]','server_control_bound_NewMusic.MaxTrackingRange'),
 ]
 try:
  with tempfile.TemporaryDirectory(prefix='sao-source-sandbox-ui-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
   cp=os.pathsep.join(map(str,jars))
   r=subprocess.run(list(map(str,[JDK/'javac.exe','-cp',cp,'-d',work,JAVA])),capture_output=True)
   (out/'compile.log').write_bytes(r.stdout+r.stderr);assert r.returncode==0
   original=OWNER.read_text(encoding='utf-8')
   for name,old,new,marker in [('baseline',None,None,None)]+controls:
    variant=original
    if old is not None:
     assert variant.count(old)==1,(name,variant.count(old))
     variant=variant.replace(old,new,1)
    target=out/(name+'-sandbox.lua');target.write_text(variant,encoding='utf-8')
    manifest=out/(name+'-sources.tsv')
    manifest.write_text('Owned:Catalog\t'+str(CATALOG)+'\nOwned:WeekOneCatalog\t'+str(WEEKONE_CATALOG)+'\nOwned:Sandbox\t'+str(target)+'\n')
    cmd=[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true',
         '-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,FIXTURE]
    r=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90)
    log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
    text=log.read_text(errors='replace')
    receipt['runs'].append({'name':name,'exit':r.returncode,'logSha256':sha(log),'marker':marker});save()
    if marker:assert r.returncode!=0 and 'D2_SOURCE_UI:'+marker in text,(name,text[-5000:])
    else:assert r.returncode==0 and 'PASS D2 source UI ' in text,text[-7000:]
  receipt['inputsAfter']={str(path):sha(path)for path in inputs}
  assert receipt['inputsAfter']==before
  receipt['status']='PASS';receipt['inverses']=len(controls);save()
  print('PASS source UI',len(controls),'inverses')
 except Exception as error:
  receipt['status']='FAIL';receipt['error']=str(error);save();raise

if __name__=='__main__':main()
