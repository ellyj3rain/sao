SAO={SourceIntegration={active=function()return true end}}
function require(name) return CATALOGUES[name] or {} end
function isServer()return MODE:sub(1,7)=='server-' end
function isClient()return CLIENT or false end
function getText(s)return s end
function getTexture(s)return s end
function getPlayerScreenTop()return 0 end
function getPlayerScreenLeft()return 0 end
function getPlayerScreenHeight()return 1000 end
function getPlayerScreenWidth()return 1600 end
function ZombRand(a,b)return b and a or 0 end
function sendVisual()end
function triggerEvent()end
function sendClientCommand(...)SENT={...}end
function sendPlayerStat(...)STAT_SENT={...}end
function SyncXp(p)XP_SENT=p end
UIFont={Small='small',Medium='medium',Large='large'}
SandboxVars={LSArt={GeneralBeautyMultiplier=1.5},LSHygiene={OuthouseRange=10},ReadingSpeed=1}
Perks={Music='Music'};JoypadState={players={}};UIManager={getSpeedControls=function()return nil end}
function getTextManager()return{getFontHeight=function()return 12 end,MeasureStringX=function(_,_,s)return #s end}end
function getCore()return{getScreenWidth=function()return 1600 end,getScreenHeight=function()return 1000 end}end
function getDebug()return true end
function instanceof(v,k)return nativeIs(v,k)end
function getCell()return{getGridSquare=function()return SCENE_SQUARE end}end
luautils={stringStarts=function(a,b)return a and a:sub(1,#b)==b end,stringEnds=function(a,b)return a and a:sub(-#b)==b end,haveToBeTransfered=function()return false end}
function getPlayerInventory()return{refreshBackpacks=function()end}end
function getGameTime()return{getMinutesPerDay=function()return 60 end}end
function isPlayerDoingAction()return false end
HaloTextHelper={addGoodText=function(p,text)HALOS[#HALOS+1]={p,text}end};HALOS={}
ModData={getOrCreate=function()return{BTY={fixture=7}}end}
LSUtil={debugPrint=function(s)LOGS[#LOGS+1]=s end,getObjSpriteName=function(o)return o and o.sprite end,hasAdminRights=function()return true end,isCooldown=function(d)return d.cooldown or false end}
LOGS={};LSSync={transmit=function(o)TRANSMITTED[#TRANSMITTED+1]=o end};TRANSMITTED={}

function sendAddItemToContainer()end
function sendClothing()end
