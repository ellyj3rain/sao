
local state={groups={a='g',b='g'}, yearsRun=1, yearsOwed=1}
local records={a={forename='A',surname='A',designation='before',stage='decision-time'},b={forename='B',surname='B'}}
local beliefs={a={known={stage='decision-time',tick=10}},b={}}
ModData={getOrCreate=function() return state end}
SAO={Identity={get=function(id) return records[id] end,all=function() return records end},
 Perception={beliefs=beliefs},History={countyHours=function() return 1 end},
 Standing={electLeader=function() records.a.designation='chosen' end}}
local count=0
_G.__handlers={OnTick=function()
 count=count+1
 if count==1 then SAO.Standing.electLeader('g') end
 if count==2 then records.a.stage='future';records.a.designation='later';beliefs.a.known.stage='future';beliefs.a.futureKnowledge={tick=200} end
end}
