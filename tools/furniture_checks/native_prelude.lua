function require()return {}end
function isClient()return false end
function isServer()return false end
function getGameTime()return nil end
function getCell()return __cell end
function getActivatedMods()return {contains=function()return false end}end
function sendAddItemToContainer()end
function sendRemoveItemFromContainer()end
function triggerEvent()end
function copyTable(t)local o={};for k,v in pairs(t)do if type(v)=='table' then o[k]=copyTable(v)else o[k]=v end end;return o end
-- instanceof and native factories come from the installed class exposer.
ISTimedActionQueue={queues={}}
function ISTimedActionQueue.getTimedActionQueue(body)
 local q=ISTimedActionQueue.queues[body]
 if not q then
  q={queue={}}
  function q:indexOf(a)for i,x in ipairs(self.queue)do if a==x then return i end end;return -1 end
  function q:removeFromQueue(a)local i=self:indexOf(a);if i~=-1 then table.remove(self.queue,i)end end
  function q:onCompleted(a)if self.current~=a then return end;self:removeFromQueue(a);self.current=self.queue[1]end
  ISTimedActionQueue.queues[body]=q
 end
 return q
end
function ISTimedActionQueue.add(a)local q=ISTimedActionQueue.getTimedActionQueue(a.character);q.queue[#q.queue+1]=a;q.current=q.current or a end
ISLogSystem={logAction=function()end}
luautils={stringStarts=function(s,p)return s:sub(1,#p)==p end}
Events={OnObjectAdded={Add=function()end},OnObjectAboutToBeRemoved={Add=function()end},
 OnGameBoot={Add=function()end},OnDynamicMovableRecipe={Add=function()end}}
