(function()
 local returned=SAO.AfflictedReturn.adopt(1)
 local before=SAO.Controller.describe("loaded")
 local dormantDead=records.dormant.dead
 SAO.Controller.adopt(records.loaded)
 return "adoptReturned="..tostring(returned).." loadedDead="..tostring(records.loaded.dead).." hasBody="..tostring(SAO.Body.get("loaded")~=nil).." automaticController="..before.." dormantDead="..tostring(dormantDead).." controlEnrolled="..tostring(SAO.Controller.agents.loaded~=nil)
end)()