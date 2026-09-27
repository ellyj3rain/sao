-- Controlled native receivers for the whole Body/Snapshot/Pharmacology join.
-- The separate pharmacology probe proves the installed native receivers.
CharacterStat=setmetatable({}, {__index=function(self,name)
 local high=({HUNGER=1,THIRST=1,FATIGUE=1,ENDURANCE=1,STRESS=1})[name] or 100
 local stat={name=name,getMinimumValue=function() return 0 end,
   getMaximumValue=function() return high end}
 self[name]=stat return stat
end})
BodyPartType={Head='Head',ToString=function(value) return tostring(value) end}
local oldBody=__body
function __body()
 local b=oldBody()
 b.values={FATIGUE=.4,ENDURANCE=.8,HUNGER=.2,THIRST=.3}
 local stats={}
 function stats:get(stat) return b.values[stat.name] or 0 end
 function stats:set(stat,value)
  if __failStat==stat.name then error('controlled native stat failure') end
  __statWrites=(__statWrites or 0)+1
  b.values[stat.name]=math.max(stat:getMinimumValue(),math.min(stat:getMaximumValue(),value))
 end
 function stats:add(stat,value) self:set(stat,self:get(stat)+value) end
 function stats:remove(stat,value) self:set(stat,self:get(stat)-value) end
 function b:getStats() return stats end
 function b:isDead() return self.dead==true end
 local part={pain=0,stiffness=0}
 function part:getAdditionalPain() return self.pain end
 function part:getPain() return self.pain end
 function part:setAdditionalPain(value) self.pain=value end
 function part:getStiffness() return self.stiffness end
 function part:setStiffness(value) self.stiffness=value end
 function part:getType() return 'Head' end
 function b:getBodyDamage() return {getBodyPart=function() return part end,
   getBodyParts=function() return {size=function() return 1 end,get=function() return part end} end} end
 function b:getFitness() return {removeStiffnessValue=function() end} end
 function b:getCharacterTraits() return {set=function() end} end
 return b
end
local oldSetup=__setup
function __setup()
 __failStat=nil __statWrites=0
 local rec,body,agent=oldSetup()
 body.md.SAOPersonId=rec.id
 return rec,body,agent
end
function __foreign(rec,body,token)
 token=token or 'transaction-owner'
 rec.bodyOwner='ZAO' rec.bodyOwnerToken=token
 SAO.Body.active[rec.id]=nil SAO.Body.foreign[rec.id]=body
 SAO.Controller.agents[rec.id]=nil
 body.md.SAOExternalOwner='ZAO' body.md.SAOExternalToken=token body.md.ZAOOwned=true
end
function __copy(value)
 if type(value)~='table' then return value end
 local out={} for key,item in pairs(value) do out[key]=__copy(item) end return out
end
function __equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not __equal(v,b[k]) then return false end end
 for k,v in pairs(b) do if a[k]==nil then return false end end
 return true
end
local nativeSnapshots={}
local oldHibernate=SAOJavaBridge.hibernate
SAOJavaBridge.hibernate=function(self,body)
 local packed=oldHibernate(self,body)
 nativeSnapshots[packed]={values=__copy(body.values),asleep=body.asleep,sit=body.sit}
 return packed
end
local oldAwaken=SAOJavaBridge.awaken
SAOJavaBridge.awaken=function(self,body,packed,elapsed)
 local result=oldAwaken(self,body,packed,elapsed)
 local saved=nativeSnapshots[packed]
 if saved and SAO.Pharmacology then
  body.values=__copy(saved.values) body.asleep=saved.asleep body.sit=saved.sit
 end
 return result
end
SAOJavaBridge.applyDormantRestState=function(self,body,fatigue,endurance)
 body.fatigue=fatigue body.endurance=endurance
 body:getStats():set(CharacterStat.FATIGUE,fatigue)
 body:getStats():set(CharacterStat.ENDURANCE,endurance)
 return true
end
SAOJavaBridge.advanceDormantMetabolism=function(self,body,delta)
 body:getStats():add(CharacterStat.HUNGER,delta*.012)
 body:getStats():add(CharacterStat.THIRST,delta*.020)
 return 'METABOLIZED native-receiver-fixture'
end
__transactionResults={}
function __transactionCase(name,run)
 local ok,err=pcall(run)
 __transactionResults[name]=ok and true or tostring(err)
 __failStat=nil
end
