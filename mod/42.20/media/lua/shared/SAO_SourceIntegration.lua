-- Owned source package availability and exact original source readers.
-- Imported physical namespaces remain original; canonical people stay SAO's.
require "SAO_SourcePackageManifest"
SAO=SAO or {}
SAO.SourceIntegration=SAO.SourceIntegration or {}
local S=SAO.SourceIntegration
local manifest=SAO.SourcePackageManifest
local verified={}
S.loadReport=S.loadReport or {}

local function pathSafe(path)
    return type(path)=="string" and #path>0 and #path<512
        and path:sub(1,1)~="/" and not path:find("\\",1,true)
        and not path:find(":",1,true) and not path:find("..",1,true)
        and not path:find("\0",1,true)
end

function S.available(id)
    manifest=SAO.SourcePackageManifest
    local row=type(id)=="string" and manifest and manifest.sources and manifest.sources[id]
    if not row or manifest.schema~="sao.owned-source-package/1"
        or manifest.packageId~="SurvivorAwareness" or not getModFileReader then
        S.loadReport[tostring(id)]="owned-source-unavailable";return false
    end
    local prior=verified[id]
    if prior and prior.row==row and prior.seal==row.seal and prior.root==row.root
        and prior.sentinel==row.sentinel then
        S.loadReport[id]="owned-source-ready";return true
    end
    local reader=getModFileReader(manifest.packageId,row.sentinel,false)
    if not reader then S.loadReport[id]="owned-source-sentinel-absent";return false end
    local ok,line=pcall(function()return reader:readLine()end)
    pcall(function()reader:close()end)
    if not ok or tostring(line)~="SAO-OWNED-SOURCE/1 "..id.." "..row.seal then
        S.loadReport[id]="owned-source-seal-mismatch";return false
    end
    verified[id]={row=row,seal=row.seal,root=row.root,sentinel=row.sentinel}
    S.loadReport[id]="owned-source-ready";return true
end

-- This is the installed selection, separate from the owned package seal.
function S.externalSelected(id)
    local mods=getActivatedMods and getActivatedMods()
    return type(id)=="string" and mods and mods:contains(id)==true or false
end

-- Packaged Lua files call active() before registering physical producers.
-- Private SAO readers use available() so an activated original mod does not
-- take away the person's source knowledge or its pinned original methods.
function S.active(id)
    if S.externalSelected(id) then
        S.loadReport[id]="duplicate-external-source-refused";return false
    end
    return S.available(id)
end

function S.reader(id,path,create)
    if create==true or not pathSafe(path) or path:sub(1,6)~="media/" then
        return nil,"owned-source-path-refused"
    end
    if not S.available(id) then return nil,S.loadReport[tostring(id)] end
    local row=manifest.sources[id]
    local reader=getModFileReader(manifest.packageId,row.root.."/"..path,false)
    if not reader then return nil,"owned-source-original-absent" end
    return reader
end

return S
