SAO={Log={line=function() end},Identity={},History={},Body={},Perception={},Hash={of=function() return 0 end,unit=function() return 0.5 end},Conditions={fear=function() return 0 end}}
rec={id="p",x=10,y=10,homeX=10,homeY=10}; SAO.Identity.get=function() return rec end; SAO.Identity.all=function() return {p=rec} end; SAO.Body.get=function() return nil end
SAO.History.ageOf=function() return 12 end; SAO.History.countyHours=function() return 0 end; SAO.History.fearFloorOf=function() return 0.1 end; SAO.History.nightFearOf=function() return 0 end; SAO.History.countyTimeOfDay=function() return 12 end; SAO.History.WOUND_FEAR=0.25
storeTable={}; ModData={getOrCreate=function() return storeTable end}
