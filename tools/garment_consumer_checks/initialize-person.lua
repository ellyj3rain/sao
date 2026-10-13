local id="garment-person"
local rec=SAO.Identity.ensure(id,"Casey","Source",body:getX(),body:getY(),body:getZ())
if not rec then error("actual identity adoption failed")end
if rec.bodyOwnerToken~=nil or body:getModData().SAOExternalToken~=nil then error("ordinary body unexpectedly tokenized")end
SAO.Body.active[id]=body
__record=rec
