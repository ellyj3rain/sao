local id="utility-owner"
local rec=SAO.Identity.ensure(id,"Casey","Source",body:getX(),body:getY(),body:getZ())
if not rec then error("native ordinary identity adoption failed")end
SAO.Body.active[id]=body;__record=rec
if rec.bodyOwnerToken~=nil or body:getModData().SAOExternalToken~=nil then error("ordinary native body token changed")end
