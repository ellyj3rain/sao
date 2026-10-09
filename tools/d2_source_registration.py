#!/usr/bin/env python3
"""Merge owned source fragments into canonical engine registration files.

All inputs are sealed; conflicts fail before mutation. Exact preimages and
old/new hashes are retained. Original imported vault fragments stay unchanged.
"""
from pathlib import Path
from collections import OrderedDict
import argparse,hashlib,json,re,xml.etree.ElementTree as ET
from d2_source_package import parse_translation,serialize_translation
import weekone_sandbox_controls as weekone
ROOT=Path(__file__).resolve().parents[1]
PACKAGE=ROOT/'mod/42.20'
# The engine's sandbox option identity is its dotted option ID. A page is a
# presentation field; source fragments remain byte-exact while the owned merge
# places their existing controls under source-linked SAO pages.
SAO_SOURCE_PAGES={
 'LifestyleHobbies':{
  'Lifestyle':('SAO_LifestyleHobbies_Main','SAO / Leisure / Hobbies'),
  'LifestyleMD':('SAO_LifestyleHobbies_MusicDance','SAO / Leisure / Music and Dance'),
  'LifestyleMY':('SAO_LifestyleHobbies_MeditationYoga','SAO / Leisure / Meditation and Yoga'),
  'LifestyleHC':('SAO_LifestyleHobbies_Hygiene','SAO / Leisure / Hygiene and Cleaning'),
  'LifestyleAA':('SAO_LifestyleHobbies_Art','SAO / Leisure / Art and Ambitions'),
  'LifestyleServer':('SAO_LifestyleHobbies_Server','SAO / Leisure / Server'),
  'LifestyleMisc':('SAO_LifestyleHobbies_Other','SAO / Leisure / Other'),
  'Character':('SAO_LifestyleHobbies_Skills','SAO / Leisure / Skill Gains'),
 },
 'NewMusic':{'NewMusic':('SAO_NewMusic','SAO / Music / Devices and Media')},
 'ComputerModkum':{
  'ComputerMod_Hardware':('SAO_ComputerModkum_Hardware','SAO / Computers / Hardware'),
  'ComputerMod_Network':('SAO_ComputerModkum_Network','SAO / Computers / Network'),
 },
 'ProjectArcade':{'ProjectArcade':('SAO_ProjectArcade','SAO / Recreation / Arcade')},
 'FWOFitnessWorkoutOverhaul':{'FWOFitness':('SAO_FWOFitnessWorkoutOverhaul','SAO / Fitness / Workouts')},
 'FWOBenchPressTreadmill':{'FWOWorkingTreadmill':('SAO_FWOBenchPressTreadmill','SAO / Fitness / Equipment')},
 'KnoxAquarium':{'KnoxAquarium':('SAO_KnoxAquarium','SAO / Care / Aquariums')},
}
SAO_PAGE_LABELS={new:label for pages in SAO_SOURCE_PAGES.values() for new,label in pages.values()}
def sha_bytes(data):return hashlib.sha256(data).hexdigest()
def masked(text):
 # Preserve positions while masking comments, for exact block slices.
 pattern=r'/\*.*?\*/|//[^\n]*'
 return re.sub(pattern,lambda m:''.join('\n'if c=='\n'else' 'for c in m[0]),text,flags=re.S)
def parse(text):
 """Balanced ScriptParser-format blocks/values, retaining original spans."""
 text=text.lstrip('\ufeff');clean=masked(text)
 def level(start,stop):
  rows=[];at=start
  while at<stop:
   while at<stop and(clean[at].isspace()or clean[at]==','):at+=1
   if at>=stop:break
   begin=at;quote=None;end=at
   while end<stop:
    c=clean[end]
    if quote:
     if c==quote and(end==0 or clean[end-1]!='\\'):quote=None
    elif c in'"\'':quote=c
    elif c in'{,}':break
    end+=1
   if end>=stop:raise ValueError('unterminated declaration: '+clean[begin:begin+80])
   header=clean[begin:end].strip();delimiter=clean[end]
   if delimiter=='}':raise ValueError('unmatched closing brace')
   if delimiter==',':
    if '='not in header:raise ValueError('invalid value: '+header)
    key,value=header.split('=',1);rows.append({'kind':'value','key':key.strip(),'value':value.strip(),'raw':text[begin:end+1]});at=end+1;continue
   depth=1;cursor=end+1;quote=None
   while cursor<stop and depth:
    c=clean[cursor]
    if quote:
     if c==quote and clean[cursor-1]!='\\':quote=None
    elif c in'"\'':quote=c
    elif c=='{':depth+=1
    elif c=='}':depth-=1
    cursor+=1
   if depth:raise ValueError('unclosed block: '+header)
   parts=header.split(None,1);rows.append({'kind':'block','type':parts[0],'id':parts[1]if len(parts)>1 else None,'children':level(end+1,cursor-1),'raw':text[begin:cursor]});at=cursor
  return rows
 return level(0,len(clean))
def normalized(row):return re.sub(r'\s+','',masked(row['raw']))
def keyed(rows,key):
 result=OrderedDict()
 for row in rows:
  identity=key(row)
  if identity in result:
   if normalized(result[identity])!=normalized(row):raise ValueError('conflicting registration '+str(identity))
   raise ValueError('duplicate registration '+str(identity))
  result[identity]=row
 return result
def merge_header(texts,kind,version):
 values=OrderedDict();blocks=OrderedDict()
 for text in texts:
  parsed=parse(text)
  if sum(v['kind']=='value'and v['key']=='VERSION'for v in parsed)!=1:raise ValueError('expected single version header')
  keyed(parsed,lambda v:v['key']if v['kind']=='value'else(v['type'],v['id']))
  for row in parsed:
   if row['kind']=='value':
    if row['key']!='VERSION'or row['value']!=str(version):raise ValueError('unsupported top-level header')
    values['VERSION']=row
   else:
    if row['type']!=kind or not row['id']:raise ValueError('unexpected registration block')
    if row['id']in blocks:
     if normalized(blocks[row['id']])!=normalized(row):raise ValueError('conflicting '+kind+' '+row['id'])
     continue
    keyed(row['children'],lambda v:(v['kind'],v.get('key')or(v.get('type'),v.get('id'))))
    blocks[row['id']]=row
 if 'VERSION'not in values:raise ValueError('version absent')
 return 'VERSION = '+str(version)+',\n\n'+'\n\n'.join(row['raw']for row in blocks.values())+'\n',list(blocks)
def repage_options(text,by_id,source_only=False):
 """Change only a selected option's page, rejecting unknown prior layouts."""
 seen=set()
 for row in parse(text):
  if row['kind']!='block' or row['type']!='option':continue
  option_id=row['id'];target=by_id.get(option_id)
  if target is None:
   if source_only:raise ValueError('unowned source option page: '+str(option_id))
   continue
  old,new=target
  pages=[child for child in row['children']if child['kind']=='value'and child['key']=='page']
  if len(pages)!=1 or pages[0]['value']not in ((old,)if source_only else(old,new)):
   raise ValueError('source option page drift: '+str(option_id))
  if pages[0]['value']==new:
   seen.add(option_id);continue
  page=pages[0];replacement=page['raw'].replace(page['value'],new,1)
  if replacement==page['raw'] or row['raw'].count(page['raw'])!=1:
   raise ValueError('ambiguous source option page: '+str(option_id))
  changed=row['raw'].replace(page['raw'],replacement,1)
  if text.count(row['raw'])!=1:raise ValueError('ambiguous source option block: '+str(option_id))
  text=text.replace(row['raw'],changed,1);seen.add(option_id)
 if source_only and seen!=set(by_id):raise ValueError('source option set drift')
 return text
def source_option_layout(text,source_id):
 pages=SAO_SOURCE_PAGES.get(source_id)
 if not pages:raise ValueError('unknown source option family: '+source_id)
 layout={};used=set()
 for row in parse(text):
  if row['kind']=='value'and row['key']=='VERSION':continue
  if row['kind']!='block' or row['type']!='option' or not row['id']:
   raise ValueError('unexpected source option declaration: '+source_id)
  page=[child['value']for child in row['children']if child['kind']=='value'and child['key']=='page']
  if len(page)!=1 or page[0]not in pages:raise ValueError('unknown source option page: '+str(row['id']))
  if row['id']in layout:raise ValueError('duplicate source option: '+row['id'])
  layout[row['id']]=(page[0],pages[page[0]][0]);used.add(page[0])
 if used!=set(pages):raise ValueError('source page without controls: '+source_id)
 return layout
def merge_wrapper(texts,wrapper,version):
 entries=OrderedDict()
 for text in texts:
  roots=parse(text)
  if len(roots)!=1 or roots[0].get('type')!=wrapper:raise ValueError('expected single '+wrapper+' wrapper')
  rows=roots[0]['children'];versions=[v for v in rows if v['kind']=='value'and v['key']=='VERSION']
  if len(versions)!=1 or versions[0]['value']!=str(version):raise ValueError('invalid wrapper version')
  for row in rows:
   if row['kind']=='value'and row['key']=='VERSION':continue
   if wrapper=='tileGeometry':
    if row.get('type')!='tileset':raise ValueError('unexpected geometry child')
    names=[v['value']for v in row['children']if v['kind']=='value'and v['key']=='name']
    if len(names)!=1:raise ValueError('tileset name absent/duplicate')
    identity=names[0]
    tiles=[v for v in row['children']if v['kind']=='block']
    def tile_key(tile):
     if tile['type']!='tile':raise ValueError('unexpected tileset child')
     xy=[v['value']for v in tile['children']if v['kind']=='value'and v['key']=='xy']
     if len(xy)!=1:raise ValueError('tile coordinates absent/duplicate')
     return xy[0]
    keyed(tiles,tile_key)
   else:
    if row['kind']!='value':raise ValueError('unexpected depth block')
    identity=row['key']
   if identity in entries:
    if normalized(entries[identity])!=normalized(row):raise ValueError('conflicting wrapper registration '+identity)
    continue
   entries[identity]=row
 return wrapper+'\n{\n    VERSION = '+str(version)+',\n\n'+'\n\n'.join(row['raw']for row in entries.values())+'\n}\n',list(entries)
def merge_xml(texts,package):
 rows=OrderedDict();guids={}
 for text in texts:
  root=ET.fromstring(text)
  if root.tag!='fileGuidTable':raise ValueError('wrong file GUID root')
  for child in root:
   if child.tag!='files':raise ValueError('unknown GUID element')
   path=child.findtext('path');guid=child.findtext('guid')
   if not path or not guid or '..'in Path(path).parts or Path(path).is_absolute()or not(package/path).is_file():raise ValueError('unresolved GUID path '+str(path))
   if path in rows and rows[path]!=guid:raise ValueError('conflicting GUID path')
   if guid in guids and guids[guid]!=path:raise ValueError('conflicting GUID identity')
   rows[path]=guid;guids[guid]=path
 root=ET.Element('fileGuidTable')
 for path,guid in rows.items():node=ET.SubElement(root,'files');ET.SubElement(node,'path').text=path;ET.SubElement(node,'guid').text=guid
 ET.indent(root,space='    ')
 return '<?xml version="1.0" encoding="utf-8"?>\n'+ET.tostring(root,encoding='unicode')+'\n',rows
def trait_audit(package,registry):
 traits=re.search(r'local traits\s*=\s*\{(.*?)\}',registry,re.S)
 if not traits:raise ValueError('registry trait declaration absent')
 names=re.findall(r'"([^"\n]+)"',traits[1]);assert len(names)==len(set(names))==40
 actual=package/'media/scripts/generated/characters/LS_character_traits.txt'
 ids=re.findall(r'character_trait_definition\s+Lifestyle:([^\s{]+)',actual.read_text(encoding='utf-8-sig'))
 if set(names)!=set(ids)or len(ids)!=len(set(ids)):raise ValueError('trait definition registry mismatch')
 sao=(package/'media/lua/shared/NPCs/SAO_Traits.lua').read_text(encoding='utf-8')
 own=set()
 for key in['ANCHOR','HABIT_ANCHOR']:
  block=re.search(r'T\.'+key+r'\s*=\s*\{(.*?)\}',sao,re.S)
  own.update(re.findall(r'^\s*([a-zA-Z0-9_]+)\s*=',block[1],re.M))
 # SAO clinical/substance identities and vanilla asthma/insomnia remain canonical.
 if {v.lower()for v in names}&{v.lower()for v in own}:raise ValueError('canonical semantic trait collision')
 return {'sourceTraits':names,'sourceDefinitions':str(actual),'canonicalSAOTraits':sorted(own),'vanillaReused':['ASTHMATIC','INSOMNIAC'],'semanticOverlap':[],'owner':'Lifestyle namespace registers once; original script owns its costs/effects. SAO clinical/substance and vanilla identities preserved.'}
def plan(package,report):
 grouped=OrderedDict();inputs={}
 for row in report['mergeRequired']:
  p=package/row['fragment'];data=p.read_bytes()
  if sha_bytes(data)!=row['sha256']:raise ValueError('fragment seal changed: '+str(p))
  grouped.setdefault(row['enginePath'],[]).append((row,data.decode('utf-8-sig')));inputs[str(p)]=row['sha256']
 outputs={};audit={};source_layout=None
 for relative,fragments in grouped.items():
  target=package/relative;old=target.read_bytes().decode('utf-8-sig')if target.exists()else'';texts=([old]if old else[])+[text for row,text in fragments]
  if fragments[0][0].get('kind')=='merged-translation':
   if len(fragments)!=1:raise ValueError('multiple premerged translations')
   merged=(package/fragments[0][0]['fragment']).read_bytes();incoming,wrapper=parse_translation(merged,relative)
   if relative=='media/lua/shared/Translate/EN/Sandbox.json':
    incoming=dict(incoming)
    for page,label in SAO_PAGE_LABELS.items():
     key='Sandbox_'+page
     if key in incoming and incoming[key]!=label:raise ValueError('SAO page locale collision: '+key)
     incoming[key]=label
    merged=serialize_translation(incoming,wrapper,relative)
    merged=weekone.compose_locale(merged.decode('utf-8')).encode('utf-8')
   previous,priorWrapper=parse_translation(target.read_bytes(),relative)if target.is_file()else({},wrapper)
   if priorWrapper!=wrapper or any(incoming.get(key)!=value for key,value in previous.items()):raise ValueError('canonical translation overwritten: '+relative)
   outputs[relative]=merged;audit[relative]={'kind':'exact-premerged-translation','preservesCanonicalPreimage':True,'priorKeys':len(previous),'mergedKeys':len(incoming)};continue
  if relative.endswith('sandbox-options.txt'):
   layout={};owners={};repaged=[]
   for row,fragment in fragments:
    local=source_option_layout(fragment,row['sourceId'])
    if set(layout)&set(local):raise ValueError('source option identity collision')
    layout.update(local);owners.update({name:row['sourceId'] for name in local});repaged.append(repage_options(fragment,local,True))
   if len(layout)!=156:raise ValueError('D2 source option count drift')
   source_layout={name:(owners[name],old,new)for name,(old,new)in layout.items()}
   texts=([repage_options(old,layout)]if old else[])+repaged
   text,keys=merge_header(texts,'option',1)
   text=weekone.compose_sandbox(text,parse,repage_options,merge_header)
   audit['sourceSandboxLayout']={'optionCount':len(layout),'sourceFamilies':sorted(SAO_SOURCE_PAGES),'pageCount':len(SAO_PAGE_LABELS),'optionIdsPreserved':True,'originalFragmentsUnchanged':True}
  elif relative.endswith('perks.txt'):text,keys=merge_header(texts,'perk',1)
  elif relative.endswith('tileGeometry.txt'):text,keys=merge_wrapper(texts,'tileGeometry',2)
  elif relative.endswith('tileDepthTextureAssignments.txt'):text,keys=merge_wrapper(texts,'tileDepthTextureAssignments',1)
  elif relative.endswith('fileGuidTable.xml'):text,keys=merge_xml(texts,package)
  elif relative.endswith('registries.lua'):
   if old.strip()and old.replace('\r\n','\n').strip()!=fragments[0][1].replace('\r\n','\n').strip():raise ValueError('existing registry needs explicit owner reconciliation')
   if len(fragments)!=1:raise ValueError('multiple registry producers')
   text=fragments[0][1];keys=trait_audit(package,text);audit['traitOwnership']=keys
  else:raise ValueError('unknown registration path '+relative)
  outputs[relative]=text.encode('utf-8');audit[relative]={'entries':keys,'fragmentCount':len(fragments)}
 if source_layout is not None:
  quote=lambda value:json.dumps(value,ensure_ascii=False)
  lines=['-- Generated by tools/d2_source_registration.py from sealed source option fragments.',
   'SAO=SAO or {}','SAO.SourceSandboxPages={schema="sao.source-sandbox-pages/1",options={']
  for name,(source_id,old,new)in source_layout.items():
   lines.append('['+quote(name)+']={sourceId='+quote(source_id)+',originalPage='+quote(old)+',ownedPage='+quote(new)+'},')
  lines.extend(['}}','return SAO.SourceSandboxPages',''])
  outputs['media/lua/shared/SAO_SourceSandboxPages.lua']='\n'.join(lines).encode('utf-8')
 metadata=(package/'mod.info').read_text(encoding='utf-8');existing=[v.strip()for v in metadata.splitlines()if v.startswith(('pack=','tiledef='))];declared=[v for rows in report['registrations'].values()for v in rows];missing=[]
 for line in declared:
  if line.startswith('pack='):
   name=line[5:];asset=package/'media/texturepacks'/(name+'.pack')
  elif line.startswith('tiledef='):
   name,id=line[8:].split();asset=package/'media'/(name+'.tiles')
   for current in existing+missing:
    if current.startswith('tiledef=')and current.split()[-1]==id and current!=line:raise ValueError('tiledef ID collision')
  else:raise ValueError('unknown metadata registration')
  if not asset.is_file():raise ValueError('registered asset absent: '+str(asset))
  if line not in existing and line not in missing:missing.append(line)
 metadataBytes=(package/'mod.info').read_bytes();ending=b'\r\n'if b'\r\n'in metadataBytes else b'\n'
 if missing and metadataBytes and not metadataBytes.endswith((b'\n',b'\r')):metadataBytes+=ending
 outputs['mod.info']=metadataBytes+b''.join(v.encode('utf-8')+ending for v in missing)
 audit['metadata']={'preserved':existing,'appended':missing};return outputs,audit,inputs

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--apply',action='store_true');args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 report=json.loads(args.report.read_text(encoding='utf-8'));receipt={'schema':'sao.source-registration-merge/1','status':'INCOMPLETE','report':str(args.report.resolve()),'reportSha256':sha_bytes(args.report.read_bytes())}
 try:
  outputs,audit,inputs=plan(PACKAGE,report);receipt['fragmentInputs']=inputs;receipt['audit']=audit;receipt['preimages']={};receipt['outputs']={}
  # Complete planning/conflict checks precede every canonical write.
  for relative,data in outputs.items():
   target=PACKAGE/relative;before=target.read_bytes()if target.exists()else None
   if before is not None:
    prior=out/'preimages'/relative;prior.parent.mkdir(parents=True,exist_ok=True);prior.write_bytes(before)
   receipt['preimages'][relative]={'exists':before is not None,'sha256':sha_bytes(before)if before is not None else None}
   private=out/'merged'/relative;private.parent.mkdir(parents=True,exist_ok=True);private.write_bytes(data);receipt['outputs'][relative]={'sha256':sha_bytes(data),'bytes':len(data)}
  if args.apply:
   for relative,data in outputs.items():
    target=PACKAGE/relative;prior=receipt['preimages'][relative];current=target.read_bytes()if target.exists()else None
    if (sha_bytes(current)if current is not None else None)!=prior['sha256']:raise ValueError('canonical writer drift: '+relative)
   for relative,data in outputs.items():target=PACKAGE/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
  receipt['status']='APPLIED'if args.apply else'PLANNED';receipt['canonicalFiles']=len(outputs);print(receipt['status'],len(outputs),'canonical files')
 except Exception as error:receipt['status']='FAIL';receipt['failure']=str(error);print('FAIL',error)
 (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');return 0 if receipt['status']in['APPLIED','PLANNED']else 1
if __name__=='__main__':raise SystemExit(main())
