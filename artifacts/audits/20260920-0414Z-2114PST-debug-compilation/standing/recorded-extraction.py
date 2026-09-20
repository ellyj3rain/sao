# Recorded extraction command from exec output ed39ed. This is the original
# mutating transformation, preserved for audit; do not rerun on the repaired tree.
from pathlib import Path
import hashlib,json,subprocess
p=Path('mod/42.20/media/lua/shared/SAO_Standing.lua')
s=p.read_text(encoding='utf-8')
original=subprocess.run(['git','show','HEAD:'+p.as_posix()],capture_output=True,check=True).stdout.decode('utf-8')
assert s==original,'Standing has existing changes; refusing unreviewed baseline'
parts=[
('updateElectionCreed','s, groupName','    -- [B23] The turn of a house.','    -- [B23] A division that goes somewhere.'),
('applyElectionDivision','groupName, members','    -- [B23] A division that goes somewhere.','    -- [C117] The afflicted member in the room.'),
('applyAfflictedDispute','groupName, members','    -- [C117] The afflicted member in the room.','    -- [B21] The work is JUDGED.'),
('reviewElectionWork','s, groupName, members','    -- [B21] The work is JUDGED.','    -- The political economy of scale'),
]
helpers=[];record=[]
for name,args,start,end in parts:
 a=s.index(start);b=s.index(end,a);body=s[a:b]
 helper='local function '+name+'('+args+')\n'+body+'end\n\n'
 call='    '+name+'('+args+')\n'
 s=s[:a]+call+s[b:];helpers.append(helper)
 record.append({'name':name,'parameters':args,'body_lines':len(body.splitlines()),'body_sha256':hashlib.sha256(body.encode()).hexdigest(),'body':body,'helper':helper,'call':call})
insert=''.join(helpers)
s=s.replace('function S.electLeader(groupName)',insert+'function S.electLeader(groupName)',1)
reconstructed=s.replace(insert,'',1)
for r in record:
 assert reconstructed.count(r['call'])==1
 reconstructed=reconstructed.replace(r['call'],r['body'],1)
assert reconstructed==original
p.write_text(s,encoding='utf-8',newline='\n')
print(json.dumps({'reconstruction_equals_head':True,'original_sha256':hashlib.sha256(original.encode()).hexdigest(),'refactored_sha256':hashlib.sha256(s.encode()).hexdigest(),'phases':[{k:v for k,v in r.items() if k not in ['body','helper','call']} for r in record]},indent=2))
