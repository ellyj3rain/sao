__helperRequires={};__helperLoads={};__eventAdds={};__emissions={};__emitters={};__ambientTargets={}
for _,name in ipairs({'OnTickEvenPaused','OnPostMapLoad'})do
 Events[name]={Add=function(fn)__eventAdds[name]=(__eventAdds[name]or 0)+1 end}
end
__oldRequire=require
function require(name)
 if name=='ProjectArcade_SoundPolicy' or name=='ProjectArcade_ArcadeAmbientSound' then
  __helperRequires[name]=(__helperRequires[name]or 0)+1
  if __forbidNewModules then error('ARCADE_BINDING:inactive_eager_module_'..name)end
  __libraries=__libraries or{}
  if __libraries[name]==nil then
   __helperLoads[name]=(__helperLoads[name]or 0)+1
   local owner=assert(__helperFactories[name])()
   if name=='ProjectArcade_ArcadeAmbientSound' then
    local original=owner.suppressForObject
    owner.suppressForObject=function(obj)__ambientTargets[#__ambientTargets+1]=obj;return original(obj)end
   end
   __libraries[name]=owner
  end
  return __libraries[name]
 end
 return __oldRequire(name)
end
GameSounds={getSound=function(name)return{getRandomClip=function()return{name=name,getVolume=function()return 0.8 end}end}end}
IsoWorld={instance={getFreeEmitter=function()
 local e={id=#__emitters+1,playing={}};__emitters[#__emitters+1]=e
 function e:setPos(x,y,z)self.pos={x,y,z}end
 function e:playClip(clip)local id=#__emissions+1;__emissions[id]={clip=clip,pos=self.pos,emitter=self};self.playing[id]=true;return id end
 function e:setVolume(id,v)__emissions[id].volume=v end
 function e:set3D(id,v)__emissions[id].is3D=v end
 function e:tick()end
 function e:isPlaying(id)return self.playing[id]==true end
 function e:stopSound(id)self.playing[id]=nil end
 function e:stopAll()self.playing={}end
 return e
end}}
function foreignAmbientOwner()error('ARCADE_BINDING:foreign_ambient_consulted')end
ArcadeAmbientSound={suppressForObject=foreignAmbientOwner}
SAO.SourceIntegration.active=function()return false end
SAO.SourceIntegration.available=SAO.SourceIntegration.active
__forbidNewModules=true
