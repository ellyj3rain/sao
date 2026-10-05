-- Only engine/world receivers are controlled. The generated Config, complete
-- StudyWorld observer, installed Kahlua and StudyExport serializer are real.
Events = {}
for _, name in ipairs({'OnPreMapLoad','OnInitWorld','OnInitGlobalModData','OnGameStart','OnTick','OnTickEvenPaused'}) do
    local callbacks = {}
    Events[name] = {Add=function(fn) callbacks[#callbacks+1]=fn end,
        fire=function(value) for _,fn in ipairs(callbacks) do fn(value) end end}
end
worldgen = {roads={}}
local settings, dimensions = {}, {}
for key,value in pairs(Config.sandbox) do settings[key]=value end
getSandboxOptions = function() return {
    getOptionByName=function(_, key)
        local option={value=settings[key]}
        option.asConfigOption=function(self) return self end
        option.makeCopy=function(self) return self end
        option.isValidString=function() return true end
        option.setValueFromObject=function(self,v) self.value=v end
        option.getValueAsObject=function(self) return self.value end
        return option
    end,
    set=function(_,key,value) settings[key]=value end,toLua=function() end} end
WorldGenParams={INSTANCE={}}
for _, name in ipairs({'SeedString','MinXCell','MinYCell','MaxXCell','MaxYCell'}) do
    WorldGenParams.INSTANCE['set'..name]=function(_,value) dimensions[name]=value end
end
WorldGenParams.INSTANCE.getSeedString=function() return dimensions.SeedString end
local grid={getMinX=function() return dimensions.MinXCell end,getMinY=function() return dimensions.MinYCell end,
    getMaxX=function() return dimensions.MaxXCell end,getMaxY=function() return dimensions.MaxYCell end}
getWorld=function() return {getMap=function() return Config.mapName end,
    getWorld=function() return 'ArrayProbe' end,getMetaGrid=function() return grid end} end
getCore=function() return {getVersion=function() return 'controlled-world-receivers' end} end
getGameTime=function() return {getWorldAgeHours=function() return 2 end,
    getStartYear=function() return 1993 end,getStartMonth=function() return 0 end,
    getStartDay=function() return 0 end} end
getTimestampMs=function() return 123456789 end
isClient=function() return false end
isServer=function() return false end
local persisted={}
ModData={getOrCreate=function() return persisted end}
getActivatedMods=function() return {size=function() return 0 end} end
getCell=function() return {getGridSquare=function() return nil end} end
SAO={History={countyHours=function() return 2 end},Identity={all=function() return {} end},Body={},
    PopulationAdmissions={stageInitialPeople=function() return true end,
        stageInitialAwareness=function(_,_,entries)
            assert(entries==Config.situation.initialAwareness,'admission lost original authored table')
            assert(getmetatable(entries[1].entries)==nil,'admission configuration was mutated')
            return true
        end,stageInitialLifeHistory=function(_,_,rows,startDate)
            assert(rows==Config.situation.initialLifeHistory,'life admission lost source table')
            assert(startDate=='1993-01-01','life admission lost native calendar')
            assert(getmetatable(rows[1].episodes)==nil,'life source array was mutated')
            return true
        end,initialPeopleSnapshot=function() return {} end}}
function RunArrayChecks(Study)
    assert(Study.prepare(),'prepare failed')
    assert(Study.options(),'options failed')
    Events.OnInitGlobalModData.fire(true)
    assert(Study.start(),'start failed')
    local rec={id='array-person',x=128,y=128,z=0}
    local body={getX=function()return 128 end,getY=function()return 128 end,getZ=function()return 0 end}
    SAO.Identity.all=function()return {[rec.id]=rec} end
    SAO.Body.get=function(id)return id==rec.id and body or nil end
    SAO.Body.hasRepresentation=function(id)return id==rec.id end
    SAO.History.ticks=function()return 120 end
    local inference={paths={},contradictions={},missing={},parentIds={},evidenceIds={},roots={}}
    local held={schema='sao-person-state/1',actorId=rec.id,status='available',atTick=120,atHours=2,
        modelView={actorId=rec.id,atTick=120,atHours=2,recall={episodes={{participants={},relations={}}}},situation={questions={{
            evidence={},anticipated={},revisions={{evidence={},observations={}}},
            conceptualEvidence={conditionalHarm=inference}}}}}}
    local function detached(value)
        if type(value)~='table' then return value end
        local result={} for key,item in pairs(value) do result[key]=detached(item) end return result
    end
    SAO.PersonState={query=function(id,candidate,tick)
        assert(id==rec.id and candidate==body and tick==120,'person export lost current owner')
        return detached(held)
    end}
    local frozen={schema='sao-person-decision-state/1',actorId=rec.id,decisionId='decision/1',
        atHours=2,atTick=120,status='available',personState=held}
    SAO.Cognition={snapshot=function(id,full)
        assert(id==rec.id and full==true,'cognition export lost owner')
        return detached({schema='simulation.cognition/1',actorId=rec.id,
            episodes={{id='episode/1',worldHours=2,frame={id='decision/1',actorId=rec.id},decisionPersonState=frozen}},experiences={}})
    end}
    FRAME=Study.observe()
    FALLBACK=Study.encode(FRAME)
    assert(FRAME.situation~=Config.situation,'situation aliases authored configuration')
    assert(FRAME.situation.initialAwareness~=Config.situation.initialAwareness,'awareness aliases configuration')
    assert(FRAME.situation.initialAwareness[2].entries[1]~=Config.situation.initialAwareness[2].entries[1],
        'report aliases authored configuration')
    FRAME.situation.initialAwareness[2].entries[1].sourceId='fixture-modified-copy'
    assert(Config.situation.initialAwareness[2].entries[1].sourceId=='fixture-radio',
        'detached observation changed authored report')
    assert(getmetatable(Config.situation.initialAwareness[1].entries)==nil,
        'observer mutated authored empty list')
    assert(FRAME.situation.initialLifeHistory~=Config.situation.initialLifeHistory,'life history aliases configuration')
    local episode=FRAME.situation.initialLifeHistory[2].episodes[1]
    assert(episode~=Config.situation.initialLifeHistory[2].episodes[1],'episode aliases source')
    episode.description='changed-return'
    assert(Config.situation.initialLifeHistory[2].episodes[1].description==
        'A prior shared movie night. caf'..string.char(233)..' '..string.char(55356,57260),
        'detached observation changed life history')
    assert(getmetatable(Config.situation.initialLifeHistory[1].episodes)==nil,'observer mutated empty life array')
    assert(getmetatable(Config.situation.initialLifeHistory[2].episodes[1].participants)==nil,'observer mutated source participants')
    FRAME=Study.observe()
    assert(Study.encode(FRAME)==FALLBACK,'fresh projection retained prior copy mutation')
    assert(getmetatable(held.modelView.recall.episodes)==nil,'observer marked private person owner')
    assert(getmetatable(held.modelView.situation.questions[1].evidence)==nil,'observer marked private question evidence')
    assert(getmetatable(frozen.personState.modelView.recall.episodes)==nil,'observer marked frozen source state')
end
