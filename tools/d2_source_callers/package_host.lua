-- Actual project-vault filesystem reader; body/queue/audio remain the existing controlled native host.
local priorRequire=require
__ownedReads={};__externalSource=nil;__hideOriginal=nil;__tamperOriginal=nil;__hideSentinel=false;__tamperSentinel=false
getActivatedMods=function()return{contains=function(_,id)return id==__externalSource end}end
getModFileReader=function(package,path,create)
 assert(package=='SurvivorAwareness' and create~=true,'external-package-reader-forbidden')
 __ownedReads[#__ownedReads+1]=path
 if __hideSentinel and SAO.SourcePackageManifest then for _,row in pairs(SAO.SourcePackageManifest.sources)do if path==row.sentinel then return nil end end end
 if path==__hideOriginal then return nil end
 local text=__packageFile(path);if not text then return nil end
 if __tamperSentinel and text:sub(1,18)=='SAO-OWNED-SOURCE/1'then text='bad seal\n'end
 if path==__tamperOriginal then text=text..'\n-- altered vault fixture bytes\n'end
 local at=1
 return{readLine=function()if at>#text then return nil end;local e=text:find('\n',at,true);local line=text:sub(at,e and e-1 or #text);at=e and e+1 or #text+1;return line:gsub('\r$','')end,close=function()end}
end
function __loadPackageRegistry()
 SAO.SourceIntegration=nil
 assert(loadstring(assert(__packageFile('media/lua/shared/SAO_SourcePackageManifest.lua')),'actual-owned-manifest'))()
 assert(loadstring(__registryText or assert(__packageFile('media/lua/shared/SAO_SourceIntegration.lua')),'actual-owned-registry'))()
end
require=function(name)
 if name=='SAO_SourceIntegration'then __loadPackageRegistry();return SAO.SourceIntegration end
 if name=='SAO_SourcePackageManifest'then return SAO.SourcePackageManifest end
 return priorRequire(name)
end
__loadPackageRegistry()
