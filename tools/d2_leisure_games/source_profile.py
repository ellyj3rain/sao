"""Exact source profiles for isolated NPC computer and ping-pong engines."""
from pathlib import Path
import hashlib,os,re
COMPUTER=Path(os.environ.get('COMPUTER_LUA',r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3725497089/mods/ComputerMod/42/media/lua'))
LIFESTYLE=Path(os.environ.get('LIFESTYLE_LUA',r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3403870858/mods/Lifestyle/common/media/lua'))
ARCADE=Path(r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3645980077/mods/ProjectArcade/common/media/lua')
IDS={'Pong':'pong','Snake':'snake','Minesweeper':'minesweeper','Tetris':'tetris','SpaceInvaders':'space_invaders','Doom':'doom','Racer':'racer','Flappy':'flappy','Breakout':'breakout','Asteroids':'asteroids','Frogger':'frogger','MissileCommand':'missile','LunarLander':'lander','CircuitRunner':'circuit','MemoryMatch':'memory','StarPilot':'starpilot','CaveRunner':'caverunner','LightsOut':'lightsout','SignalMatch':'signalmatch','BoxPush':'boxpush','TileSlide':'tileslide','PipeLink':'pipelink','CodeBreaker':'codebreaker','OutbreakOps':'outbreakops'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def games():
    out=[]
    for stem,id in IDS.items():
        path=COMPUTER/f'client/ComputerMod_eLua{stem}.lua';text=path.read_text(encoding='utf-8-sig')
        classname=re.search(r'(PZ\w+) = ISPanel:derive',text).group(1)
        keys=sorted(set(re.findall(r'ComputerModGameInput\.isDown\(self, "(\w+)"\)',text)))
        if 'updateGridSelection' in text:keys=sorted(set(keys+['up','down','left','right','action','secondary']))
        # Class identity is lexical; all source code and game mechanics remain.
        original=classname+' = ISPanel:derive';assert text.count(original)==1
        text=text.replace(original,'local '+original,1)
        block='GameClasses['+repr(id)+'] = (function()\n'+text+'\nreturn '+classname+'\nend)()\n'
        out.append((id,classname,path,keys,block))
    return out
def grid():
    p=COMPUTER/'client/ComputerMod_GameInput.lua';text=p.read_text(encoding='utf-8-sig')
    return text[text.index('function ComputerModGameInput.updateGridSelection('):text.index('function ComputerModGameInput.drawGamepadSelection(')]
def labels():
    text=(COMPUTER/'client/ComputerMod_GameInput.lua').read_text(encoding='utf-8-sig')
    return text[text.index('ComputerModGameInput.profileOrder ='):text.index('local function getRoot')]+text[text.index('function ComputerModGameInput.getProfileName'):text.index('function ComputerModGameInput.getJoypadId')]+text[text.index('function ComputerModGameInput.getInputLabel'):]
def mood_original():
    text=(COMPUTER/'client/ComputerMod_UI_State.lua').read_text(encoding='utf-8-sig')
    return text[text.index('local function clampComputerMood'):text.index('ComputerModGameMoodEventHandler =')]
def mood():
    return 'local ComputerMood=(function()\nlocal target={}\nlocal ComputerScreenUI={}\n'+mood_original()+'''
target.__index=target
function target:isVisible()return current and current.body==self.playerObj and owned(current)end
function target:isGameView()return true end
function target:getActiveGameInstance()return self.game end
return {new=function(body,game)return setmetatable({playerObj=body,game=game},target)end,
    update=function(ui)ComputerScreenUI.instance=ui;updateComputerGameMoodFromPlayer(ui.playerObj);ComputerScreenUI.instance=nil end}
end)()
'''
def arcade():
    path=ARCADE/'client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua'
    text=path.read_text(encoding='utf-8-sig')
    original='ProjectArcade_PlayArcadeTimedAction = ISBaseTimedAction:derive'
    assert text.count(original)==1;text=text.replace(original,'local '+original,1)
    # Exact two source-owner bindings qualified by the native Arcade consumer proof.
    original='local function getLoopDurationMs(soundName)\n    if soundName == "PAMsfplay" then return 46000 end\n    if soundName == "PAMdroidsplay" then return 30000 end\n    if soundName == "PAMpinballplay" then return 29000 end\n    if soundName == "PAddplay" then return 58000 end\n\tif soundName == "PAsiplay" then return 38000 end \n    if soundName == "PAafplay" then return 50000 end\n    if soundName == "PAtzplay" then return 53000 end\n    if soundName == "PAijplay" then return 60500 end\n\tif soundName == "PAdkplay" then return 55000 end\n    if soundName == "PAt2play" then return 60000 end\n    if soundName == "PAcenplay" then return 60000 end\n    if soundName == "PAdigplay" then return 64000 end\n    if soundName == "PAnbaplay" then return 62000 end\n    if soundName == "PAtmntplay" then return 62000 end\n    if soundName == "PAmkplay" then return 60000 end\n    if soundName == "PAfhplay" then return 60000 end\n    if soundName == "PAbk2000play" then return 70000 end\n    if soundName == "PAetpmplay" then return 60000 end\n    if soundName == "PAswplay" then return 60000 end\n    if soundName == "PAmbplay" then return 60000 end\n\n    return 25000\nend'
    replacement='local function getLoopDurationMs(soundName)\n    local policy = require "ProjectArcade_SoundPolicy"\n    return policy.getLoopDurationMs(soundName)\nend'
    assert text.count(original)==1
    text=text.replace(original,replacement,1)
    original='    if ArcadeAmbientSound and ArcadeAmbientSound.suppressForObject then'
    replacement='    local ArcadeAmbientSound = require "ProjectArcade_ArcadeAmbientSound"\n    if ArcadeAmbientSound and ArcadeAmbientSound.suppressForObject then'
    assert text.count(original)==1
    text=text.replace(original,replacement,1)
    menu=(ARCADE/'client/ProjectArcade_PAMPlayGameMenu.lua').read_text(encoding='utf-8-sig')
    power=menu[menu.index('local function machineHasPower'):menu.index('local function doBuildMenu')]
    return 'local ArcadeSource=(function()\n'+text+'\n'+power+'\nreturn {class=ProjectArcade_PlayArcadeTimedAction,machineType=getArcadeMachineType,front=getInteractionTileForRecreational,overlay=PA_SetArcadeScreenOverlay,power=machineHasPower}\nend)()\n'
def currency():
    text=(ARCADE/'client/ProjectArcade_Currency.lua').read_text(encoding='utf-8-sig')
    original='ProjectArcade_Currency = ProjectArcade_Currency or {}'
    assert text.count(original)==1;text=text.replace(original,'local ProjectArcade_Currency = {}',1)
    for line in ['Events.OnGameStart.Add(PA_Currency_ApplySandboxOnStart)','Events.OnServerCommand.Add(onServerCommand)']:
        assert text.count(line)==1;text=text.replace(line,'-- Original player/server event registration remains with the installed owner.',1)
    return 'local ProjectArcade_Currency=(function()\n'+text+'\nPA_Currency_ApplySandboxOnStart()\nreturn ProjectArcade_Currency\nend)()\n'
def ping():
    p=LIFESTYLE/'shared/TimedActions/LSPingPong.lua';text=p.read_text(encoding='utf-8-sig')
    text=text[text.index('LSPingPong = ISBaseTimedAction:derive'):]
    text=text.replace('LSPingPong = ISBaseTimedAction:derive','local LSPingPong = ISBaseTimedAction:derive',1)
    text=text.replace('if character and character.Say then character:Say(anim); end','-- Source debug animation-name speech is retained as the real action animation.')
    text=text.replace('if character and character.Say then character:Say(swingAnim_miss); end','-- Source debug animation-name speech is retained as the real action animation.')
    return 'local PingCore=(function()\n'+text+'\nend)()\n'
def ping_rules():
    p=LIFESTYLE/'shared/MPSocial/social_utils.lua';text=p.read_text(encoding='utf-8-sig')
    return 'local MatchRules=(function()\nlocal LSMPS={}\n'+text[text.index('LSMPS.getPingPongForm ='):text.index('LSMPS.getPingPongKey =')]+'\nreturn LSMPS\nend)()\n'
def ball():
    path=LIFESTYLE/'client/ISUI/LSPingPongBall.lua';text=path.read_text(encoding='utf-8-sig')
    constants=text[text.index('local driftDistance'):text.index('function LSPingPongBall:updateRGB')]
    setter=text[text.index('function LSPingPongBall:setShot'):text.index('function LSPingPongBall:prerender')]
    setter=setter.replace('function LSPingPongBall:setShot','local function sourceSetShot',1).replace('sourceSetShot(shot)','sourceSetShot(self,shot)',1)
    position=text[text.index('\tlocal t = self.t',text.index('function LSPingPongBall:render')):text.index('\tlocal screenX, screenY =')]
    scale=text[text.index('\tlocal overallT ='):text.index('\tlocal texW, texH =')]
    ctor=text[text.index('function LSPingPongBall:new'):]
    ctor=ctor.replace('\to.playerNum = character:getPlayerNum()','\t-- NPC scene has no player camera/slot.',1)
    return 'local LSPingPongBall=(function()\nlocal LSPingPongBall=ISPanel:derive("SAONpcPingBall")\n'+constants+setter+ctor+'''
function LSPingPongBall:setShot(shot)
    if not current or not owned(current)then error("unbound-source-ping-shot")end
    sourceSetShot(self,shot)
    current.shot=plain(shot);current.work.nativeProgress.shots=(current.work.nativeProgress.shots or 0)+1
    current.work.nativeProgress.ballPosition=self:position()
end
function LSPingPongBall:position()
'''+position+scale+'''
    return {x=wx,y=wy,z=self.z,arcPixels=arc,lateralPixels=lateral,depthScale=depthScale,alpha=self.alpha}
end
function LSPingPongBall:setVisible()end
function LSPingPongBall:addToUIManager()end
function LSPingPongBall:close()self.shouldClose=true end
return LSPingPongBall
end)()
'''
if __name__=='__main__':
    for id,cls,path,keys,_ in games():
        text=path.read_text();print(id,cls,keys,sorted(set(re.findall(r'gameState\s*=\s*"(\w+)"',text))))
