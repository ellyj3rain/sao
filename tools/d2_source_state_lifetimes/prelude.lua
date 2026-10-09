CHECKS=0
function check(v,n)assert(v,'D2_STATE:'..n);CHECKS=CHECKS+1;print('CASE '..n)end
SAO={SourceIntegration={active=function()return true end}};require=function()end
function isClient()return false end;function isServer()return MODE=='juke'end
ISPanelJoypad={derive=function()return {}end};LS_AMcache={};LS_PatchUtils={hasCompatMod=function()return false end}
UIFont={Small='small',Medium='medium'};getTextManager=function()return {getFontHeight=function()return 12 end}end
IsoDirections={S='S'}
getTexture=function(s)return s end;sendVisual=function()end
LSUtil={};LSAmbtMng={};ModData={};SandboxVars={}
function list(a)return {size=function()return #a end,get=function(_,i)return a[i+1]end}end
BloodBodyPartType={MAX={index=function()return 1 end},FromIndex=function()return 'head'end}
ZombRand=function()return 0 end
MakeUpDefinitions={makeup={{category='FullFace',item='probe'}}};instanceItem=function(s)return nativeMakeup(s)end
