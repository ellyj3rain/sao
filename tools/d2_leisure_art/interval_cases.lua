local n=0
local function check(name,ok)if not ok then error('D2_SOURCE_INTERVAL:'..name)end;n=n+1 end
getGameTime=function()return {getGameWorldSecondsSinceLastUpdate=function()return 1 end}end
local function make(name,id,interval)
    local body,object=fixture(id)
    local class=_G[name]
    local action
    if name=='LSCanvasAppraiseAction' then action=class:new(body,object,{quality='IGUI_PaintingQuality_Normal'},2)
    elseif name=='LSCheckYourself' then action=class:new(body,object,nil,nil,'PepTalk',800)
    else action=class:new(body,object,{},{});body.data.LSMirrorMenuOverlayPanel=true end
    check('constructor_private_interval_'..name,action.soundTimeInterval==false)
    action.animName='controlled-current-source-routine';action.animTime=1000
    action.soundType='IntriguedHmm';action.soundName='ManIntriguedHMM01'
    action.soundTime=interval;action.soundTimeInterval=interval
    body.emitter.plays=0;body.emitter.stops=0
    body.emitter.playSound=function(self,sound)self.plays=self.plays+1;return self.plays end
    body.emitter.stopSound=function(self)self.stops=self.stops+1 end
    return action,body
end
for _,name in ipairs({'LSCanvasAppraiseAction','LSCheckYourself','LSCheckYourselfAP'})do
    local first,body1=make(name,name..'-first',2)
    local second,body2=make(name,name..'-second',5)
    local previous=soundTimeInterval;soundTimeInterval='unrelated-global-sentinel'
    first:update();second:update();first:update();second:update()
    check('before_exact_boundary_'..name,body1.emitter.plays==0 and body2.emitter.plays==0)
    first:update()
    check('private_interval_advanced_'..name,first.soundTimeInterval==4 and body1.emitter.plays==1)
    check('other_action_interval_unchanged_'..name,second.soundTimeInterval==5 and body2.emitter.plays==0)
    check('global_unchanged_'..name,soundTimeInterval=='unrelated-global-sentinel')
    first:update()
    check('not_each_update_'..name,body1.emitter.plays==1)
    first:update()
    check('next_exact_repeat_'..name,body1.emitter.plays==2 and first.soundTimeInterval==6)
    second:update();second:update();second:update();second:update()
    check('independent_second_repeat_'..name,body2.emitter.plays==1 and second.soundTimeInterval==10)
    local silent,silentBody=make(name,name..'-silent',2);silent.canTalk=false
    silent:update();silent:update();silent:update()
    check('silent_schedule_without_sound_'..name,silent.soundTimeInterval==4 and silentBody.emitter.plays==0)
    local zero,zeroBody=make(name,name..'-zero',0)
    zero:update();zero:update();zero:update()
    check('zero_repeat_disabled_'..name,zeroBody.emitter.plays==0 and zero.soundTimeInterval==0)
    soundTimeInterval=previous
end
__result='PASS source intervals '..n
