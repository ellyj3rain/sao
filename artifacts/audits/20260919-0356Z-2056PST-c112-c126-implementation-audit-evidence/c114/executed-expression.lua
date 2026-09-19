(function()
 SAO.Driving.order("audit",body,"car",1000,0)
 local verbBeforeMotion=rec.verbs[1]
 for i=1,600 do SAO.Driving.tick("audit") end
 local at600=SAO.Driving.status("audit")
 SAO.Driving.tick("audit")
 local at601=SAO.Driving.status("audit")
 local moved=body.x; local aborts=cancelled
 calls=0;cancelled=0;succeedAt=600;body.x=0
 SAO.Driving.order("audit",body,"car",1000,0)
 for i=1,601 do SAO.Driving.tick("audit") end
 return "tick600="..at600.." tick601="..at601.." moved="..tostring(moved).." cancellations="..tostring(aborts).." verbBeforeMotion="..tostring(verbBeforeMotion).." control="..SAO.Driving.status("audit").." controlCancel="..tostring(cancelled)
end)()