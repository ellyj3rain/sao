CHECKS=0
function check(ok,name) if not ok then error('D2_UTILITY:'..name) end CHECKS=CHECKS+1 end
function require() end
SAO={SourceIntegration={active=function() return true end}}
LSSync={isClientOnly=function() return false end}
function instanceof() return false end
function isServer() return false end
function isClient() return false end
function ZombRand() return 0 end
Perks={Strength='Strength',Nimble='Nimble'}
-- Controlled source audio receiver: native Event drives the original scheduling.
EMITTER={playing={},starts=0,stops=0}
function EMITTER:playSound(name) self.starts=self.starts+1;self.playing[self.starts]=true;return self.starts end
function EMITTER:playSoundImpl(name) return self:playSound(name) end
function EMITTER:isPlaying(id) return self.playing[id]==true end
function EMITTER:stopSound(id) self.playing[id]=false;self.stops=self.stops+1 end
SOUND_BODY={getEmitter=function() return EMITTER end}
FOLLOWER_HITS=0
function follower() FOLLOWER_HITS=FOLLOWER_HITS+1 end
Events.OnTick.Add(follower);Events.EveryOneMinute.Add(follower)
-- Original base-action queue/log presentation host is controlled; native item count is real.
QUEUE={completed=0,resets=0}
function QUEUE:onCompleted(action) self.completed=self.completed+1;self.last=action end
function QUEUE:resetQueue() self.resets=self.resets+1 end
ISTimedActionQueue={getTimedActionQueue=function() return QUEUE end}
ISLogSystem={logAction=function() end}
TEXT_BODY={words={},getInventory=function() return {getCountTypeRecurse=function(_,kind) return nativeCurrencyCount(kind) end} end}
function TEXT_BODY:Say(text) self.words[#self.words+1]=text end
function TEXT_BODY:setIsFarming(value) self.farming=value end
OBJECT={getSquare=function() return {} end}
