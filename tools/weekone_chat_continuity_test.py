#!/usr/bin/env python3
"""Week One source chat enters one heard person before source actuation."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

WORKSHOP_CHAT = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600") / (
    "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/BWOChat.lua")
CHAT_PIN = "10527d5d89115c2b6bb532a7604809e9b30d1625d7759f887bc43b1c275c43ad"

FIXTURE = r'''
__spoken={} __answers={} __programs={} __stages={} __groups={}
__heard=true __standing=.8 __trust=.8 __hostile=false __registered={} __bodies={}
ModData.get=function(k) return __stores[k] end
BanditZombie.GetInstanceById=function(id) return __bodies[id] end
__player.Say=function(self,text) __spoken[#__spoken+1]=text end
__player.isDead=function() return false end
SAO.Standing.playerKey=function(player)
 if player==__player then return 'player:active' end end
SAO.Standing.groupOf=function(id) return __groups[id] end
SAO.Standing.trust=function() return __trust end
SAO.Standing.companyStanding=function() return __standing end
SAO.Standing.isHostileTo=function() return __hostile end
SAO.Standing.adjustTrust=function(id,other,delta)
 __trust=__trust+delta return __trust end
SAO.Standing.setHostile=function(id,other,value) __hostile=value end
SAO.Disposition.hostilityBar=function() return -.5 end
SAOJavaBridge.weekOneCanHearPlayer=function(self,player,body,id,brainId,born)
 return __heard and player==__player and body.md.SAOWeekOneOrigin=='BanditsWeekOne'
  and body.md.SAOWeekOnePersonId==id and body.md.SAOWeekOneBrainId==brainId
  and body.md.SAOWeekOneBorn==born and body:getPersistentOutfitID()==brainId
end
BanditBrain={Get=function(body) return __registered[body.id] end}
Bandit={
 SetProgram=function(body,name)
  local brain=BanditBrain.Get(body)
  brain.program={name=name,stage='Prepare'}
  __programs[#__programs+1]=name
 end,
 SetProgramStage=function(body,stage)
  local brain=BanditBrain.Get(body)
  brain.program.stage=stage
  __stages[#__stages+1]=stage
 end,
}
function __actor(id,origin)
 local brain=__brain(id,origin or 'BanditsWeekOne')
 brain.program={name='Walker',stage='Main'}
 brain.tasks={}
 local body=__body(id)
 body.addLineChatElement=function(self,text)
  __answers[#__answers+1]=text end
 __registered[id]=brain
 __bodies[id]=body
 return brain,body
end
function __move(brain,personId,action)
 local phase=__records[personId].weekOne
 phase.decision={kind='ordinary',source='sao-person-and-native-feature',
  actionOwner='BanditsWeekOne',atTick=__tick}
 local task={action=action or 'Move',time=115,endurance=0,x=81,y=80,z=0,
  walkType='Walk',closeSlow=false,saoWeekOnePersonId=personId,
  saoWeekOneBrainId=brain.id,saoWeekOneBorn=brain.born,
  saoWeekOneAtTick=__tick}
 brain.tasks={task}
 return brain.tasks,task
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local brain,body=__actor(701)
local wrong,wrongBody=__actor(702)
local duplicate=__brain(701,'BanditsWeekOne')
duplicate.program={name='Walker',stage='Main'}
local count=function() return #__programs end

__step='foreign'
assert(W.onSourceChat(__brain(703,'Bandits2'),__body(703),__player,'follow me')==false
 and #__spoken==0 and count()==0,'foreign actor admitted through SAO chat')

__step='exact-brain'
assert(W.onSourceChat(wrong,body,__player,'follow me')==false
 and #__spoken==0 and count()==0,'wrong source brain acted on another body')
assert(W.onSourceChat(duplicate,body,__player,'follow me')==false
 and #__spoken==0 and count()==0,'wrong source brain acted on another body')

__step='unheard'
__heard=false
local unheared,why=W.onSourceChat(brain,body,__player,'follow me')
local id=body.md.SAOWeekOnePersonId
assert(unheared==false and why=='not-heard' and #__spoken==1
 and not __records[id].weekOne.lastSpeech and count()==0,
 'unheard speech became accepted request')

__step='source-body-exact'
local resolved,sourceBrain=W.sourceBodyFor(id)
assert(resolved==body and sourceBrain==brain,
 'exact source body was not exposed to common person observation')
local savedBorn=body.md.SAOWeekOneBorn
body.md.SAOWeekOneBorn=-1
assert(W.sourceBodyFor(id)==nil,'body marker inverse resolved a source proxy')
body.md.SAOWeekOneBorn=savedBorn
local row=__stores.SurvivorAwareness_WeekOneContinuity.byBrain[tostring(brain.id)]
local savedRowPerson=row.personId row.personId='another-person'
assert(W.sourceBodyFor(id)==nil,'crosswalk inverse resolved another person')
row.personId=savedRowPerson
local phase=__records[id].weekOne
phase.pending={}
assert(W.sourceBodyFor(id)==nil,'pending transfer exposed source body')
phase.pending=nil phase.status='transferred'
assert(W.sourceBodyFor(id)==nil,'transferred person exposed source body')
phase.status='external'
brain.saoWeekOneOrigin='Bandits2'
assert(W.sourceBodyFor(id)==nil,'foreign brain exposed source body')
brain.saoWeekOneOrigin='BanditsWeekOne'
local savedBody=__bodies[brain.id] __bodies[brain.id]=wrongBody
assert(W.sourceBodyFor(id)==nil,'wrong cached body exposed source body')
__bodies[brain.id]=savedBody

__step='unheard-with-owned-queue'
local waiting,move=__move(brain,id)
local unheardQueued=W.onSourceChat(brain,body,__player,'follow me')
assert(unheardQueued==false and brain.tasks==waiting and brain.tasks[1]==move
 and brain.program.name=='Walker' and count()==0,
 'unheard request discarded owned work')

__step='unavailable'
__heard=true
local native=SAOJavaBridge.weekOneCanHearPlayer
SAOJavaBridge.weekOneCanHearPlayer=nil
local unavailable,reason=W.onSourceChat(brain,body,__player,'follow me')
assert(unavailable==false and reason=='native-hearing-unavailable'
 and not __records[id].weekOne.lastSpeech and count()==0,
 'absent native hearing became reception')
SAOJavaBridge.weekOneCanHearPlayer=native

__step='quiet'
local before=#__spoken
local quiet,quietReason=W.onSourceChat(brain,body,__player,'xhornx',true)
assert(quiet==false and quietReason=='source-quiet-unverified'
 and #__spoken==before and count()==0,
 'quiet horn input fabricated spoken words')

__step='greeting'
local heard,answer=W.onSourceChat(brain,body,__player,'Hello!')
assert(heard==true and answer=='answered' and #__spoken==before+1
 and #__answers==1 and __answers[1]=='Hello.'
 and __records[id].weekOne.lastSpeech.intent=='greeting'
 and count()==0,'heard greeting lacked person response')

__step='refused-join'
__standing=.2
local refusedQueue,refusedMove=__move(brain,id)
local refused,choice=W.onSourceChat(brain,body,__player,'Follow me!')
assert(refused==true and choice=='refused' and count()==0
 and brain.tasks==refusedQueue and brain.tasks[1]==refusedMove
 and not __records[id].weekOne.chatCompanion
 and not __groups[id] and not brain.permanent and not brain.loyal,
 'low-standing request made a companion or group')

__step='join-setter-failure'
__standing=.8
local originalProgramSetter=Bandit.SetProgram
Bandit.SetProgram=function(body,name)
 brain.program={name=name,stage='Prepare'} error('program setter failed') end
local failedJoin,failedJoinDecision=W.onSourceChat(brain,body,__player,'Follow me!')
assert(failedJoin and failedJoinDecision=='refused' and brain.program.name=='Walker'
 and brain.program.stage=='Main' and brain.tasks==refusedQueue
 and brain.tasks[1]==refusedMove and not __records[id].weekOne.chatCompanion
 and count()==0 and __records[id].weekOne.lastSpeech.decision=='refused',
 'failed join setter changed the program, queue or person relationship')
Bandit.SetProgram=originalProgramSetter

__step='same-group-refusal'
__groups[id]='player-camp' __groups['player:active']='player-camp'
local groupQueue,groupMove=__move(brain,id)
local sameGroup,sameGroupDecision=W.onSourceChat(brain,body,__player,'Follow me!')
assert(sameGroup and sameGroupDecision=='refused' and count()==0
 and brain.tasks==groupQueue and brain.tasks[1]==groupMove
 and not __records[id].weekOne.chatCompanion,
 'same-group source company was accepted without ordinary continuation')
__groups[id]=nil __groups['player:active']=nil

__step='accepted-join'
local joined,joinDecision=W.onSourceChat(brain,body,__player,'Follow me!')
assert(joined and joinDecision=='accepted' and count()==1
 and brain.program.name=='Walker' and brain.program.stage=='Prepare'
 and #brain.tasks==0 and brain.tasks~=refusedQueue
 and __records[id].weekOne.chatCompanion.playerKey=='player:active'
 and __records[id].weekOne.chatMode=='follow'
 and not __groups[id] and not __groups['player:active']
 and not brain.permanent and not brain.loyal,
 'heard accepted company did not retain the neutral source actuator')

__step='relationship-independent-of-source-label'
brain.program={name='Janitor',stage='Main'}
local labelQueue=__move(brain,id)
local labelHeld,labelDecision=W.onSourceChat(brain,body,__player,'Stay here')
assert(labelHeld and labelDecision=='accepted' and count()==2
 and brain.program.name=='Walker' and brain.tasks~=labelQueue
 and __records[id].weekOne.chatMode=='hold',
 'persisted SAO companion lost control after source role changed')
__programs[#__programs]=nil
__records[id].weekOne.chatMode='follow'

__step='protected-queue'
local prior=brain.program
local protected={
 {name='locked',task={lock=true}},
 {name='untagged',task={saoWeekOnePersonId=false}},
 {name='foreign',task={saoWeekOnePersonId='bwo-another'}},
 {name='action',task={action='SAOWaterFlowerbed'}},
 {name='source-use',task={action='SourceUse'}},
 {name='foreign-field',task={sourceUse=true}},
}
for _,case in ipairs(protected) do
 local queue,task=__move(brain,id)
 for key,value in pairs(case.task) do task[key]=value end
 local allowed,decision=W.onSourceChat(brain,body,__player,'Stay here')
 assert(allowed and decision=='refused' and brain.program==prior
  and brain.program.stage=='Prepare' and brain.tasks==queue
  and brain.tasks[1]==task and #__stages==0,
  'protected '..case.name..' task was discarded or source program changed')
end

__step='setter-failure'
local failedQueue,failedMove=__move(brain,id)
Bandit.SetProgram=function(body,name)
 brain.program={name=name,stage='Prepare'} error('setter failed after mutation') end
local failed,failureDecision=W.onSourceChat(brain,body,__player,'Stay here')
assert(failed and failureDecision=='refused' and brain.program==prior
 and brain.program.stage=='Prepare' and brain.tasks==failedQueue
 and brain.tasks[1]==failedMove and #__stages==0
 and __records[id].weekOne.lastSpeech.decision=='refused',
 'setter failure left an accepted receipt or changed program/queue')
Bandit.SetProgram=originalProgramSetter

__step='setter-unconfirmed'
local unconfirmedQueue,unconfirmedMove=__move(brain,id)
Bandit.SetProgram=function(body,name)
 brain.program={name=name,stage='Main'} end
local unconfirmed,unconfirmedDecision=W.onSourceChat(brain,body,__player,'Stay here')
assert(unconfirmed and unconfirmedDecision=='refused' and brain.program==prior
 and brain.program.stage=='Prepare' and brain.tasks==unconfirmedQueue
 and brain.tasks[1]==unconfirmedMove and #__stages==0,
 'unconfirmed source stage made an accepted receipt or changed queue')
Bandit.SetProgram=originalProgramSetter

__step='reload-hold'
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
local holdQueue=__move(brain,id)
local held,holdDecision=W.onSourceChat(brain,body,__player,"Don't follow me")
assert(held and holdDecision=='accepted' and brain.program.name=='Walker'
 and brain.program.stage=='Prepare'
 and #brain.tasks==0 and brain.tasks~=holdQueue
 and __records[id].weekOne.chatMode=='hold' and count()==2 and #__stages==0,
 'save-compatible person relationship did not hold')

__step='resume-follow'
local followQueue=__move(brain,id,'GoTo')
local followed,followDecision=W.onSourceChat(brain,body,__player,'Follow me')
assert(followed and followDecision=='accepted' and brain.program.name=='Walker'
 and brain.program.stage=='Prepare'
 and #brain.tasks==0 and brain.tasks~=followQueue
 and __records[id].weekOne.chatMode=='follow' and count()==3 and #__stages==0,
 'held person did not resume following after own judgment')

__step='go-home'
local homeQueue=__move(brain,id)
local home,homeDecision=W.onSourceChat(brain,body,__player,'Go home')
assert(home and homeDecision=='accepted' and brain.program.name=='Walker'
 and brain.program.stage=='Prepare' and #brain.tasks==0
 and brain.tasks~=homeQueue and __records[id].weekOne.chatMode=='home'
 and count()==4 and #__stages==0,'accepted home left old move ahead of new program')

__step='leave'
local leaveQueue=__move(brain,id)
Bandit.SetProgram=function(body,name)
 brain.program={name=name,stage='Prepare'} error('program setter failed') end
local failedLeave,failedLeaveDecision=W.onSourceChat(brain,body,__player,'Go away')
assert(failedLeave and failedLeaveDecision=='refused'
 and brain.program.name=='Walker' and brain.program.stage=='Prepare'
 and brain.tasks==leaveQueue and #brain.tasks==1
 and __records[id].weekOne.chatMode=='home' and count()==4,
 'failed leave setter changed the source or person relationship')
Bandit.SetProgram=originalProgramSetter
local left,leaveDecision=W.onSourceChat(brain,body,__player,'Go away')
assert(left and leaveDecision=='accepted' and brain.program.name=='Walker'
 and brain.program.stage=='Prepare' and #brain.tasks==0
 and brain.tasks~=leaveQueue
 and __records[id].weekOne.chatCompanion==nil
 and __records[id].weekOne.chatMode==nil and count()==5,
 'leave retained source or person companionship')

__step='unearned-hold'
local heldAlone,aloneDecision=W.onSourceChat(brain,body,__player,'Stay here')
assert(heldAlone and aloneDecision=='refused' and brain.program.name=='Walker'
 and #__stages==0,'former companion obeyed an unearned hold')

__step='hidden-kill'
local shutdown,shutdownDecision=W.onSourceChat(brain,body,__player,'shutdown now')
assert(shutdown and shutdownDecision=='uninterpreted' and body.alive
 and brain.program.name=='Walker' and count()==5,
 'source hidden kill became a person action')

__step='group-conflict'
__groups[id]='existing-house'
local conflict,conflictDecision=W.onSourceChat(brain,body,__player,'Join my team')
assert(conflict and conflictDecision=='refused' and count()==5
 and __groups[id]=='existing-house',
 'request displaced an existing person group')
__groups[id]=nil

__step='threat'
__trust=-.4
local threatened,threatAnswer=W.onSourceChat(brain,body,__player,'I will kill you')
assert(threatened and threatAnswer=='answered' and __hostile
 and __records[id].weekOne.lastSpeech.intent=='threat'
 and count()==5 and body.alive,
 'heard explicit threat did not use private Standing threshold')

__step='selected-emote-phrases'
__trust=.8 __hostile=false __standing=.8
for i,phrase in ipairs(__FOLLOW_EMOTE_PHRASES__) do
 local emoteBrain,emoteBody=__actor(900+i)
 local received,decision=W.onSourceChat(emoteBrain,emoteBody,__player,phrase)
 local emoteId=emoteBody.md.SAOWeekOnePersonId
 assert(received and decision=='accepted' and emoteBrain.program.name=='Walker'
  and __records[emoteId].weekOne.lastSpeech.intent=='join',
  'selected source follow emote failed heard person judgment: '..phrase)
end
for i,phrase in ipairs(__WAVE_EMOTE_PHRASES__) do
 local emoteBrain,emoteBody=__actor(950+i)
 local received,decision=W.onSourceChat(emoteBrain,emoteBody,__player,phrase)
 local emoteId=emoteBody.md.SAOWeekOnePersonId
 assert(received and decision=='answered' and emoteBrain.program.name=='Walker'
  and __records[emoteId].weekOne.lastSpeech.intent=='greeting',
  'selected source greeting emote lost native response: '..phrase)
end

return 'PASS'
'''

CONTROLS = [
    ("source-role-independence", 'and companion.source == "heard-player-request"',
     'and false', "persisted SAO companion lost control after source role changed"),
    ("native-hearing", 'if not okHeard or heard ~= true then return false, "not-heard" end',
     'if false then return false, "not-heard" end',
     "unheard speech became accepted request"),
    ("source-brain", 'if not okBrain or selected ~= brain then return false, "brain-mismatch" end',
     'if false then return false, "brain-mismatch" end',
     "wrong source brain acted on another body"),
    ("standing-judgment", 'or standing <= bar)',
     'or standing > bar)',
     "low-standing request made a companion or group"),
    ("same-group-judgment", 'if actorGroup then',
     'if false then',
     "same-group source company was accepted without ordinary continuation"),
    ("follow-emote-lexicon", '["accompany me"] = "join"',
     '["accompany me"] = "conversation"',
     "selected source follow emote failed heard person judgment"),
    ("greeting-emote-lexicon", 'or words == "greetings" then return "greeting" end',
     'then return "greeting" end',
     "selected source greeting emote lost native response"),
    ("quiet-speech", 'if quiet == true then return false, "source-quiet-unverified" end',
     'if false then return false, "source-quiet-unverified" end',
     "quiet horn input fabricated spoken words"),
    ("leave-continuity", 'phase.chatCompanion, phase.chatMode = nil, nil',
     'do end', "leave retained source or person companionship"),
    ("exact-disposable-task", 'or task.saoWeekOnePersonId ~= rec.id',
     'or false', "protected untagged task was discarded or source program changed"),
    ("action-task", 'or task.action ~= "Move" and task.action ~= "GoTo"',
     'or false',
     "protected action task was discarded or source program changed"),
    ("effective-queue-transition", 'local cleared = pcall(function() brain.tasks = {} end)',
     'local cleared = pcall(function() do end end)',
     "heard accepted company did not retain the neutral source actuator"),
    ("body-marker", 'and md.SAOWeekOneBorn == brain.born\n    end)\n    if not marked',
     'and true\n    end)\n    if not marked',
     "body marker inverse resolved a source proxy"),
]


def main() -> int:
    paths = [SOURCE, WORKSHOP_CHAT, GAME / "projectzomboid.jar",
             GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in paths):
        raise SystemExit("missing installed engine or exact Week One chat source")
    chat_hash = hashlib.sha256(WORKSHOP_CHAT.read_bytes()).hexdigest()
    if chat_hash != CHAT_PIN:
        raise RuntimeError(f"installed Week One chat source drifted: {chat_hash}")
    selected_chat = WORKSHOP_CHAT.read_text(encoding="utf-8")
    def emote_phrases(name: str) -> list[str]:
        choice = re.search(r'emote2txt\["' + re.escape(name)
                           + r'"\]\s*=\s*BanditUtils\.Choice\(\{(.*?)\}\)',
                           selected_chat, re.S)
        if not choice:
            raise RuntimeError(f"installed Week One {name} emote source moved")
        phrases = re.findall(r'"([^"\r\n]+)"', choice.group(1))
        if not phrases or len(phrases) > 32:
            raise RuntimeError(f"installed Week One {name} emote values invalid")
        return phrases
    follow_phrases = emote_phrases("followme")
    wave_phrases = emote_phrases("wavehi")
    source = SOURCE.read_text(encoding="utf-8")
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "installedChatSha256": chat_hash,
               "selectedEmotePhrases": {"followme": len(follow_phrases),
                                        "wavehi": len(wave_phrases)}, "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-chat-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + FIXTURE, encoding="utf-8")
        selected_cases = CASES.replace("__FOLLOW_EMOTE_PHRASES__",
            "{" + ",".join(json.dumps(value) for value in follow_phrases) + "}")
        selected_cases = selected_cases.replace("__WAVE_EMOTE_PHRASES__",
            "{" + ",".join(json.dumps(value) for value in wave_phrases) + "}")
        (work / "cases.lua").write_text(
            "function __cases()\n" + selected_cases + "\nend\n"
            "function __safe() local ok,value=pcall(__cases) "
            "if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")

        def run(name: str, current: str) -> tuple[int, str]:
            (work / "sao.lua").write_text(current, encoding="utf-8")
            (work / "reload.lua").write_text(
                "function __reloadWeekOne()\n" + current + "\nend\n",
                encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "sao.lua"),
                str(work / "reload.lua"), str(work / "cases.lua"),
                "--", "__safe()"], cwd=work, capture_output=True,
                text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                     "output": output[-1200:]})
            return done.returncode, output

        code, output = run("current", source)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("Week One chat current failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " inverse failed incorrectly: " + output)
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/chat-continuity.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One heard chat and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
