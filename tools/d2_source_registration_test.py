#!/usr/bin/env python3
"""Guard controls and actual installed parser proof for a sealed registration merge."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,tempfile
import d2_source_registration as m
from native_proof_preflight import installed_presence
ROOT=m.ROOT;GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'));JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
JAVA=ROOT/'tools/d2_source_registration/RegistrationProbe.java'
def assert_equal_outputs(outputs,package):
 for relative,data in outputs.items():assert (package/relative).read_bytes()==data,relative
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--merge',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--guards-only',action='store_true');args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 merge=args.merge.resolve();record=json.loads((merge/'receipt.json').read_text(encoding='utf-8'));report=Path(record['report']);source=json.loads(report.read_text(encoding='utf-8'));jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),Path(m.__file__),ROOT/'tools/d2_source_package.py',JAVA,m.PACKAGE/'media/lua/shared/NPCs/SAO_Traits.lua',m.PACKAGE/'media/scripts/generated/characters/LS_character_traits.txt',report,merge/'receipt.json',*[m.PACKAGE/v['fragment']for v in source['mergeRequired']],*[merge/'merged'/p for p in record['outputs']],*jars,GAME/'stdlib.lua',GAME/'media/tileGeometry.txt',GAME/'media/lua/shared/Sandbox/Apocalypse.lua']
 missing=installed_presence(inputs,GAME,JDK,'D2 native source registrations')
 if missing is not None:return missing
 receipt={'schema':'sao.native-source-registration-proof/1','status':'INCOMPLETE','inputsBefore':{str(p):m.sha_bytes(p.read_bytes())for p in inputs},'controls':[],'runs':[],'boundary':'Installed native ScriptParser/CustomSandboxOptions and actual SandboxOptions binding, CustomPerks, TileGeometryFile/TileDepthTextureAssignments, FileGuidTable XML parser and CharacterTrait/ItemTag receivers. No graphics texturepack/tilemap render/game/MP startup claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def check(name,fn,expected=True):
  failed=False
  try:fn()
  except (ValueError,AssertionError):failed=True
  assert failed==expected,name;receipt['controls'].append({'name':name,'expectedRefusal':expected})
 def run(name,command,work):
  r=subprocess.run(list(map(str,command)),cwd=work,capture_output=True,timeout=120);p=out/(name+'.log');p.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'sha256':m.sha_bytes(p.read_bytes())});save();return r.returncode,p.read_text(encoding='utf-8',errors='replace')
 try:
  check('unclosed-block',lambda:m.parse('VERSION = 1, option A { type = boolean,'))
  check('conflicting-option',lambda:m.merge_header(['VERSION = 1, option A { type = boolean, default = true, }','VERSION = 1, option A { type = boolean, default = false, }'],'option',1))
  check('duplicate-version',lambda:m.merge_header(['VERSION = 1, VERSION = 1, option A { default = true, }'],'option',1))
  check('unsupported-version',lambda:m.merge_header(['VERSION = 2, option A { default = true, }'],'option',1))
  check('duplicate-option',lambda:m.merge_header(['VERSION = 1, option A { default = true, } option A { default = true, }'],'option',1))
  check('conflicting-depth-key',lambda:m.merge_wrapper(['tileDepthTextureAssignments {VERSION = 1, x = a,}','tileDepthTextureAssignments {VERSION = 1, x = b,}'],'tileDepthTextureAssignments',1))
  check('duplicate-geometry-coordinate',lambda:m.merge_wrapper(['tileGeometry {VERSION = 2, tileset {name = x, tile {xy = 0x0,} tile {xy = 0x0,}}}'],'tileGeometry',2))
  check('unresolved-guid',lambda:m.merge_xml(['<fileGuidTable><files><path>media/no-such.xml</path><guid>x</guid></files></fileGuidTable>'],m.PACKAGE))
  # Functional restored conflict guard: the defective merger accepts the conflicting input.
  text=Path(m.__file__).read_text(encoding='utf-8');old="if normalized(blocks[row['id']])!=normalized(row):raise ValueError('conflicting '+kind+' '+row['id'])";assert text.count(old)==1
  namespace={'__file__':str(Path(m.__file__)),'__name__':'private_defective_registration'};exec(compile(text.replace(old,'if False:raise ValueError("removed-conflict-guard")',1),str(Path(m.__file__)), 'exec'),namespace)
  check('restored-conflict-guard-removed',lambda:namespace['merge_header'](['VERSION = 1, option A { default = true, }','VERSION = 1, option A { default = false, }'],'option',1),False)
  with tempfile.TemporaryDirectory(prefix='sao-registration-negative-')as tmp:
   private=Path(tmp);fragment='media/SAOSources/Merged/media/lua/shared/Translate/EN/UI.txt';canonical='media/lua/shared/Translate/EN/UI.txt';target=private/fragment;target.parent.mkdir(parents=True);data=b'UI_EN = {\n UI_existing = "previous",\n}\n';target.write_bytes(data);dest=private/canonical;dest.parent.mkdir(parents=True);dest.write_text('UI_EN = {\n UI_existing = "changed",\n}\n')
   row={'enginePath':canonical,'fragment':fragment,'sha256':m.sha_bytes(data),'kind':'merged-translation'}
   (private/'mod.info').write_text('id=SurvivorAwareness\n')
   dest.write_bytes(data);check('canonical-translation-preserved',lambda:m.plan(private,{'mergeRequired':[row],'registrations':{}}),False)
   dest.write_text('UI_EN = {\n UI_existing = "changed",\n}\n')
   check('canonical-translation-drift',lambda:m.plan(private,{'mergeRequired':[row],'registrations':{}}))
   target.write_bytes(data+b'--tamper');check('original-fragment-seal',lambda:m.plan(private,{'mergeRequired':[row],'registrations':{}}))
  planned,_,_=m.plan(m.PACKAGE,source)
  check('current-canonical-merge-idempotent',lambda:assert_equal_outputs(planned,m.PACKAGE),False)
  # Restoring newline normalization reproduces the actual byte-preservation defect.
  raw="target.read_bytes().decode('utf-8-sig')if target.exists()else''";assert text.count(raw)==1
  broken={'__file__':str(Path(m.__file__)),'__name__':'private_line_ending_defect'};exec(compile(text.replace(raw,"target.read_text(encoding='utf-8-sig')if target.exists()else''",1),str(Path(m.__file__)),'exec'),broken)
  check('restored-line-ending-normalization-defect',lambda:assert_equal_outputs(broken['plan'](m.PACKAGE,source)[0],m.PACKAGE))
  if args.guards_only:
   receipt['inputsAfter']={str(p):m.sha_bytes(p.read_bytes())for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'];receipt['status']='PASS';receipt['nativeChecks']=0;receipt['reusesNativeProof']='source-registration-proof-06: all210data output hashes unchanged; onlymetadataCRLF prefix correction';save();print('PASS registration guards',len(receipt['controls']));return 0
  # Actual preimage + every original fragment are separately parsed by the native receiver.
  tsv=out/'expected-fragments.tsv';pairs=[]
  for relative in ['media/sandbox-options.txt','media/perks.txt','media/tileGeometry.txt','media/tileDepthTextureAssignments.txt']:
   before=merge/'preimages'/relative
   if before.is_file():pairs.append((relative,before))
   pairs.extend((relative,m.PACKAGE/row['fragment'])for row in source['mergeRequired']if row['enginePath']==relative)
  tsv.write_text(''.join(name+'\t'+str(p)+'\n'for name,p in pairs),encoding='utf-8')
  layout={}
  for row in source['mergeRequired']:
   if row['enginePath']!='media/sandbox-options.txt':continue
   fragment=(m.PACKAGE/row['fragment']).read_text(encoding='utf-8-sig')
   local=m.source_option_layout(fragment,row['sourceId'])
   assert not set(layout)&set(local),'duplicate D2 sandbox option identity'
   layout.update(local)
  assert len(layout)==156 and len({new for old,new in layout.values()})==15
  page_tsv=out/'sao-source-pages.tsv'
  page_tsv.write_text(''.join(name+'\t'+new+'\n'for name,(old,new)in layout.items()),encoding='utf-8')
  locale_path='media/lua/shared/Translate/EN/Sandbox.json'
  locale=json.loads((merge/'merged'/locale_path).read_text(encoding='utf-8'))
  original_locale=json.loads((m.PACKAGE/'media/SAOSources/Merged'/locale_path).read_text(encoding='utf-8'))
  assert all(locale.get(key)==value for key,value in original_locale.items()),'source locale value drift'
  assert all(locale.get('Sandbox_'+page)==label for page,label in m.SAO_PAGE_LABELS.items()),'SAO page locale absent'
  catalog=(merge/'merged/media/lua/shared/SAO_SourceSandboxPages.lua').read_text(encoding='utf-8')
  assert all('['+json.dumps(name)+']={sourceId=' in catalog for name in layout),'source page catalog incomplete'
  with tempfile.TemporaryDirectory(prefix='sao-native-registration-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars));status,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,JAVA],work);assert status==0,log
   status,log=run('native',[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-Djava.library.path='+str(GAME),'-Duser.home='+str(work),'-cp',str(work)+os.pathsep+cp,'RegistrationProbe',merge/'merged',tsv,GAME,page_tsv],GAME);assert status==0 and 'PASS native registrations'in log,log[-9000:];receipt['nativeChecks']=int(re.search(r'PASS native registrations (\d+)',log)[1])
  receipt['inputsAfter']={str(p):m.sha_bytes(p.read_bytes())for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'registration inputs drifted';receipt['status']='PASS';save();print('PASS source registrations',receipt['nativeChecks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['failure']=str(error);save();print('FAIL',error);return 1
if __name__=='__main__':raise SystemExit(main())
