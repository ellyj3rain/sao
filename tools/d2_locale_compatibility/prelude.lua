REQUIRES=0
function require(name) REQUIRES=REQUIRES+1 end
SAO={SourceIntegration={active=function() return true end}}
Perks={MetalWelding=__nativeWeld}
SandboxVars={LevelForMediaXPCutoff=10}
local xp=0
BODY={getPerkLevel=function(self,perk) assert(perk==__nativeWeld); return 0 end,
    getXp=function() return {getXP=function(self,perk) assert(perk==__nativeWeld); return xp end} end}
function addXp(body,perk,amount)
    assert(body==BODY and perk==__nativeWeld and amount==50,"D2_LOCALE:source_welding_xp_unchanged")
    xp=xp+amount
end
HALOS={}; local instance={addHalo=function(name,amount) HALOS[#HALOS+1]={name=name,amount=amount} end,
    checkPlayer=function() end,setNoHalo=function() end}
ISRadioInteractions={getInstance=function() return instance end}
ORIGINAL_INSTANCE_METHOD=ISRadioInteractions.getInstance
EVENTS=0;Events={OnTick={Add=function(callback) assert(type(callback)=='function');EVENTS=EVENTS+1 end}}
