-- Installed source owns sound, animation, learning and physiological changes.
-- This owner binds source participation to a particular person and purpose.
require "SAO_LeisureMusicWorld"
require "SAO_LeisureMusicSupply"
SAO = SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end
SAO.LeisureMusic = SAO.LeisureMusic or {}
local M = SAO.LeisureMusic
if M.reset then M.reset("module-reload") end
local runtime = {}
local OWNER = "SAO.LeisureMusic"
local PINS = {
    ["LifestyleHobbies:shared/LSUtil.lua"] = { "4e6b73720eefcafd828773067327664aa854228a6080705cf948c9cecc149ddb", 1541193869, 1686604880, 2388 },
    ["LifestyleHobbies:shared/Instruments/animations.lua"] = { "67842db5de3f9ac88c72b3da65c9970d0707f906140e13b088ecbcf7d395a4c0", 109963311, 987496555, 190 },
    ["LifestyleHobbies:shared/TimedActions/PlayInstrumentActionNew.lua"] = { "529d944ce7f7dd18d1512b2eca31e542820856a9d3095c8fb8e54720eedbaaf3", 343507785, 1643734932, 552 },
    ["LifestyleHobbies:shared/TimedActions/PlayInstrumentTraining.lua"] = { "835dc53b2f5a8807c9b77d6e5edc39f4611a063ddac43e7dfacaa2e0e53f604a", 1132098851, 2076609104, 681 },
    ["LifestyleHobbies:shared/TimedActions/PlayInstrumentVocal.lua"] = { "33f628fa94fe7522a6925f1a4a47c999c32c09cec176f0de5e1a2a39b07f6a38", 673780015, 937546317, 578 },
    ["LifestyleHobbies:shared/TimedActions/PlayerIsDancingToMusic.lua"] = { "6cdd500807d05edbf4d9e2f4c8c2036920d858c2d7887a477c6fb337e48e845c", 2108432921, 546369063, 882 },
    ["LifestyleHobbies:client/LSDanceEffects.lua"] = { "19b3111f2629b75ec77f229673cf88be4aae5cdd209961d9fe87a03c758b3487", 811590428, 218297921, 320 },
    ["LifestyleHobbies:client/JukeboxContextMenu.lua"] = { "a488db5febe4ade1e5eadc0f5767952a96817faa8166044a58a417304608b46e", 1174284704, 602191323, 144 },
    ["LifestyleHobbies:client/TimedActions/PlayerVoiceTracks.lua"] = { "4b5dd1871c51b68514922f804d2c10d4fe6775f72532c0c3e376a0a0bc3c732c", 1647777782, 736065194, 145 },
    ["LifestyleHobbies:client/TimedActions/PlayerDanceMoves.lua"] = { "990bef24101e395e9e4a2eb72a7232ba21353a1eb59325f86f65ab214dbe3186", 667020360, 2021379037, 172 },
    ["LifestyleHobbies:client/XpSystem/PlayerTracker.lua"] = { "3b78755a7fb00e44bcdd0058fcd2b7cfe9e05b8bdbaf629e40ec7b0df92fca52", 1922440540, 1884050285, 228 },
    ["LifestyleHobbies:client/Instruments/Tracks/PlayVocalTracksDuet.lua"] = { "476b8db71dc29aac08095ffa3f18b7e7316847295822f3eddda0d39b4c3810f2", 465471216, 138455128, 88 },
    ["LifestyleHobbies:client/Instruments/Tracks/PlayPianoTracks.lua"] = { "b82ce519528a200c4fe467a3e7db10a1a57aa15857651a5f56c4ecb6cb828881", 508806979, 1054295682, 44 },
    ["LifestyleHobbies:client/Instruments/InstrumentPianoContextMenu.lua"] = { "44851d755f09a6d364e1043d8e0b89799818111237e7c3c40f7eeec46345eb47", 1605730528, 1313759085, 348 },
    ["LifestyleHobbies:client/LSIsListeningEffects.lua"] = { "44a2a0490c84d256b8a10023f9b08032f8a488bcce9d6ccb89dd8843d8fbfe12", 624071614, 1622846682, 216 },
    ["LifestyleHobbies:client/Instruments/VocalContextMenu.lua"] = { "e05e85b49469da5c36f9a903ee2a5a1a8302d359b2fb6114d0cb3832e100fc5a", 900304028, 1194231971, 189 },
    ["LifestyleHobbies:client/Instruments/Tracks/PlayPianoTracksDuet.lua"] = { "5e763909e36966a6fdb057a99121a72b2990af5d3289d09edd517b2acd43155d", 1809164408, 902101094, 54 },
    ["LifestyleHobbies:client/TimedActions/PlayBanjoTracksDuet.lua"] = { "74891aeb8dc3ac0c5f349331e3b5cc069bf00b8d838ce3b7af9e601798875b42", 2113956921, 1521202163, 26 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarAcousticTracksDuet.lua"] = { "5011ea72f75e2daac9c12605281a2fc0674a735fd0470c8b27c0a905cebd3237", 1274314873, 261021605, 53 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarElectricBassTracksDuet.lua"] = { "455bf292addd34274794e66d3fcfc9dbe6e27c08190b31647ef3fcb9454ac734", 1969309286, 1086845946, 86 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarElectricTracksDuet.lua"] = { "0bbe551b5eac11f6ee0248dffa2ab45264b541fe74b4f4b3a374be07a408e8f6", 611289032, 139810320, 72 },
    ["LifestyleHobbies:client/TimedActions/PlayFluteTracksDuet.lua"] = { "54ec8834c932e02ea519315203f4c0acdbc2e77ffc431a226bf1bcee110736f4", 1600848612, 1190966622, 38 },
    ["LifestyleHobbies:client/TimedActions/PlayTrumpetTracksDuet.lua"] = { "095f8b95b8cbe8cfe854e9221d8d08fae63917d95bdbcd6e160ba55df884cab4", 1218822435, 1171535327, 38 },
    ["LifestyleHobbies:client/TimedActions/PlayKeytarTracksDuet.lua"] = { "60cbae6e37c4daa047d4d221f9519bfeda7fba0217614ef0cc97b7d28eb5c681", 778064034, 1682504476, 98 },
    ["LifestyleHobbies:client/TimedActions/PlaySaxophoneTracksDuet.lua"] = { "20b8b33b6985f7c9277a841713387ed633da33df1fa4a4baf08852e648489315", 1882677144, 944465160, 36 },
    ["LifestyleHobbies:client/TimedActions/PlayViolinTracksDuet.lua"] = { "0c32b827e14f2a1a26b331e9221ba241b107c9ad1dae051e1b11483283ccf067", 1984032490, 1972487861, 31 },
    ["LifestyleHobbies:client/TimedActions/PlayHarmonicaTracksDuet.lua"] = { "f3f795f4b928547230610c9afdf3d3fd5ee82560404d3891072f5ba77b0aa52f", 2115548659, 1161290106, 20 },
    ["LifestyleHobbies:client/TimedActions/PlayBanjoTracks.lua"] = { "11782aba6422eeff02e71b430180159fa49f7127cc84e8049a26cd192cbc53b9", 1454769332, 532858714, 76 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarAcousticTracks.lua"] = { "39cd417f32a4a972c82cb5a94ca8af24ba859817e4bfdf7bd6f32eccab3f871c", 1398301260, 1758663327, 77 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarElectricBassTracks.lua"] = { "b66988800115d046ba567967340b000db8d5c642f387d27d07bebbbb2e22c404", 636486735, 1813031208, 76 },
    ["LifestyleHobbies:client/TimedActions/PlayGuitarElectricTracks.lua"] = { "745ef5a5d78162cff684f6ed66bb864251cd7de7e620be87311f825e2b39b58a", 222286359, 667669008, 76 },
    ["LifestyleHobbies:client/TimedActions/PlayFluteTracks.lua"] = { "bf4b5b8137201d56d3a0cfa29c60eeb3687aca184b36e29b0f69ad9c046446d1", 2131631732, 1637853822, 78 },
    ["LifestyleHobbies:client/TimedActions/PlayTrumpetTracks.lua"] = { "c9f8a27b89bb5266930f68c598110a1a4d483169886187de476ffdc58fee9b7d", 415809975, 1997608155, 82 },
    ["LifestyleHobbies:client/TimedActions/PlayKeytarTracks.lua"] = { "3c27b595fed47ca7eaae08554021ed1fe4a88707eeafa7c1ce2e343d35e7f38a", 285468777, 1385237086, 78 },
    ["LifestyleHobbies:client/TimedActions/PlaySaxophoneTracks.lua"] = { "1b01698e73c94f39baec15fcf33cb51acbf028b8f251ea1e218a3940d8b45e49", 1416284637, 1914585703, 76 },
    ["LifestyleHobbies:client/TimedActions/PlayViolinTracks.lua"] = { "e2011f76efed0fd9348357ce678120c37e2e3f974612bd90019ad441e4dc2cd0", 1838051586, 277853476, 61 },
    ["LifestyleHobbies:client/TimedActions/PlayHarmonicaTracks.lua"] = { "f9a9942bda125b8d545f4342a9aec7ad6b409d7a67410959a8800adbcd81ed05", 93179302, 1375565000, 63 },
    ["NewMusic:shared/helpers/NMAttachmentHelpers.lua"] = { "b1c9a3aeb2cb07c49e42269c9fea343bd19a52cd457c968483066edbdfb84295", 22271658, 1732610145, 244 },
    ["NewMusic:shared/slot/NMInsertedHeadphonePolicy.lua"] = { "64dd8035ec94321f071e4d0bde1a917d6b9d5e9aa4fc023f194a618c2eb03c6c", 2106159016, 1364970829, 44 },
    ["NewMusic:client/sync/NMClientModeReconcile.lua"] = { "343f16b4caf52d732951a3bd5470941c50c98a68a71ed94fe85d86ff267a4743", 1425786220, 333572426, 257 },
    ["NewMusic:shared/audio/NMPlaybackRuntimeCommon.lua"] = { "e3ff416d15a656ca3a9b969bb0c94c0dfb9639dd7caa1844edbf5b99255bf8e9", 103650887, 1760648538, 272 },
    ["NewMusic:shared/audio/NMPlaybackRuntime.lua"] = { "06f944f941ff92a781ce2984203df6608824e351c7aa56062e4c5ac0a6c5e454", 782253652, 1565322809, 2681 },
    ["NewMusic:client/intents/NMClientIntentDispatch.lua"] = { "e1f309f408784b953639441e6daced73a13aaafed8462ea04e68361137e1d1cf", 1767864685, 421395577, 1192 },
    ["NewMusic:client/cache/NMClientWorldSourceCache.lua"] = { "b3eeaa85bd6a49982ef81c7df10202020786d9c9add267cb4d85975b03d7af99", 1602393160, 503481682, 1071 },
    ["NewMusic:client/runtime/NMClientDetachedPlaybackPass.lua"] = { "64035d65f45a4186c68683033c4ec737c7343cae5a0ab4527ca074cfd90275c3", 203248781, 2010291514, 228 },
    ["NewMusic:client/runtime/NMClientTrackFinishedDispatch.lua"] = { "e62b9c9c683e3850112fbbd586eea9d48e47f05e86bc0d43bd5624fd09b86d99", 1114504313, 463287731, 311 },
    ["NewMusic:client/runtime/NMClientPlaybackTick.lua"] = { "e7d40336faa56b66676a03a79347a8be3f82b379ca559d623ebb2d397f861b07", 1209664039, 1559809281, 3201 },
    ["NewMusic:client/runtime/NMClientMainRuntime.lua"] = { "8c0c74bbdc465dae64b7eddca7c18580079cd2ebd0f6eb87e243fb7e6e7a1f1b", 663504099, 1701731595, 972 },
    ["NewMusic:client/runtime/NMClientSPLocalRuntime.lua"] = { "07936b28f7476e6fa480d2145d640c63a8203fcfc876b9426bda370719cd3b1f", 544453681, 622484963, 247 },
}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function plain(v, depth)
    depth=depth or 0
    if type(v)=="string" or type(v)=="boolean" then return v end
    if type(v)=="number" then return finite(v) and v or nil end
    if type(v)~="table" or depth>=7 then return nil end
    local result={}
    for k,x in pairs(v) do if type(k)=="number" or type(k)=="string" then result[k]=plain(x,depth+1) end end
    return result
end
local function person(id) return SAO.Identity and SAO.Identity.get(id) end
local function hours() return SAO.History.countyHours() end
local function live(id,body) return person(id) and SAO.Needs and SAO.Needs.ownsRecoveryBody(id,body)==true end
local function activeSource(id) return SAO.SourceIntegration and SAO.SourceIntegration.available(id)==true end
local function sp() return not isClient() and not isServer() end
local function carried(body)
    local result={}
    local items=SAOJavaBridge:privateCarriedItems(body)
    for n=0,items:size()-1 do result[#result+1]=items:get(n) end
    return result
end
local function itemKey(item) return "item:"..tostring(item:getID())..":"..item:getFullType() end
local function resolveItem(body,key)
    for _,item in ipairs(carried(body)) do if itemKey(item)==key then return item end end
end
local function concept(id,from)
    local K=SAO.ConceptKnowledge
    if not K or not K.infer then return nil end
    for _,effect in ipairs({"recreation","relief-from-stress"}) do
        local view=K.infer(id,from,effect)
        local path=view and view.actorId==id and view.paths and view.paths[1]
        if path and path.status=="expectation" and type(path.evidenceIds)=="table" and #path.evidenceIds>0 then
            return {id=path.id,evidenceIds=plain(path.evidenceIds),basis=path.basis,expectedEffect=effect,modal=true}
        end
    end
end
local function measure(body)
    local result={}
    if not LSUtil or not LSUtil.getCharacterMood then return result end
    for _,name in ipairs({"Boredom","Stress","Unhappiness","Endurance","Fatigue","Pain"}) do
        local v=LSUtil.getCharacterMood(body,name)
        if finite(v) then result[name]=v end
    end
    return result
end
local function physical(body,continuing)
    if body:isAsleep() or body:getVehicle() or body:isSneaking() or body:isAiming() then return false end
    return continuing or SAO.Needs.workAvailable(body)
end
local learned={Banjo="BanjoLearnedTracks",GuitarAcoustic="GuitarALearnedTracks",
    GuitarElectricBass="GuitarEBLearnedTracks",GuitarElectric="GuitarELearnedTracks",
    Flute="FluteLearnedTracks",Trumpet="TrumpetLearnedTracks",Keytar="KeytarLearnedTracks",
    Saxophone="SaxophoneLearnedTracks",Violin="ViolinLearnedTracks",Harmonica="HarmonicaLearnedTracks",Piano="PianoLearnedTracks"}
local function instrument(item)
    local kind=item:getType()
    if kind:find("^GuitarElectricBass") then return "GuitarElectricBass" end
    if kind:find("^GuitarElectric") then return "GuitarElectric" end
    if learned[kind] and kind~="Piano" then return kind end
    local full=item:getFullType()
    if full:find("^HMW%.H_Bass") then return "GuitarElectricBass" end
    if full:find("^HMW%.H_Acoustic") then return "GuitarAcoustic" end
    if full:find("^HMW%.H_Electric") then return "GuitarElectric" end
    if full:find("^HMW%.H_Banjo") then return "Banjo" end
end
-- Re-read unchanged source into a private Lua environment. Two independent
-- normalized-text fingerprints detect drift; SHA provenance is the audited file.
local function chunk(env,source,path)
    local pin=PINS[source..":"..path]
    if not pin or not loadstring or not setfenv or not (SAO.SourceIntegration and SAO.SourceIntegration.reader) then error("source-loader-unavailable:"..path) end
    local reader=SAO.SourceIntegration.reader(source,"media/lua/"..path)
    if not reader then error("source-file-unavailable:"..path) end
    local lines,h1,h2,count={},0,0,0
    local ok,err=pcall(function()
        while true do
            local line=reader:readLine()
            if line==nil then break end
            line=tostring(line);count=count+#line+1
            if count>1048576 then error("source-file-too-large") end
            lines[#lines+1]=line
            for n=1,#line do local b=string.byte(line,n);h1=(h1*31+b)%2147483647;h2=(h2*131+b)%2147483647 end
            h1=(h1*31+10)%2147483647;h2=(h2*131+10)%2147483647
        end
    end)
    reader:close()
    if not ok then error(err) end
    if h1~=pin[2] or h2~=pin[3] or #lines~=pin[4] then error("source-revision-changed:"..path) end
    local code=table.concat(lines,"\n").."\n"
    if source=="LifestyleHobbies" and path=="shared/TimedActions/PlayerIsDancingToMusic.lua" then
        -- The raw source pin remains authoritative provenance. These two
        -- source-local reads belong to this exact action, as its constructor
        -- and remaining callbacks already establish.
        env.danceOwnershipSites={}
        for _,binding in ipairs({
            {"elseif AnimTime ~= 0", "elseif self.AnimTime ~= 0"},
            {"not self.character:isItemInBothHands(handItemP)", "not self.character:isItemInBothHands(self.handItemP)"},
        })do
            local changed,sites=code:gsub(binding[1]:gsub("([^%w])","%%%1"),binding[2])
            if sites~=1 then error("source-dance-action-binding-seam-changed:"..binding[1])end
            code=changed;env.danceOwnershipSites[#env.danceOwnershipSites+1]={original=binding[1],derived=binding[2]}
        end
        env.danceTraceSites={}
        for _,argument in ipairs({"self.fallSoundScream","self.fallSound","voiceSoundF","voiceSound"})do
            local site="self.character:getEmitter():playSound("..argument..")"
            local pattern=site:gsub("([^%w])","%%%1")
            local changed,count=code:gsub(pattern,"__dancePlaySound(self.character,"..argument..")")
            if count~=1 then error("source-dance-audio-tracing-seam-changed:"..argument)end
            code=changed;env.danceTraceSites[#env.danceTraceSites+1]=site
        end
        local derivedH1,derivedH2=0,0
        for n=1,#code do local b=string.byte(code,n);derivedH1=(derivedH1*31+b)%2147483647;derivedH2=(derivedH2*131+b)%2147483647 end
        env.danceDerivedRevision={h1=derivedH1,h2=derivedH2,bytes=#code,authority="verified-original-with-explicit-action-bindings-and-four-audio-sites"}
    end
    if source=="LifestyleHobbies"and path=="client/JukeboxContextMenu.lua"then
        -- These exact source-native choices need no context-menu/UI/file owner.
        -- Extraction happens only after the complete original source pin passes.
        local parts={"JukeboxMenu={}"}
        for _,name in ipairs({"onEnableDancing","onDisableDancing"})do
            local pattern="JukeboxMenu%."..name.." = function%(player%)%s+.-%s+end"
            local found;local count=0
            for value in code:gmatch(pattern)do found=value;count=count+1 end
            if count~=1 then error("source-dance-choice-producer-changed:"..name)end
            parts[#parts+1]=found
        end
        code=table.concat(parts,"\n").."\n"
    end
    local fn,why=loadstring(code,source..":"..path)
    if not fn then error(why) end
    setfenv(fn,env)
    return fn()
end
local function pin(source,path) return PINS[source..":"..path] and PINS[source..":"..path][1] end
local function environment(id,body)
    local env=setmetatable({LSMusic={},LS_DJBooth={},LSMoodHandler={PerMin={}},NMPlaybackRuntime={},NMPlaybackRuntimeCommon={},NMClientIntentDispatch={},NMAttachmentHelpers={},NMClientModeReconcile={},
        NMClientPlacedWorldCandidate={},NMClientPortableDropHandoff={}},{__index=_G})
    env._G=env
    env.NMClientPlaybackTick={requestFullPass=function()
        local a=runtime[id];if a and a.body==body then a.sourceFullPassRequested=true end
    end}
    local sm={volume=getSoundManager():getMusicVolume()}
    function sm:getMusicVolume() return self.volume end
    function sm:setMusicVolume(v) self.volume=v end
    function sm:playUISound(sound) return body:getEmitter():playSound(sound) end
    env.getSoundManager=function() return sm end
    env.isKeyDown=function() return false end
    env.getPlayer=function() return body end
    env.getNumActivePlayers=function() return 0 end
    env.getSpecificPlayer=function() return nil end
    env.LSNoteMng={addToQueue=function(_,_,_,_,args)
        local a=runtime[id]
        if a and a.body==body and args and args[1]==body then
            a.notes=a.notes or {};if #a.notes<8 then a.notes[#a.notes+1]={text=args[2],kind=args[3],sourceId="LifestyleHobbies"} end
        end
    end}
    env.sendClientCommand=function(actor,module,command,args)
        local a=runtime[id]
        if actor~=body or not a or a.body~=body then error("foreign-source-command") end
        if module=="LS" and command=="AddXP" then
            local rec=person(id);local work=rec and rec.leisureMusicWork
            if not work or work.status~="active" or not finite(args[2]) or args[2]<0 then error("invalid-source-skill-request") end
            if args[2]==0 then return end -- The exact source may request zero at mastery.
            rec.leisureMusicSkillSequence=(rec.leisureMusicSkillSequence or 0)+1
            local request={actorId=id,workId=work.workId,purposeId=work.purposeId,workSequence=work.sequence,
                sequence=rec.leisureMusicSkillSequence,perkName=args[1],amount=args[2],atHours=hours(),
                sourceId=work.sourceId,revision=work.revision,status="requested",
                nativeProgress={sourceCallback=a.sourceCallback,sourceInvocationSequence=a.sourceInvocationSequence,
                    actionStarted=a.started==true,jobDelta=a.action and a.action:getJobDelta()}}
            if not request.nativeProgress.actionStarted or not request.nativeProgress.sourceCallback then error("unbound-source-skill-callback") end
            a.skillRequests=a.skillRequests or {}
            a.skillRequests[request.sequence]=plain(request)
            rec.leisureMusicSkillRequests=rec.leisureMusicSkillRequests or {}
            rec.leisureMusicSkillRequests[#rec.leisureMusicSkillRequests+1]=request
            if #rec.leisureMusicSkillRequests>64 then table.remove(rec.leisureMusicSkillRequests,1) end
            if SAO.LeisureSkill and SAO.LeisureSkill.consume then SAO.LeisureSkill.consume(id,body,OWNER,work.sequence,request.sequence) end
            return
        end
        -- SP source mood setters use native Stats. Unassessed command paths
        -- are refused rather than dispatched through an operator player slot.
        error("unassessed-source-command:"..tostring(command))
    end
    local modules={}
    env.require=function(name)
        if name=="TimedActions/ISBaseTimedAction" then return ISBaseTimedAction end
        if name=="runtime/NMClientPlacedWorldCandidate" then return env.NMClientPlacedWorldCandidate end
        local path="client/"..name..".lua"
        if PINS["LifestyleHobbies:"..path] then
            if modules[name]==nil then modules[name]=chunk(env,"LifestyleHobbies",path) or true end
            return modules[name]
        end
        return require(name)
    end
    return env
end
local function lifestyleEnv(id,body)
    local env=environment(id,body)
    chunk(env,"LifestyleHobbies","shared/LSUtil.lua")
    chunk(env,"LifestyleHobbies","shared/Instruments/animations.lua")
    for _,name in ipairs({"changeCharacterMood","changeCharacterMoodGroup","addPainBodyPart"}) do
        local native=env.LSUtil[name]
        if native then env.LSUtil[name]=function(actor,...)
            local a=runtime[id];local rec=person(id);local w=rec and rec.leisureMusicWork
            if actor~=body or not a or a.body~=body or not w or w.status~="active"
                or not live(id,body) or w.bodyToken~=body:getModData().SAOExternalToken then error("source-effect-owner-lost") end
            return native(actor,...)
        end end
    end
    return env
end
-- Carried source mode uses exact native hand/back/attached item membership.
-- Hidden placed-item candidate scans and cross-player drop handoffs have no
-- actor-acquired producer here, so those optional queries remain absent.
local function recordedSourceEnv(id,body)
    local env=environment(id,body)
    chunk(env,"NewMusic","shared/helpers/NMAttachmentHelpers.lua")
    chunk(env,"NewMusic","client/sync/NMClientModeReconcile.lua")
    return env
end
local function recordedContext(env,body,item,profile,state)
    if item.getWorldItem and item:getWorldItem() then return nil end
    local mode=env.NMClientModeReconcile.resolveModeForItem(body,item,profile,state)
    if mode=="attached" or mode=="stowed" or mode=="inventory" then return mode end
end
local function recordedDance(offer) return offer.activity=="dance-to-recorded-music" end
local function danceActivity(offer) return offer.activity=="dance" or recordedDance(offer) end
local function danceHeard(a) return a.danceHeardMusic or a.offer.heardMusic end
local function danceSourceEnv(id,body)
    local env=lifestyleEnv(id,body)
    local sourceGroup=env.LSUtil.changeCharacterMoodGroup
    env.LSUtil.changeCharacterMoodGroup=function(actor,moods)
        local a=runtime[id]
        if actor~=body or not a or not danceActivity(a.offer) or not a.started or a.sourceCallback~="update"
            or not live(id,body) then error("unbound-source-dance-cycle")end
        local heard=M.currentHeardMusic(id,body)
        if not heard or not danceHeard(a) then error("source-dance-current-music-lost")end
        for field,value in pairs(danceHeard(a))do
            if heard[field]~=value then error("source-dance-current-music-lost")end
        end
        local before=measure(body);local result=sourceGroup(actor,moods)
        -- Only the original complete cycle's exact group callback is a milestone.
        if type(moods)=="table" and moods.Endurance and moods.Endurance[1]==-.015
            and moods.Fatigue and moods.Fatigue[1]==.001 and moods.Boredom and moods.Stress and moods.Unhappiness then
            a.danceCycle={actorId=id,sourceId="LifestyleHobbies",sourceInvocationSequence=a.sourceInvocationSequence,
                sourceCallback="update",before=before,after=measure(body),moods=plain(moods),heardMusic=plain(heard),
                sourceCallbackCompleted=false,atHours=hours()}
        end
        return result
    end
    env.HaloTextHelper={addTextWithArrow=function(actor,text)
        local a=runtime[id]
        if actor~=body or not a or not a.started or not live(id,body)
            or (a.sourceCallback~="update" and a.sourceCallback~="stop")then error("unbound-dance-source-note")end
        a.notes=a.notes or {};if #a.notes<16 then a.notes[#a.notes+1]={text=text,sourceId="LifestyleHobbies"}end
    end}
    env.__dancePlaySound=function(actor,sound)
        local a=runtime[id];local heard=M.currentHeardMusic(id,body)
        if actor~=body or not a or not danceActivity(a.offer) or not a.started or a.sourceCallback~="update"
            or not live(id,body) or not heard or not danceHeard(a) then error("unbound-source-dance-sound")end
        for field,value in pairs(danceHeard(a))do if heard[field]~=value then error("source-dance-sound-hearing-lost")end end
        local handle=actor:getEmitter():playSound(sound)
        if finite(handle)and handle~=0 then
            a.danceSounds=a.danceSounds or {};a.danceSounds[handle]=sound
        end
        return handle
    end
    return env
end
-- Public devices retain the installed source's one physical UUID renderer.
-- Listening observes that owner; it never synchronizes or retires its emitter.
local function audioSources(id,body)
    local P=SAO.Perception
    return P and P.leisureAudioSources and P.leisureAudioSources(id,body) or {}
end
local function audioTarget(id,body,offer)
    local P=SAO.Perception
    local target=P and P.resolveLeisureAudioSource and P.resolveLeisureAudioSource(id,body,offer.audioSourceKey)
    if type(target)~="table" then return nil end
    if offer.sourceContext=="placed" then
        local object,item=target.object,target.item
        if not object or not item or object:getItem()~=item or item:getWorldItem()~=object
            or tostring(item:getID())~=offer.itemKey or item:getFullType()~=offer.itemType then return nil end
        return target,item,NMDeviceProfiles.getForItem(item)
    end
    local vehicle,part=target.vehicle,target.part
    if not vehicle or not part or part:getVehicle()~=vehicle or vehicle:getPartById(offer.partId)~=part
        or tostring(vehicle:getId())~=offer.vehicleId or tostring(vehicle:getSqlId())~=offer.vehicleSqlId
        or tostring(part:getId())~=offer.partId then return nil end
    return target,part,NMDeviceProfiles.getVehicleProfile(part)
end
local function sourcePower(body,target,device,profile,state,context)
    if context=="vehicle" then return NMVehicleHelpers and NMVehicleHelpers.vehicleHasPower(target.vehicle,target.part)==true end
    if profile.requiresExternalPower then
        return NMInventoryHelpers and NMInventoryHelpers.resolveExternalPowerAvailable(body,device,profile)==true
    end
    return profile.requiresBattery==true and state.batteryPresent==true and finite(state.batteryCharge) and state.batteryCharge>0
end
local function publicSource(target,context)
    if context=="placed" then
        local sq=target.object:getSquare()
        if not sq then return nil end
        return {mode="placed",context="placed",x=sq:getX()+.5,y=sq:getY()+.5,z=sq:getZ()}
    end
    local vehicle=target.vehicle
    return {mode="vehicle",context="vehicle",vehicle=vehicle,vehicleId=tostring(vehicle:getId()),
        vehicleSqlId=tostring(vehicle:getSqlId()),partId=tostring(target.part:getId()),
        x=vehicle:getX(),y=vehicle:getY(),z=vehicle:getZ(),windowsOpen=NMVehicleHelpers.vehicleWindowsOpen(vehicle)}
end
local function nearPublicControl(body,target,context)
    if context=="vehicle" then return body:getVehicle()==target.vehicle end
    local sq=target.object:getSquare()
    return sq and body:getZ()==sq:getZ() and math.abs(body:getX()-(sq:getX()+.5))<=1.5
        and math.abs(body:getY()-(sq:getY()+.5))<=1.5
end
local function descriptor(id,body,activity,key,path,evidence,extra)
    local d={id="music:"..id..":"..activity..":"..key,actorId=id,family="music",sourceId="LifestyleHobbies",
        revision=pin("LifestyleHobbies",path),activity=activity,itemKey=key,evidence=plain(evidence),
        bodyToken=body:getModData().SAOExternalToken,bodyGenerationKnown=body:getModData().SAOExternalToken~=nil,
        revisionAuthority="audited SHA256; runtime dual normalized-text fingerprints"}
    for k,v in pairs(extra or {}) do d[k]=plain(v) end
    return d
end
local function publicAudioOffers(id,body,intents,result,evidence)
    if not evidence or not activeSource("NewMusic") or not NMDeviceProfiles or not NMDeviceState
        or not NMPlaybackRuntime or not NMPlaybackRuntime.computeLocalListenerAudibility
        or not NMClientWorldSourceCache or not NMWorldRegistrySnapshot then return end
    for n,row in ipairs(audioSources(id,body)) do
        if n>48 or #result>=24 then break end
        if row.actorId==id and type(row.key)=="string" and (row.sourceKind=="placed" or row.sourceKind=="vehicle") then
            local context=row.sourceKind
            local d=descriptor(id,body,"listen-source-world-music",row.itemKey or row.key,
                "shared/TimedActions/PlayInstrumentActionNew.lua",evidence)
            d.sourceId="NewMusic";d.revision=pin("NewMusic","shared/audio/NMPlaybackRuntime.lua")
            d.rendererRevisionAuthority="audited source files; shared loaded renderer bytes unsealed"
            d.sourceContext=context;d.audioSourceKey=row.key;d.audioObservation=plain(row)
            d.itemType=row.itemType;d.vehicleId=row.vehicleId and tostring(row.vehicleId)
            d.vehicleSqlId=row.vehicleSqlId and tostring(row.vehicleSqlId);d.partId=row.partId
            local target,device,profile=audioTarget(id,body,d)
            local state=device and NMDeviceState.peek(device)
            local supplies=target and profile and state and SAO.LeisureMusicSupply
                and SAO.LeisureMusicSupply.plan(body,device,profile,state,context)
            if target and profile and state and state.deviceUUID and (state.mediaFullType or supplies and supplies.media)
                and (sourcePower(body,target,device,profile,state,context)or supplies and supplies.battery)
                and (tonumber(state.volume)or 0)>0 and not state.isMuted
                and (SAO.LeisureMusicSupply and SAO.LeisureMusicSupply.outputMode(profile,state,context,supplies)
                    or NMDeviceProfiles.resolveOutputMode(profile,state,context,false))=="world" then
                local nearby=nearPublicControl(body,target,context)
                -- Source vehicle controls are an occupant operation. A nearby
                -- nonoccupant may listen to an already running public radio.
                if state.isPlaying or nearby or intents and context=="placed" then
                    for _,field in ipairs({"deviceUUID","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do d[field]=state[field]end
                    d.deviceRevision=state.revision;d.alreadyPlaying=state.isPlaying==true
                    d.sourceSupplies=plain(supplies)
                    if supplies then d.materials=SAO.LeisureMusicSupply.materialKeys(supplies)end
                    d.requiresPreparation={frontSquare=not state.isPlaying and not nearby}
                    if d.requiresPreparation.frontSquare then
                        local source=publicSource(target,context);d.targetX=source.x;d.targetY=source.y;d.targetZ=source.z
                    end
                    result[#result+1]=d
                end
            end
        end
    end
end
local function sourceState(body)
    local data=body:getModData()
    return type(data.LSMoodles)=="table" and type(data.LSMoodles.PartyBad)=="table"
        and type(data.LSMoodles.Embarrassed)=="table"
end
-- A current hearing fact for dance. Perception owns acquisition; this reader
-- never starts, mixes or advances the shared physical renderer.
-- Fresh receiver evidence over personally acquired contacts. Existing source
-- callbacks own playback; this query starts no sound and supplies no pleasure.
function M.currentPerformerMusic(id,body)
    if not live(id,body)or body:isAsleep()or not activeSource("LifestyleHobbies")
        or not SAO.Perception or not SAO.Perception.knownPeople or not SAOJavaBridge.canConverseNow then return nil end
    local contacts=SAO.Perception.knownPeople(id)
    for n,contact in ipairs(contacts or {})do
        if n>48 then break end
        local peer=type(contact)=="table"and contact.id;local a=peer and runtime[peer]
        local rec=a and person(peer);local w=rec and rec.leisureMusicWork
        if peer~=id and a and w and a.body~=body and a.started and not a.performed
            and a.offer.sourceId=="LifestyleHobbies"and a.offer.activity~="dance"
            and a.offer.activity~="listen-recorded-music"and w.status=="active"and a.body:getModData().PlayingInstrument==true
            and live(peer,a.body)and SAO.Body and a.body==SAO.Body.get(peer)and a.action
            and ISTimedActionQueue.hasAction(a.action)then
            local handle=a.action.gameSound
            local admitted=SAO.ProceduralPlanning and SAO.ProceduralPlanning.hobbyAdmission
                and SAO.ProceduralPlanning.hobbyAdmission(peer,w.purposeId,w.workId)
            local ok,heard=pcall(function()
                return a.action:isValid()and admitted and admitted.ownerName==OWNER and admitted.sequence==w.sequence and body:CanSee(a.body)
                    and body:getZ()==a.body:getZ()and body:isOutside()==a.body:isOutside()
                    and handle and handle~=0 and a.body:getEmitter():isPlaying(handle)
                    and SAOJavaBridge:canConverseNow(a.body,body,8)==true
            end)
            if ok and heard==true then
                return {actorId=id,sourceId="LifestyleHobbies",revision=w.revision,
                    sourceKey="performer:"..peer..":"..w.workId,sourceContext="performer",
                    performerId=peer,performerWorkId=w.workId,performerWorkSequence=w.sequence,
                    runtimeInstance=w.bodyToken,sourceGeneration=w.sequence,sourceSoundId=handle,
                    itemKey=w.itemKey,itemType=w.itemType,sound=a.action.lastSound or a.action.soundFile,
                    nativeHeard=true,soundObserved=true,range=8,atHours=hours(),
                    receptionRevision="5b34989c686e9a1c4f80dd575537bf35506d659a2a4455e83a9df97b16d54bca",
                    receptionProducer="DiscoStateChange.LS_PlayingInstrumentRange/getPlayerList range8; current known-contact/native visibility/hearing",
                    listenerEffects=false}
            end
        end
    end
end
-- Personal output is a fact only for this admitted actor and this exact live
-- body, item, source tuple and actor emitter. It does not enter world hearing.
local function currentPersonalMusic(id,body)
    local a=runtime[id];local rec=person(id);local w=rec and rec.leisureMusicWork
    if not a or a.body~=body or not a.playbackStarted or not a.playback or not w
        or w.status~="active" or w.sequence~=a.sequence or w.bodyToken~=body:getModData().SAOExternalToken
        or a.offer.sourceId~="NewMusic" or a.offer.audioSourceKey or not activeSource("NewMusic")
        or resolveItem(body,a.offer.itemKey)~=a.item then return nil end
    local admission=SAO.ProceduralPlanning and SAO.ProceduralPlanning.hobbyAdmission
        and SAO.ProceduralPlanning.hobbyAdmission(id,w.purposeId,w.workId)
    if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return nil end
    local state=NMDeviceState and NMDeviceState.peek(a.item);local binding=a.playback
    if not state or not state.isOn or not state.isPlaying or state.isMuted or not state.batteryPresent
        or not finite(state.batteryCharge) or state.batteryCharge<=0 then return nil end
    for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
        if state[field]~=binding[field]then return nil end
    end
    local profile=NMDeviceProfiles and NMDeviceProfiles.getForItem(a.item)
    local context=profile and recordedContext(a.env,body,a.item,profile,state)
    if context~=a.offer.sourceContext or NMDeviceProfiles.resolveOutputMode(profile,state,context,false)~="personal"then return nil end
    local renderer=a.env.NMPlaybackRuntime;local entry=renderer and renderer.Active and renderer.Active[tostring(binding.deviceUUID)]
    local channel=entry and entry.mode=="single" and entry
    local audibility=renderer and renderer.computeLocalListenerAudibility
        and renderer.computeLocalListenerAudibility(body,profile,state,{mode=context,context=context})
    if not entry or entry.epoch~=binding.playbackEpoch or entry.sourceGeneration~=binding.sourceGeneration
        or entry.trackIndex~=binding.trackIndex or entry.context~=context or not channel
        or channel.isWorldEmitter~=false or channel.emitter~=body:getEmitter() or not channel.soundId
        or not channel.emitter:isPlaying(channel.soundId) or not audibility or not audibility.shouldPlay
        or not audibility.personalOwnerAllowed or audibility.outputMode~="personal"
        or not finite(audibility.personalVolume) or audibility.personalVolume<=.001
        or not finite(audibility.worldVolume) or audibility.worldVolume>.001 then return nil end
    return {actorId=id,sourceId="NewMusic",revision=a.offer.revision,
        sourceKey="portable:"..a.offer.itemKey..":"..tostring(binding.deviceUUID),sourceContext=context,
        runtimeInstance=w.workId,bodyToken=w.bodyToken,itemKey=a.offer.itemKey,itemType=a.offer.itemType,
        deviceUUID=binding.deviceUUID,deviceRevision=binding.revision,playbackEpoch=binding.playbackEpoch,
        sourceGeneration=binding.sourceGeneration,trackIndex=binding.trackIndex,mediaFullType=binding.mediaFullType,
        sourceSoundId=channel.soundId,nativeHeard=true,soundObserved=true,sound=channel.sound,
        listenerVolume=audibility.personalVolume,worldVolume=audibility.worldVolume,atHours=hours(),
        revisionAuthority=a.offer.revisionAuthority}
end
function M.currentHeardMusic(id,body)
    if not live(id,body) or body:isAsleep() or body.isDead and body:isDead() then return nil end
    local personal=currentPersonalMusic(id,body)
    if personal then return plain(personal)end
    local lifestyle=SAO.LeisureLifestyle and SAO.LeisureLifestyle.currentHeardMusic
    local ok,ownSource=pcall(lifestyle or M.currentPerformerMusic,id,body)
    if not ok then ownSource=nil end
    if ownSource then return plain(ownSource)end
    if not NMPlaybackRuntime or not NMDeviceState then return nil end
    local rows={};publicAudioOffers(id,body,false,rows,concept(id,"music"))
    for _,offer in ipairs(rows)do
        local target,device,profile=audioTarget(id,body,offer)
        local state=device and NMDeviceState.peek(device)
        local source=target and publicSource(target,offer.sourceContext)
        local entry=state and NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[tostring(state.deviceUUID)]
        local channel=entry and (entry.mode=="dual" and entry.world or entry)
        local audibility=source and NMPlaybackRuntime.computeLocalListenerAudibility(body,profile,state,source)
        local range=profile and state and NMDeviceProfiles.computeWorldRange(profile,tonumber(state.volume)or 0)
        if state and state.isOn and state.isPlaying and not state.isMuted and sourcePower(body,target,device,profile,state,offer.sourceContext)
            and entry and entry.epoch==state.playbackEpoch and entry.sourceGeneration==state.sourceGeneration
            and entry.trackIndex==state.trackIndex and entry.context==offer.sourceContext
            and channel and true==channel.isWorldEmitter and channel.emitter and channel.soundId
            and channel.emitter:isPlaying(channel.soundId) and audibility and audibility.shouldPlay
            and finite(audibility.worldVolume) and audibility.worldVolume>.001 and finite(range) and range>0
            and SAO.Perception.canHearLeisureSource(id,body,offer.audioObservation,range)==true then
            return {actorId=id,sourceId="NewMusic",revision=offer.revision,sourceKey=offer.audioSourceKey,
                sourceContext=offer.sourceContext,runtimeInstance=offer.audioObservation.runtimeInstance,
                deviceUUID=state.deviceUUID,deviceRevision=state.revision,playbackEpoch=state.playbackEpoch,
                sourceGeneration=state.sourceGeneration,trackIndex=state.trackIndex,mediaFullType=state.mediaFullType,
                nativeHeard=true,soundObserved=true,sound=channel.sound,range=range,listenerVolume=audibility.worldVolume,
                atHours=hours(),revisionAuthority=offer.rendererRevisionAuthority}
        end
    end
end
local function danceBinding(fact)
    if not fact then return nil end
    local result={}
    for _,field in ipairs({"actorId","bodyToken","sourceId","revision","sourceKey","sourceContext","runtimeInstance","deviceUUID",
        "deviceRevision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType",
        "performerId","performerWorkId","performerWorkSequence","sourceSoundId","itemKey","itemType"})do result[field]=fact[field]end
    return result
end
local function validTrack(t,level)
    return type(t)=="table" and type(t.sound)=="string" and t.sound~="" and finite(t.length)
        and t.length>0 and finite(t.level) and t.level<=level
end
local function voiceReady(data)
    return finite(data.PlayerVoice) and data.PlayerVoice>=0 and data.PlayerVoice<=4 and data.PlayerVoice%1==0
end
local function personalRecordedDanceReady(id,body,intents)
    if not live(id,body) or not sp() or not physical(body,false)
        or not activeSource("NewMusic") or not activeSource("LifestyleHobbies")
        or not concept(id,"music") or not concept(id,"dance")
        or not Perks.Dancing or not LSUtil or not LSUtil.getCharacterMood
        or body:isSitOnGround() or body:isSittingOnFurniture() then return false end
    local data=body:getModData()
    return (intents or sourceState(body) and voiceReady(data))
        and LSUtil.getCharacterMood(body,"Endurance")>.3
        and LSUtil.getCharacterMood(body,"Pain")<=20
        and (not sourceState(body) or data.LSMoodles.Embarrassed.Value<.2)
end
local function partnerStyleAvailable(data)
    local listening=data.IsListeningToDJ and "electronic"or data.IsListeningToMusicStyle
    if not listening then return true end -- Exact source default is disco.
    if type(listening)~="string"then return false end
    local recognized={disco=true,rbsoul=true,pop=true,metal=true,salsa=true,beach=true,classical=true,country=true,
        holiday=true,jazz=true,muzak=true,rap=true,reggae=true,rock=true,world=true,electronic=true}
    return not (recognized[listening] or recognized[string.sub(listening,2)])or listening=="disco"or listening=="cdisco"
end
function M.danceChoices(id,body)
    if not live(id,body) or not sp() or not activeSource("LifestyleHobbies")or not physical(body,true)
        or body:isSitOnGround()or body:isSittingOnFurniture()or not Perks.Dancing or not LSUtil then return {}end
    local evidence=concept(id,"dance");local heard=evidence and M.currentHeardMusic(id,body);local data=body:getModData()
    if not heard or not partnerStyleAvailable(data)or LSUtil.getCharacterMood(body,"Endurance")<=.3
        or LSUtil.getCharacterMood(body,"Pain")>20 or sourceState(body)and data.LSMoodles.Embarrassed.Value>=.2 then return {}end
    local result={}
    for _,role in ipairs({"source","target"})do
        local row=descriptor(id,body,"dance","body:dance","shared/TimedActions/PlayerIsDancingToMusic.lua",evidence,
            {role=role,partnerRoles={role=="source"and"target"or"source"},heardMusic=danceBinding(heard),
                musicKey=heard.sourceId=="LifestyleHobbies"and (heard.sourceKey..":"..tostring(heard.sourceSoundId)..":"..tostring(heard.sourceGeneration))
                    or tostring(heard.deviceUUID)..":"..tostring(heard.playbackEpoch)..":"..tostring(heard.trackIndex),
                danceEffectsRevision=pin("LifestyleHobbies","client/LSDanceEffects.lua"),
                choiceProducerRevision=pin("LifestyleHobbies","client/JukeboxContextMenu.lua"),
                roleAnimation=role=="source"and"Bob_DancingDiscoSourceDefault"or"Bob_DancingDiscoTargetDefault",
                nativeDuration="one-observed-native-partner-animation-cycle",participationUnit="one-native-partner-dance-cycle",
                requiresPreparation={sourceInitialization=not sourceState(body),sourceVoice=not voiceReady(data)}})
        row.id=row.id..":partner:"..role;result[#result+1]=row
    end
    return plain(result)
end
function M.danceChoice(id,body,choiceId)
    for _,row in ipairs(M.danceChoices(id,body))do if row.id==choiceId then return row end end
end
local function danceOffers(id,body,intents,result)
    local O=SAO.Organization;if not O or not O.danceOffers then return end
    for _,agreement in ipairs(O.danceOffers(id))do
        local choice=M.danceChoice(id,body,agreement.choiceId)
        if choice and (intents or not choice.requiresPreparation.sourceInitialization and not choice.requiresPreparation.sourceVoice)then
            choice.dance={processId=agreement.processId,revision=agreement.revision,commitmentId=agreement.commitmentId,
                partnerId=agreement.partnerId,role=agreement.role,musicKey=agreement.musicKey}
            result[#result+1]=choice
        end
    end
end
-- Exact installed InstrumentPianoContextMenu/getAdjPiece map. Both pieces
-- must have their own current personal observation and fresh native handle.
local pianoPieces={
    recreational_01_8={"recreational_01_9",1,0,0,-.3},recreational_01_9={"recreational_01_8",-1,0,0,-.3},
    recreational_01_12={"recreational_01_13",0,-1,-.25,0},recreational_01_13={"recreational_01_12",0,1,-.25,0},
    recreational_01_28={"recreational_01_29",1,0,0,.3},recreational_01_29={"recreational_01_28",-1,0,0,.3},
    recreational_01_30={"recreational_01_31",0,-1,.5,0},recreational_01_31={"recreational_01_30",0,1,.5,0},
    recreational_01_40={"recreational_01_41",1,0,0,0},recreational_01_41={"recreational_01_40",-1,0,0,0},
    recreational_01_48={"recreational_01_49",0,-1,-.1,0},recreational_01_49={"recreational_01_48",0,1,-.1,0},
    recreational_01_108={"recreational_01_109",1,0,0,0},recreational_01_109={"recreational_01_108",-1,0,0,0},
    recreational_01_99={"recreational_01_96",0,-1,.1,0},recreational_01_96={"recreational_01_99",0,1,.1,0},
}
local function observedObjects(id,body)
    local P=SAO.Perception
    return P and P.leisureObjects and P.resolveLeisureObject and P.leisureObjects(id,body) or {}
end
local function resolveObject(id,body,key)
    local P=SAO.Perception;return P and P.resolveLeisureObject and P.resolveLeisureObject(id,body,key)
end
local function pianoReady(body,obj)
    local a,b=body:getSquare(),obj and obj:getSquare()
    return a and b and body:isSittingOnFurniture() and not body:hasTrait(CharacterTrait.DEAF)
        and a:getZ()==b:getZ() and math.abs(a:getX()-b:getX())<=1 and math.abs(a:getY()-b:getY())<=1
        and body:isFacingObject(obj,.8)
end
local function pianoOffers(id,body,evidence,intents,level,result)
    if body:hasTrait(CharacterTrait.DEAF) then return end
    local observations=observedObjects(id,body)
    for n,row in ipairs(observations) do
        if n>48 or #result>=24 then break end
        local vars=pianoPieces[row.spriteName]
        if row.actorId==id and vars and finite(row.x) and finite(row.y) and finite(row.z) then
            for index,other in ipairs(observations) do
                if index>48 then break end
                if other.actorId==id and other.spriteName==vars[1] and other.x==row.x+vars[2]
                    and other.y==row.y+vars[3] and other.z==row.z then
                    local obj=resolveObject(id,body,row.key);local pair=resolveObject(id,body,other.key)
                    if obj and pair and obj:getSpriteName()==row.spriteName and pair:getSpriteName()==vars[1] then
                        local prep={sourceInitialization=not sourceState(body),sitFurniture=not body:isSittingOnFurniture(),
                            faceObject=not body:isFacingObject(obj,.8),adjacentObject=not pianoReady(body,obj)}
                        if intents or (not prep.sourceInitialization and pianoReady(body,obj)) then
                            local extra={instrumentType="Piano",objectKey=row.key,pairObjectKey=other.key,
                                objectSpriteName=row.spriteName,pairSpriteName=other.spriteName,
                                objectObservation=plain(row),pairObservation=plain(other),requiresPreparation=prep,
                                sourceOffset={x=vars[4],y=vars[5]},
                                menuRevision=pin("LifestyleHobbies","client/Instruments/InstrumentPianoContextMenu.lua")}
                            local tracks=require("Instruments/Tracks/PlayPianoTracks");local practice=false
                            for _,t in ipairs(type(tracks)=="table" and tracks or {}) do
                                if type(t.sound)=="string" and t.sound~="" and finite(t.level) and t.level<=level
                                    and t.isaddon==2 then practice=true;break end
                            end
                            local known=body:getModData().PianoLearnedTracks or {}
                            if level>1 then for _,t in ipairs(known) do if validTrack(t,level) then practice=true end end end
                            if practice then result[#result+1]=descriptor(id,body,"practice-instrument",row.key,
                                "shared/TimedActions/PlayInstrumentTraining.lua",evidence,extra) end
                            for _,t in ipairs(known) do
                                if #result>=24 then break end
                                if validTrack(t,level) and t.isaddon~=2 then
                                    local performance=plain(extra);performance.sound=t.sound;performance.length=t.length;performance.trackLevel=t.level
                                    result[#result+1]=descriptor(id,body,"perform-instrument",row.key,
                                        "shared/TimedActions/PlayInstrumentActionNew.lua",evidence,performance)
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end
end
function M.prepareActor(id,body)
    if not live(id,body) or not activeSource("LifestyleHobbies") or not sp() then return false,"source-person-unavailable" end
    if not concept(id,"music") and not concept(id,"dance") then return false,"source-person-not-personally-supported" end
    local ok,why=pcall(function()
        if not sourceState(body) then
            if not LSMoodleManager or not LSMoodleManager.init then error("source-moodle-initializer-unavailable") end
            LSMoodleManager.init(body)
        end
        local data=body:getModData()
        if not voiceReady(data) then
            local tracker=data.PlayTracker
            if tracker~=nil and type(tracker)~="table" then error("invalid-source-tracker") end
            local env=environment(id,body)
            env.Events=setmetatable({},{__index=function(_,name)return {Add=function(fn)
                if name=="OnNewGame" then env.sourceVoiceInitializer=fn end
            end}end})
            chunk(env,"LifestyleHobbies","client/XpSystem/PlayerTracker.lua")
            if type(env.sourceVoiceInitializer)~="function" then error("source-voice-initializer-unavailable") end
            if tracker==nil then
                env.sourceVoiceInitializer(body)
            else
                -- The pinned source's hourly recovery selects ZombRand(5).
                -- Reuse that source voice domain without running its hourly
                -- tracker-aging callback or resetting this person's history.
                local replacement=ZombRand(5)
                if not voiceReady({PlayerVoice=replacement}) or not live(id,body)
                    or body:getModData()~=data or data.PlayTracker~=tracker then
                    error("source-voice-repair-unavailable")
                end
                data.PlayerVoice=replacement
            end
            if not voiceReady(data) then error("source-voice-initialization-incomplete") end
        end
        person(id).leisureMusicInitialization={actorId=id,bodyToken=data.SAOExternalToken,atHours=hours(),
            sourceId="LifestyleHobbies",revision=pin("LifestyleHobbies","client/XpSystem/PlayerTracker.lua"),
            nativeOwner="PlayerTracker pinned voice policy (isolated new-game or midgame repair)",voice=data.PlayerVoice}
    end)
    return ok,not ok and "source-person-initialization-failed:"..tostring(why) or nil
end
local roleFor={Banjo="banjo",GuitarAcoustic="guitaracoustic",GuitarElectric="guitarelectric",
    GuitarElectricBass="guitarelectricbass",Keytar="keytar",Flute="flute",Saxophone="saxophone",
    Trumpet="trumpet",Violin="violin",Harmonica="harmonica",Piano="piano"}
local function sourceFront(obj)
    if not obj or not obj:getSquare() then return nil end
    local props=obj:getSprite():getProperties();local face=props:has("Facing") and props:get("Facing")
    local front=face and IsoDirections[face] and obj:getSquare():getAdjacentSquare(IsoDirections[face])
    return front
end
local function frontReady(body,obj)
    local front=sourceFront(obj)
    return front and not body:isSitOnGround() and not body:isSittingOnFurniture() and body:getSquare()==front
end
-- Catalogue choices describe the actor's own part and source-advertised
-- compatible roles. They carry neither a partner nor presumed consent.
function M.duetChoices(id,body)
    if not live(id,body) or not activeSource("LifestyleHobbies") or not sp() or not physical(body,true)
        or body:hasTrait(CharacterTrait.DEAF) or not Perks.Music then return {} end
    local evidence=concept(id,"music");if not evidence then return {} end
    local result={};local level=body:getPerkLevel(Perks.Music);if level<4 then return result end
    local env=environment(id,body)
    local function append(kind,key,extra,path,role)
        local ok,tracks=pcall(chunk,env,"LifestyleHobbies",path);if not ok or type(tracks)~="table" then return end
        for _,track in ipairs(tracks) do
            if #result>=128 then break end
            local gender=body:getDescriptor():isFemale() and "Female" or "Male"
            local song=type(track.sound)=="string" and track.sound:match("Duet%d%d(.+)$")
            if song and validTrack(track,level) and (kind~="Vocal" or track.actionType==gender) then
                local partners={}
                for _,r in ipairs({"banjo","guitaracoustic","guitarelectric","guitarelectricbass","keytar","flute",
                    "saxophone","trumpet","violin","harmonica","piano","vocalm","vocalf"}) do
                    if track[r]==1 then partners[#partners+1]=r end
                end
                if #partners>0 then
                    local actionPath=kind=="Vocal" and "shared/TimedActions/PlayInstrumentVocal.lua"
                        or "shared/TimedActions/PlayInstrumentActionNew.lua"
                    local choice=descriptor(id,body,kind=="Vocal" and "perform-vocal-duet" or "perform-instrument",
                        key,actionPath,evidence,extra)
                    choice.id="duet-choice:"..id..":"..key..":"..track.sound
                    choice.instrumentType=kind;choice.role=role;choice.songId=song;choice.sound=track.sound
                    choice.length=track.length;choice.trackLevel=track.level;choice.partnerRoles=partners
                    choice.isDuet=true;choice.cataloguePath=path;choice.catalogueRevision=pin("LifestyleHobbies",path)
                    result[#result+1]=choice
                end
            end
        end
    end
    for n,item in ipairs(carried(body)) do
        if n>24 then break end
        local kind=instrument(item)
        if kind and not item:isBroken() and #(body:getModData()[learned[kind]] or {})>8 then
            append(kind,itemKey(item),{itemType=item:getFullType(),requiresPreparation={equipPrimary=body:getPrimaryHandItem()~=item,
                sourceInitialization=not sourceState(body)}},"client/TimedActions/Play"..kind.."TracksDuet.lua",roleFor[kind])
        end
    end
    if #(body:getModData().PianoLearnedTracks or {})>8 then
        local prepared={};pianoOffers(id,body,evidence,true,level,prepared)
        local seen={}
        for _,candidate in ipairs(prepared) do
            if not seen[candidate.objectKey] then
                seen[candidate.objectKey]=true
                local extra={}
                for _,field in ipairs({"objectKey","pairObjectKey","objectSpriteName","pairSpriteName","objectObservation",
                    "pairObservation","requiresPreparation","sourceOffset","menuRevision"}) do extra[field]=plain(candidate[field]) end
                append("Piano",candidate.itemKey,extra,"client/Instruments/Tracks/PlayPianoTracksDuet.lua","piano")
            end
        end
    end
    local observations=observedObjects(id,body)
    for n,row in ipairs(observations) do
        if n>48 then break end
        local obj=resolveObject(id,body,row.key)
        if obj and row.actorId==id and row.customName=="Microphone" and row.groupName=="Standing" and sourceFront(obj) then
            local front=sourceFront(obj)
            append("Vocal",row.key,{objectKey=row.key,objectSpriteName=row.spriteName,objectObservation=plain(row),
                micType="Standing",targetX=front:getX(),targetY=front:getY(),targetZ=front:getZ(),
                requiresPreparation={frontSquare=not frontReady(body,obj),sourceInitialization=not sourceState(body)}},
                "client/Instruments/Tracks/PlayVocalTracksDuet.lua",body:getDescriptor():isFemale() and "vocalf" or "vocalm")
        end
    end
    return plain(result)
end
function M.duetChoice(id,body,choiceId)
    for _,choice in ipairs(M.duetChoices(id,body)) do if choice.id==choiceId then return choice end end
end
local function duetOffers(id,body,intents,result)
    local O=SAO.Organization;if not O or not O.duetOffers then return end
    for _,agreement in ipairs(O.duetOffers(id)) do
        if #result>=24 then break end
        local choice=M.duetChoice(id,body,agreement.choiceId)
        if choice then
            local ready=not choice.requiresPreparation.sourceInitialization
            if choice.instrumentType=="Vocal" then ready=ready and frontReady(body,resolveObject(id,body,choice.objectKey))
            elseif choice.instrumentType=="Piano" then ready=ready and pianoReady(body,resolveObject(id,body,choice.objectKey))
            else ready=ready and not choice.requiresPreparation.equipPrimary end
            if ready or intents then
                choice.duet={processId=agreement.processId,revision=agreement.revision,commitmentId=agreement.commitmentId,
                    partnerId=agreement.partnerId,role=agreement.role,songId=agreement.songId}
                result[#result+1]=choice
            end
        end
    end
end
local function candidates(id,body,intents,ownedRequery)
    if not live(id,body) then return {},"body-unavailable" end
    if not sp() then return {},"npc-multiplayer-binding-unverified" end
    if runtime[id]and runtime[id]~=ownedRequery then return {},"music-attempt-active" end
    if body:getVehicle() then
        if body:isAsleep() or body:isSneaking() or body:isAiming() or not SAO.Needs.workAvailable(body) then return {},"native-work-busy" end
        local rows={};publicAudioOffers(id,body,intents,rows,concept(id,"music"));return rows
    end
    if not physical(body,false) then return {},"native-work-busy" end
    local evidence=concept(id,"music");local result={};local data=body:getModData()
    danceOffers(id,body,intents,result)
    duetOffers(id,body,intents,result)
    if evidence and activeSource("LifestyleHobbies") and Perks.Music and ISBaseTimedAction and SAO.SourceIntegration and SAO.SourceIntegration.reader then
        local level=body:getPerkLevel(Perks.Music)
        pianoOffers(id,body,evidence,intents,level,result)
        for _,item in ipairs(carried(body)) do
            local kind=instrument(item)
            if kind and not item:isBroken() then
                local preparation={equipPrimary=body:getPrimaryHandItem()~=item,sourceInitialization=not sourceState(body)}
                local ready=not preparation.equipPrimary and not preparation.sourceInitialization
                if ready or intents then
                    local key=itemKey(item)
                    -- Exact original practice selection requires a real playable
                    -- source track at this level, not an invented practice sound.
                    local tracks=require("TimedActions/Play"..kind.."Tracks")
                    local practice=false
                    for _,t in ipairs(type(tracks)=="table" and tracks or {}) do
                        if validTrack(t,level) and t.isaddon==2 then practice=true;break end
                    end
                    local known=data[learned[kind]] or {}
                    if level>1 then for _,t in ipairs(known) do if validTrack(t,level) then practice=true end end end
                    if practice then result[#result+1]=descriptor(id,body,"practice-instrument",key,"shared/TimedActions/PlayInstrumentTraining.lua",evidence,
                        {instrumentType=kind,itemType=item:getFullType(),requiresPreparation=preparation}) end
                    for _,t in ipairs(known) do
                        if validTrack(t,level) and t.isaddon~=2 then
                            result[#result+1]=descriptor(id,body,"perform-instrument",key,"shared/TimedActions/PlayInstrumentActionNew.lua",evidence,
                                {instrumentType=kind,itemType=item:getFullType(),sound=t.sound,length=t.length,trackLevel=t.level,requiresPreparation=preparation})
                            if #result>=24 then return result end
                        end
                    end
                end
            end
        end
    end
    local danceEvidence=concept(id,"dance")
    local danceMusic=danceEvidence and M.currentHeardMusic(id,body)
    if danceEvidence and danceMusic and activeSource("LifestyleHobbies") and Perks.Dancing and LSUtil
        and (intents or sourceState(body) and voiceReady(data))
        and not body:isSitOnGround() and not body:isSittingOnFurniture()
        and LSUtil.getCharacterMood(body,"Endurance")>0.3 and LSUtil.getCharacterMood(body,"Pain")<=20
        and (not sourceState(body) or data.LSMoodles.Embarrassed.Value<0.2) then
        result[#result+1]=descriptor(id,body,"dance", "body:dance","shared/TimedActions/PlayerIsDancingToMusic.lua",danceEvidence,
            {nativeDuration="one-source-animation-cycle",participationUnit="one-source-dance-cycle",heardMusic=danceBinding(danceMusic),
                requiresPreparation={sourceInitialization=not sourceState(body),sourceVoice=not voiceReady(data)}})
    end
    if evidence and activeSource("NewMusic") and NMDeviceProfiles and NMDeviceState and NMDeviceState.peek
        and NMClientIntentDispatch and NMPlaybackRuntime and NMRuntimeConfig then
        local sourceEnv=recordedSourceEnv(id,body)
        for _,item in ipairs(carried(body)) do
            local profile=NMDeviceProfiles.getForItem(item);local state=NMDeviceState.peek(item)
            local context=profile and state and recordedContext(sourceEnv,body,item,profile,state)
            local supplies=profile and context and state and SAO.LeisureMusicSupply
                and SAO.LeisureMusicSupply.plan(body,item,profile,state,context)
            if profile and context and profile.requiresBattery==true
                and not profile.requiresExternalPower and state and state.deviceUUID
                and (type(state.mediaFullType)=="string" and state.mediaFullType~=""or supplies and supplies.media)
                and (state.batteryPresent==true and finite(state.batteryCharge) and state.batteryCharge>0 or supplies and supplies.battery)
                and (tonumber(state.volume) or 0)>0 and not state.isMuted and not state.isPlaying
                and (SAO.LeisureMusicSupply and SAO.LeisureMusicSupply.outputMode(profile,state,context,supplies)
                    or NMDeviceProfiles.resolveOutputMode(profile,state,context,false))=="personal" then
                local d=descriptor(id,body,"listen-recorded-music",itemKey(item),"shared/TimedActions/PlayInstrumentActionNew.lua",evidence)
                d.sourceId="NewMusic";d.revision=pin("NewMusic","shared/audio/NMPlaybackRuntime.lua")
                d.itemType=item:getFullType();d.deviceUUID=state.deviceUUID;d.deviceRevision=state.revision
                d.playbackEpoch=state.playbackEpoch;d.sourceGeneration=state.sourceGeneration
                d.trackIndex=state.trackIndex;d.mediaFullType=state.mediaFullType;d.sourceContext=context
                d.sourceSupplies=plain(supplies)
                if supplies then d.materials=SAO.LeisureMusicSupply.materialKeys(supplies)end
                d.modeRevision=pin("NewMusic","client/sync/NMClientModeReconcile.lua")
                result[#result+1]=d
                if danceEvidence and personalRecordedDanceReady(id,body,intents) then
                    local dance=plain(d)
                    dance.id="music:"..id..":dance-to-recorded-music:"..d.itemKey
                    dance.activity="dance-to-recorded-music";dance.evidence=plain(danceEvidence)
                    dance.danceActionRevision=pin("LifestyleHobbies","shared/TimedActions/PlayerIsDancingToMusic.lua")
                    dance.nativeDuration="one-source-animation-cycle";dance.participationUnit="one-source-dance-cycle"
                    dance.requiresPreparation={sourceInitialization=not sourceState(body),sourceVoice=not voiceReady(data)}
                    result[#result+1]=dance
                end
            end
        end
    end
    publicAudioOffers(id,body,intents,result,evidence)
    return result
end
function M.offers(id,body)
    local ok,rows,why=pcall(candidates,id,body,false)
    if not ok then return {},"music-source-query-failed:"..tostring(rows) end
    return plain(rows),why
end
function M.intentOffers(id,body)
    local ok,rows,why=pcall(candidates,id,body,true)
    if not ok then return {},"music-source-query-failed:"..tostring(rows) end
    return plain(rows),why
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function bound(id,a)
    local rec=person(id);local w=rec and rec.leisureMusicWork
    return runtime[id]==a and w and w.status=="active" and w.sequence==a.sequence and live(id,a.body)
        and w.bodyToken==a.body:getModData().SAOExternalToken
end
local function finish(id,status,reason)
    local rec=person(id);local w=rec and rec.leisureMusicWork
    if not w or w.status~="active" then return false end
    local a=runtime[id]
    if status=="completed" and (not a or not a.started or not a.provenTerminal) then status,reason="interrupted","source-terminal-participation-unproven" end
    local current=a and live(id,a.body) and w.bodyToken==a.body:getModData().SAOExternalToken
    w.status=status;w.reason=reason;w.atHours=hours();w.after=current and measure(a.body) or w.lastMeasured
    w.afterCurrent=current==true;w.nativeNotes=plain(a and a.notes)
    w.measurementAuthority="actual-source-interval; concurrent-effects-not-isolated"
    w.cleanupSucceeded=a and a.cleanupSucceeded==true or false
    if a and recordedDance(a.offer)then
        w.terminalPhase=w.phase
        if a.danceCycle and not a.danceCycle.sourceCallbackCompleted then
            w.nativeProgress.sourceDanceCyclePartial=plain(a.danceCycle)
        end
    end
    if a and a.offer.sourceId=="NewMusic" and current and resolveItem(a.body,a.offer.itemKey)==a.item then
        w.afterPlaybackState=plain(NMDeviceState.export(NMDeviceState.peek(a.item)))
    else w.afterPlaybackState=plain(w.lastPlaybackState) end
    local row=plain(w);row.token=status=="completed" and "leisure:performed" or "leisure:interrupted"
    rec.leisureMusicOutcomes=rec.leisureMusicOutcomes or {};rec.leisureMusicOutcomes[#rec.leisureMusicOutcomes+1]=row
    if #rec.leisureMusicOutcomes>32 then table.remove(rec.leisureMusicOutcomes,1) end
    runtime[id]=nil
    if a and a.offer.duet and SAO.Organization and SAO.Organization.consumeDuet then
        SAO.Organization.consumeDuet(id,a.offer.duet.processId,w.sequence)
    end
    if a and a.offer.dance and SAO.Organization and SAO.Organization.consumeDance then
        SAO.Organization.consumeDance(id,a.offer.dance.processId,w.sequence)
    end
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeHobbyOutcome then SAO.ProceduralPlanning.consumeHobbyOutcome(id,w.sequence,OWNER) end
    return true
end
local function valid(id,a)
    local public=a.offer.audioSourceKey~=nil
    if not bound(id,a) or not activeSource(a.offer.sourceId)
        or (public and (a.body:isAsleep() or a.body:isSneaking() or a.body:isAiming()) or not public and not physical(a.body,true)) then return false end
    local planner=SAO.ProceduralPlanning;local w=person(id).leisureMusicWork
    local admission=planner and planner.hobbyAdmission and planner.hobbyAdmission(id,w.purposeId,w.workId)
    if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return false end
    if a.offer.duet then
        local agreement=SAO.Organization and SAO.Organization.duetOffer and SAO.Organization.duetOffer(id,a.offer.duet.processId)
        if not agreement or agreement.revision~=a.offer.duet.revision or agreement.choiceId~=a.offer.id
            or agreement.partnerId~=a.offer.duet.partnerId then return false end
    end
    if a.offer.instrumentType=="Vocal" then
        return sourceState(a.body) and frontReady(a.body,a.object)
            and resolveObject(id,a.body,a.offer.objectKey)==a.object and a.object:getSpriteName()==a.offer.objectSpriteName
    end
    if danceActivity(a.offer) then
        local partner=a.body:getModData().IsDancingPartner
        local heard=recordedDance(a.offer) and currentPersonalMusic(id,a.body) or M.currentHeardMusic(id,a.body)
        local binding=danceHeard(a)
        if recordedDance(a.offer) then
            if not activeSource("LifestyleHobbies") or not sourceState(a.body) or not voiceReady(a.body:getModData())
                or resolveItem(a.body,a.offer.itemKey)~=a.item or not a.supplying and not a.playbackStarted then return false end
            if a.supplying then return partner=="none"or partner==nil end
            local state=NMDeviceState.peek(a.item)
            if not state or not state.isPlaying or not state.isOn or state.isMuted then return false end
            for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
                if state[field]~=a.playback[field]then return false end
            end
            if not binding then return partner=="none"or partner==nil end
        end
        if a.offer.dance then
            local agreement=SAO.Organization and SAO.Organization.danceOffer and SAO.Organization.danceOffer(id,a.offer.dance.processId)
            if not agreement or agreement.revision~=a.offer.dance.revision or agreement.choiceId~=a.offer.id
                or agreement.partnerId~=a.offer.dance.partnerId or not partnerStyleAvailable(a.body:getModData())then return false end
            if a.danceReleased then
                return sourceState(a.body)and same(danceBinding(heard),binding)
                    and partner==a.offer.dance.role and a.body:getModData().IsDancingFullPartner==true
            end
        end
        return sourceState(a.body) and same(danceBinding(heard),binding)
            and (partner=="none" or not a.started and partner==nil)
    end
    if a.offer.instrumentType=="Piano" then
        return sourceState(a.body) and pianoReady(a.body,a.object)
            and resolveObject(id,a.body,a.offer.objectKey)==a.object
            and resolveObject(id,a.body,a.offer.pairObjectKey)==a.pairObject
            and a.object:getSpriteName()==a.offer.objectSpriteName and a.pairObject:getSpriteName()==a.offer.pairSpriteName
    end
    if public then
        local target,device=audioTarget(id,a.body,a.offer)
        return target and device==a.item and (a.offer.sourceContext=="placed" and target.object==a.target.object
            or a.offer.sourceContext=="vehicle" and target.vehicle==a.target.vehicle and target.part==a.target.part)
    end
    return resolveItem(a.body,a.offer.itemKey)==a.item
        and (a.offer.sourceId~="LifestyleHobbies" or (a.body:getPrimaryHandItem()==a.item and sourceState(a.body)))
end
local function observeSound(a,w)
    local handle=a.action.gameSound
    if handle and handle~=0 then
        local playing=a.body:getEmitter():isPlaying(handle)
        if playing then a.heard=true;w.nativeProgress.soundObserved=true;w.nativeProgress.sound= a.action.soundFile or a.action.lastSound
        elseif a.heard and a.lastHandle==handle then a.soundEnded=true end
        a.lastHandle=handle
    end
end
-- Transient source handles are available only for this exact admitted work.
function M.supplyContext(id,body,sequence)
    local a=runtime[id];local rec=person(id);local w=rec and rec.leisureMusicWork
    if not a or a.body~=body or not w or w.sequence~=sequence or not bound(id,a)
        or a.offer.sourceId~="NewMusic"or not a.offer.sourceSupplies or not activeSource("NewMusic")
        or body:isDead()or body:isAsleep()then return nil end
    local admission=SAO.ProceduralPlanning and SAO.ProceduralPlanning.hobbyAdmission
        and SAO.ProceduralPlanning.hobbyAdmission(id,w.purposeId,w.workId)
    if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return nil end
    local profile,target
    if a.offer.audioSourceKey then
        local current,device,p=audioTarget(id,body,a.offer)
        if not current or device~=a.item or not nearPublicControl(body,current,a.offer.sourceContext)then return nil end
        if a.offer.sourceContext=="placed"and(not SAO.Standing or not SAO.Standing.mayEnterCurrent
            or not SAO.Standing.mayEnterCurrent(id,current.object:getSquare():getX(),current.object:getSquare():getY()))then return nil end
        target=current;profile=p
    else
        if resolveItem(body,a.offer.itemKey)~=a.item then return nil end
        profile=NMDeviceProfiles.getForItem(a.item)
        local state=NMDeviceState.peek(a.item)
        if not profile or not state or recordedContext(a.env,body,a.item,profile,state)~=a.offer.sourceContext then return nil end
    end
    local state=profile and NMDeviceState.peek(a.item)
    if not state or state.deviceUUID~=a.offer.deviceUUID then return nil end
    return {body=body,bodyToken=w.bodyToken,workId=w.workId,purposeId=w.purposeId,device=a.item,profile=profile,
        deviceState=state,stateOwner=NMDeviceState,env=a.env,target=target,contextKey=a.offer.audioSourceKey or a.offer.itemKey,
        supplies=plain(a.offer.sourceSupplies)}
end
function M.publicPlaybackSources()
    local rows={}
    for id,a in pairs(runtime)do
        if #rows<24 and a.offer.audioSourceKey and a.playback and valid(id,a)then
            local target,device,profile=audioTarget(id,a.body,a.offer)
            local state=device and NMDeviceState.peek(device)
            local source=target and publicSource(target,a.offer.sourceContext)
            local range=profile and state and NMDeviceProfiles.computeWorldRange(profile,tonumber(state.volume)or 0)
            local observed=plain(a.offer.audioObservation)
            if observed and source then observed.x=source.x;observed.y=source.y;observed.z=source.z end
            if target and device==a.item and state and source and state.isOn and state.isPlaying and not state.isMuted
                and sourcePower(a.body,target,device,profile,state,a.offer.sourceContext)
                and finite(range)and range>0 and SAO.Perception.canHearLeisureSource(id,a.body,observed,range)==true then
                local sameBinding=true
                for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
                    if state[field]~=a.playback[field]then sameBinding=false end
                end
                if sameBinding then rows[#rows+1]={actorId=id,body=a.body,uuid=tostring(state.deviceUUID),
                    context=a.offer.sourceContext,source=source,state=state,profile=profile}end
            end
        end
    end
    -- Bounded stable insertion; source capacity is applied by its collection owner.
    for n=2,#rows do local row=rows[n];local j=n-1
        while j>=1 and (rows[j].uuid..":"..rows[j].actorId)>(row.uuid..":"..row.actorId)do rows[j+1]=rows[j];j=j-1 end
        rows[j+1]=row
    end
    return rows
end
function M.capturePublicEnding(uuid)
    local receipt=NMPlaybackRuntime.TrackEndAwaitingAdvance and NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
    if not receipt then return end
    for _,row in ipairs(M.publicPlaybackSources())do
        local a=runtime[row.actorId]
        if row.uuid==uuid and a.heard and a.firstHeardAtMs and a.recordedEmitter and a.recordedSoundId
            and a.recordedEmitter:isPlaying(a.recordedSoundId)==false then
            a.publicEndingReceipt=plain(receipt);a.publicEndingHeard=true
        end
    end
end
local function ensurePublicScheduling()
    local W=SAO.LeisureMusicWorld
    if not W or not W.install then error("public-source-scheduler-unavailable")end
    if W.current()then return end
    local env=setmetatable({},{__index=_G});env._G=env;env.require=function()end
    local modules={
        NMPlaybackRuntimeCommon="shared/audio/NMPlaybackRuntimeCommon.lua",
        NMPlaybackRuntime="shared/audio/NMPlaybackRuntime.lua",
        NMClientWorldSourceCache="client/cache/NMClientWorldSourceCache.lua",
        NMClientDetachedPlaybackPass="client/runtime/NMClientDetachedPlaybackPass.lua",
        NMClientTrackFinishedDispatch="client/runtime/NMClientTrackFinishedDispatch.lua",
        NMClientSPLocalRuntime="client/runtime/NMClientSPLocalRuntime.lua",
        NMClientPlaybackTick="client/runtime/NMClientPlaybackTick.lua",
        NMClientMainRuntime="client/runtime/NMClientMainRuntime.lua"}
    for name in pairs(modules)do env[name]={}end
    local audited={}
    for name,path in pairs(modules)do chunk(env,"NewMusic",path);audited[name]=env[name]end
    if not W.install(audited,M.publicPlaybackSources,M.capturePublicEnding)then error("public-source-executable-bindings-unverified")end
end
local function releasePartnerDance(id,a)
    if a.danceReleased then return true end
    local O=SAO.Organization;local agreement=O and O.danceReady and O.danceReady(id,a.offer.dance.processId)
    local peer=agreement and runtime[agreement.partnerId]
    if not peer or not peer.offer.dance or peer.offer.dance.processId~=a.offer.dance.processId
        or not peer.started or not valid(agreement.partnerId,peer)or not valid(id,a)
        or not ISTimedActionQueue.hasAction(a.action)or not ISTimedActionQueue.hasAction(peer.action)
        or not a.body:CanSee(peer.body)or not peer.body:CanSee(a.body)or a.body:getZ()~=peer.body:getZ()
        or a.body:isOutside()~=peer.body:isOutside()or math.abs(a.body:getX()-peer.body:getX())>1.5
        or math.abs(a.body:getY()-peer.body:getY())>1.5 then return false end
    local source=a.offer.dance.role=="source"and a or peer
    local target=source==a and peer or a
    if source.offer.dance.role~="source"or target.offer.dance.role~="target"
        or not sourceState(source.body)or not sourceState(target.body)then return false end
    -- Original native willingness producers are called only for these two
    -- already accepted maintained owners, followed by the original acceptance.
    source.env.JukeboxMenu.onEnableDancing(source.body);target.env.JukeboxMenu.onEnableDancing(target.body)
    local before={source={x=source.body:getX(),y=source.body:getY(),z=source.body:getZ()},
        target={x=target.body:getX(),y=target.body:getY(),z=target.body:getZ()}}
    target.env.PlayerIsAskedToDance(target.body,source.body:getUsername())
    if target.body:getModData().IsDancingPartner~="target"or target.body:getModData().IsDancingFullPartner~=true then return false end
    source.env.PlayerDanceWasAccepted(source.body,target.body:getUsername(),target.body:getX(),target.body:getY())
    target.env.PartnerFaceProposer(target.body,source.body:getX(),source.body:getY())
    if source.body:getModData().IsDancingPartner~="source"or source.body:getModData().IsDancingFullPartner~=true then return false end
    for _,owner in ipairs({source,target})do
        owner.danceReleased=true;owner.dancePeer=owner==source and target or source
        local w=person(owner.offer.actorId).leisureMusicWork
        w.nativeProgress.danceReleased=true
        w.nativeProgress.sourcePartnerSetup={sourceId="LifestyleHobbies",revision=pin("LifestyleHobbies","client/LSDanceEffects.lua"),
            choiceProducerRevision=pin("LifestyleHobbies","client/JukeboxContextMenu.lua"),processId=owner.offer.dance.processId,
            role=owner.offer.dance.role,partnerId=owner.offer.dance.partnerId,before=plain(before),
            after={x=owner.body:getX(),y=owner.body:getY(),z=owner.body:getZ()},atHours=hours()}
        w.phase="awaiting-native-partner-animation-cycle"
    end
    return true
end
local function retirePartnerDance(a,preservePeer)
    if not a.offer.dance then return end
    local id=a.offer.actorId;local peer=a.dancePeer;local failures={};local listenerState="not-registered"
    local function attempt(name,callback,requiresConfirmation)
        local ok,result=pcall(callback)
        if not ok then failures[#failures+1]={owner=name,reason=tostring(result)};return "failed"end
        if requiresConfirmation and result~=true then
            failures[#failures+1]={owner=name,reason="retirement-unconfirmed-or-already-absent"};return "unconfirmed-or-already-absent"
        end
        return "confirmed"
    end
    local peerActive=peer and runtime[peer.offer.actorId]==peer and peer.started and bound(peer.offer.actorId,peer)
        and peer.offer.dance and peer.offer.dance.processId==a.offer.dance.processId
    if peerActive and not preservePeer then
        attempt("original-PartnerStopDance",function()peer.env.PartnerStopDance(peer.body)end)
    end
    if a.started and a.body:getModData().SAOExternalToken==a.offer.bodyToken and a.body:getModData().SAOPersonId==id then
        attempt("original-onDisableDancing",function()a.env.JukeboxMenu.onDisableDancing(a.body)end)
    end
    if a.danceNativeWorkId then
        listenerState=attempt("native-animation-listener-retirement",function()
            if not a.danceNativeUnregister then error("captured-native-retirement-helper-unavailable")end
            return a.danceNativeUnregister(a.danceNativeBridge,a.body,a.danceNativeWorkId)
        end,true)
    end
    -- A failed own cleanup is an interruption, so the other source action
    -- must receive its original stop even when its cycle was still pending.
    if peerActive and preservePeer and #failures>0 then
        attempt("original-PartnerStopDance",function()peer.env.PartnerStopDance(peer.body)end)
    end
    local rec=person(id);local w=rec and rec.leisureMusicWork
    if w and w.sequence==a.sequence then
        w.nativeProgress.sourcePartnerCleanup={succeeded=#failures==0,failures=plain(failures),nativeListenerRetirement=listenerState}
    end
    if #failures>0 then a.cleanupSucceeded=false;a.failureReason=a.failureReason or"source-partner-cleanup-failed"end
end
local function completedPartnerDance(a,peer)
    if not peer or peer.offer.actorId~=a.offer.dance.partnerId or runtime[peer.offer.actorId]
        or not peer.started or not peer.danceReleased or not peer.performed or not peer.provenTerminal
        or peer.cleanupSucceeded~=true or not peer.partnerCycle or not peer.danceNativeWorkId
        or not peer.offer.dance or peer.offer.dance.partnerId~=a.offer.actorId
        or peer.offer.dance.processId~=a.offer.dance.processId
        or peer.offer.dance.revision~=a.offer.dance.revision
        or peer.offer.dance.musicKey~=a.offer.dance.musicKey
        or peer.offer.dance.role==a.offer.dance.role
        or not same(peer.offer.heardMusic,a.offer.heardMusic)
        or not live(peer.offer.actorId,peer.body) then return false end
    local rec=person(peer.offer.actorId)
    local work=rec and rec.leisureMusicWork
    local result=M.outcome(peer.offer.actorId,peer.sequence)
    local bind=result and result.sourceOffer and result.sourceOffer.dance
    local native=result and result.nativeProgress
    local cycle=native and native.sourcePartnerCycle
    return work~=nil and work.workId==peer.danceNativeWorkId
        and result~=nil and result.actorId==peer.offer.actorId
        and result.workId==peer.danceNativeWorkId and result.sequence==peer.sequence
        and result.status=="completed" and result.token=="leisure:performed"
        and result.sourceId=="LifestyleHobbies" and result.bodyToken==peer.offer.bodyToken
        and result.afterCurrent==true and result.cleanupSucceeded==true
        and result.measurementAuthority=="actual-source-interval; concurrent-effects-not-isolated"
        and finite(result.atHours) and result.atHours<=hours()
        and bind~=nil and bind.processId==a.offer.dance.processId
        and bind.revision==a.offer.dance.revision and bind.partnerId==a.offer.actorId
        and bind.role==peer.offer.dance.role and bind.musicKey==a.offer.dance.musicKey
        and native~=nil and native.danceReleased==true and native.sourcePerformReturned==true
        and native.sourcePartnerCleanup and native.sourcePartnerCleanup.succeeded==true
        and cycle~=nil and cycle.actorId==peer.offer.actorId
        and cycle.workId==peer.danceNativeWorkId and cycle.sequence==peer.partnerCycle.sequence
        and cycle.clip==peer.offer.roleAnimation
end
function M.nativeDanceCycleAllowed(body,workId,clip)
    if not body then return false end
    local id=body:getModData().SAOPersonId;local a=id and runtime[id]
    local rec=a and person(id);local w=rec and rec.leisureMusicWork;local peer=a and a.dancePeer
    return a~=nil and w~=nil and a.body==body and a.offer.dance~=nil and a.started==true and a.danceReleased==true
        and w.workId==workId and a.offer.roleAnimation==clip and valid(id,a)
        and ISTimedActionQueue.hasAction(a.action)and peer~=nil
        and ((runtime[peer.offer.actorId]==peer and peer.started==true and peer.danceReleased==true
            and valid(peer.offer.actorId,peer) and ISTimedActionQueue.hasAction(peer.action))
            or completedPartnerDance(a,peer))
        and body:CanSee(peer.body)and peer.body:CanSee(body)
        and body:getZ()==peer.body:getZ()and math.abs(body:getX()-peer.body:getX())<=1.5
        and math.abs(body:getY()-peer.body:getY())<=1.5
end
local function observePartnerDanceCycle(id,a)
    if not a.offer.dance or not a.danceReleased then return false end
    local w=person(id).leisureMusicWork
    if not SAOJavaBridge.registerNativeDanceCycle or not SAOJavaBridge.observeNativeDanceCycle
        or not SAOJavaBridge.nativeDanceCycleCurrent or not SAOJavaBridge.unregisterNativeDanceCycle
        or not SAOJavaBridge.nativeDanceCycleCompletionCurrent or not SAOJavaBridge.nativeDanceCycleCompletionReady
        or SAOJavaBridge:nativeDanceCycleCompletionReady()~=true then
        w.nativeProgress.nativeCycleOwnerState="native-animation-cycle-helper-unavailable";return false
    end
    if not a.danceNativeWorkId then
        if not SAOJavaBridge:registerNativeDanceCycle(a.body,w.workId,a.action.action,a.offer.roleAnimation)then
            w.nativeProgress.nativeCycleOwnerState="actual-current-native-action-or-role-track-unavailable";return false
        end
        a.danceNativeWorkId=w.workId
        a.danceNativeBridge=SAOJavaBridge;a.danceNativeUnregister=SAOJavaBridge.unregisterNativeDanceCycle
    end
    local cycle=SAOJavaBridge:observeNativeDanceCycle(a.body,w.workId)
    w.nativeProgress.nativeCycleOwnerState="awaiting-observed-native-loop"
    if not cycle then return false end
    if cycle.actorId~=id or cycle.bodyToken~=w.bodyToken or cycle.workId~=w.workId or cycle.clip~=a.offer.roleAnimation
        or cycle.authority~="native-current-owned-source-animation-loop"or not finite(cycle.engineAtHours)
        or not finite(cycle.sequence)or cycle.sequence<1 or cycle.sequence%1~=0
        or cycle.sequence<=(a.danceNativeSequence or 0)or not valid(id,a)
        or SAOJavaBridge:nativeDanceCycleCurrent(a.body,w.workId,cycle.sequence)~=true then return false end
    a.danceNativeSequence=cycle.sequence;a.partnerCycle=plain(cycle)
    w.nativeProgress.sourcePartnerCycle=plain(cycle)
    w.nativeProgress.sourcePartnerCycle.observedAtCountyHours=hours()
    w.nativeProgress.nativeCycleOwnerState="actual-native-source-loop-observed"
    return true
end
local function stopOwnedPlayback(id,a,reason)
    if a.playbackStopped then return a.playbackStopSucceeded end
    a.playbackStopped=true
    local w=person(id)and person(id).leisureMusicWork;local binding=a.playback
    if not binding then a.playbackStopSucceeded=true;return true end
    local renderer=a.env.NMPlaybackRuntime
    local entry=renderer and renderer.Active and renderer.Active[tostring(binding.deviceUUID)]
    local emitterExact=entry and entry.mode=="single" and entry.isWorldEmitter==false
        and entry.epoch==binding.playbackEpoch and entry.sourceGeneration==binding.sourceGeneration
        and entry.trackIndex==binding.trackIndex and entry.context==a.offer.sourceContext
        and entry.emitter==a.emitter and entry.emitter==a.body:getEmitter() and entry.soundId~=nil
    local data=a.body:getModData()
    local deadOwner=recordedDance(a.offer) and a.body:isDead() and runtime[id]==a
        and w and w.status=="active" and w.sequence==a.sequence and w.bodyToken==a.offer.bodyToken
        and data.SAOPersonId==id and data.SAOExternalToken==w.bodyToken
        and data.SAOExternalOwner==nil and data.ZAOOwned~=true and emitterExact==true
    local itemOwned=(live(id,a.body) or deadOwner) and resolveItem(a.body,a.offer.itemKey)==a.item
    local state=itemOwned and NMDeviceState.peek(a.item)
    local stateExact=type(state)=="table"
    if stateExact then
        for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
            if state[field]~=binding[field]then stateExact=false;break end
        end
    end
    local intentAccepted=false
    if stateExact and state.isPlaying then
        local ok,accepted=pcall(a.env.NMClientIntentDispatch.performIntent,a.body,a.item,"stop",{})
        intentAccepted=ok and accepted==true
    elseif stateExact and not state.isPlaying then intentAccepted=true end
    local emitterRetired=true
    if emitterExact then emitterRetired=pcall(renderer.forceStop,a.body,binding.deviceUUID,reason or "sao-personal-dance-terminal") end
    a.playbackStopSucceeded=stateExact and intentAccepted and emitterRetired
    if w and w.status=="active"then
        w.nativeProgress.sourcePlaybackStop={actorId=id,itemKey=a.offer.itemKey,bodyToken=w.bodyToken,
            deviceUUID=binding.deviceUUID,playbackEpoch=binding.playbackEpoch,sourceGeneration=binding.sourceGeneration,
            trackIndex=binding.trackIndex,mediaFullType=binding.mediaFullType,sourceStateExact=stateExact==true,
            personalEmitterRetired=emitterExact==true and emitterRetired,sourceStopAccepted=intentAccepted,
            atHours=hours(),reason=reason}
    end
    return a.playbackStopSucceeded
end
local function bindAction(id,a,class)
    local action=a.action;local body=a.body;local native={start=class.start,update=class.update,perform=class.perform,stop=class.stop,valid=class.isValid}
    a.actionBound=true
    action.isValid=function(self) return valid(id,a) and native.valid(self) end
    action.start=function(self)
        if a.started then return end
        if not self:isValid() then self:forceStop();return end
        local ok,why=pcall(native.start,self)
        if not ok then a.failureReason="source-start-failed:"..tostring(why);self:stop();self:forceStop();return end
        a.started=true
        person(id).leisureMusicWork.nativeProgress.started=true
        if a.offer.instrumentType=="Piano" then
            local position={bodyToken=body:getModData().SAOExternalToken,objectKey=a.offer.objectKey,
                x=body:getX(),y=body:getY(),z=body:getZ(),sourceOffsetApplied=a.env.LSUtil.pianoPos==true}
            person(id).leisureMusicPianoPosition=plain(position)
            person(id).leisureMusicWork.nativeProgress.sourcePositionAfter=plain(position)
        end
    end
    action.update=function(self)
        if not self:isValid() then self:forceStop();return end
        if not a.started then return end
        if a.offer.dance and not a.danceReleased then
            local released,why=pcall(releasePartnerDance,id,a)
            if not released then a.failureReason="source-partner-acceptance-failed:"..tostring(why);self:stop();self:forceStop();return end
            if not why then return end
        end
        if a.offer.duet and a.body:getModData().WaitingDuet then
            local agreement=SAO.Organization.duetReady and SAO.Organization.duetReady(id,a.offer.duet.processId)
            local partner=agreement and runtime[agreement.partnerId]
            if partner and partner.started and valid(agreement.partnerId,partner)
                and a.body:CanSee(partner.body) and partner.body:CanSee(a.body)
                and a.body:getZ()==partner.body:getZ() and a.body:isOutside()==partner.body:isOutside()
                and math.abs(a.body:getX()-partner.body:getX())<=8 and math.abs(a.body:getY()-partner.body:getY())<=8 then
                a.env.OtherPlayerIsStartingDuet(a.body,false)
                partner.env.OtherPlayerIsStartingDuet(partner.body,false)
                local ownWork=person(id).leisureMusicWork
                local partnerWork=person(agreement.partnerId).leisureMusicWork
                local releasedAt=hours()
                ownWork.nativeProgress.duetReleased=true
                partnerWork.nativeProgress.duetReleased=true
                ownWork.nativeProgress.duetRelease={processId=agreement.processId,revision=agreement.revision,
                    partnerId=agreement.partnerId,partnerWorkId=partnerWork.workId,atHours=releasedAt}
                partnerWork.nativeProgress.duetRelease={processId=agreement.processId,revision=agreement.revision,
                    partnerId=id,partnerWorkId=ownWork.workId,atHours=releasedAt}
            end
        end
        local w=person(id).leisureMusicWork
        local ok,why=pcall(function()
            observeSound(a,w)
            local rec=person(id);rec.leisureMusicInvocationSequence=(rec.leisureMusicInvocationSequence or 0)+1
            a.sourceCallback="update";a.sourceInvocationSequence=rec.leisureMusicInvocationSequence
            native.update(self);a.sourceCallback=nil
            if danceActivity(a.offer) and a.danceCycle then a.danceCycle.sourceCallbackCompleted=true end
            if not bound(id,a) then return end
            observeSound(a,w)
            w.nativeProgress.observedUpdates=w.nativeProgress.observedUpdates+1
            local delta=self:getJobDelta();if finite(delta) then w.nativeProgress.delta=delta end
            w.lastMeasured=measure(body)
            w.phase=a.offer.dance and "awaiting-native-partner-animation-cycle"
                or recordedDance(a.offer) and "executing-native-dance"or"executing"
            if a.offer.dance and observePartnerDanceCycle(id,a)then self:forceComplete()end
            if danceActivity(a.offer) and not a.offer.dance and a.danceCycle and a.danceCycle.sourceCallbackCompleted then
                w.nativeProgress.sourceDanceCycle=plain(a.danceCycle)
                -- The installed source's failed move has later fall/embarrassment
                -- and stop-owned injury effects. Keep its own sequence running.
                if self.criticalFailure==0 then self:forceComplete() end
            end
        end)
        if not ok and bound(id,a) then a.failureReason="source-update-failed:"..tostring(why);self:stop();self:forceStop() end
    end
    action.perform=function(self)
        if not self:isValid() or not a.started or a.performed or not ISTimedActionQueue.hasAction(self) then return end
        local w=person(id).leisureMusicWork
        local nativePartner=a.offer.dance and a.partnerCycle and a.danceNativeWorkId==w.workId
            and SAOJavaBridge.nativeDanceCycleCompletionCurrent
            and SAOJavaBridge:nativeDanceCycleCompletionCurrent(body,w.workId,a.partnerCycle.sequence)==true
        local solo=a.danceCycle and a.danceCycle.sourceCallbackCompleted==true
            and self.criticalFailure==0
            and same(danceBinding(M.currentHeardMusic(id,body)),danceHeard(a))
        local dance=danceActivity(a.offer)and (nativePartner or not a.offer.dance and solo)
        local proven=w.nativeProgress.observedUpdates>0 and (dance or a.heard
            and (((a.offer.activity=="perform-instrument" or a.offer.activity=="perform-vocal-duet") and a.soundEnded) or
                (a.offer.activity=="practice-instrument" and self:getJobDelta()>=1)))
        if not proven then self:stop();self:forceStop();return end
        -- Original perform may restore both previously held objects. Requery
        -- exact private carried custody before allowing that native cleanup.
        for _,field in ipairs({"handItemP","handItemS"})do
            local value=self[field]
            if value and value~=0 and resolveItem(body,itemKey(value))~=value then self[field]=0 end
        end
        a.performed=true;a.provenTerminal=true
        w.nativeProgress.sourceSoundEnded=a.soundEnded==true
        local rec=person(id);rec.leisureMusicInvocationSequence=(rec.leisureMusicInvocationSequence or 0)+1
        a.sourceCallback="perform";a.sourceInvocationSequence=rec.leisureMusicInvocationSequence
        local succeeded,why,trace=pcall(native.perform,self);a.cleanupSucceeded=succeeded;a.sourceCallback=nil
        w.nativeProgress.sourcePerformReturned=succeeded
        if danceActivity(a.offer)then
            local cleaned=pcall(function()for handle in pairs(a.danceSounds or {})do a.emitter:stopSound(handle)end end)
            a.cleanupSucceeded=a.cleanupSucceeded and cleaned
            retirePartnerDance(a,nativePartner and succeeded)
        end
        if recordedDance(a.offer)then
            a.cleanupSucceeded=stopOwnedPlayback(id,a,"sao-personal-dance-terminal")and a.cleanupSucceeded
        end
        local failure=not succeeded and "source-perform-failed:"..tostring(why)..":"..tostring(trace)
            or not a.cleanupSucceeded and (a.failureReason or "source-cleanup-failed") or nil
        finish(id,a.cleanupSucceeded and "completed" or "interrupted",failure)
    end
    action.stop=function(self)
        if not bound(id,a) then return end
        if live(id,body) and a.started then
            -- Source cleanup must not restore an item that changed custody.
            for _,field in ipairs({"handItemP","handItemS"}) do
                local value=self[field]
                if value and value~=0 and resolveItem(body,itemKey(value))~=value then self[field]=0 end
            end
            if danceActivity(a.offer) then a.sourceCallback="stop"end
            a.cleanupSucceeded=pcall(native.stop,self)
            if danceActivity(a.offer)then
                local cleaned=pcall(function()for handle in pairs(a.danceSounds or {})do a.emitter:stopSound(handle)end end)
                a.cleanupSucceeded=a.cleanupSucceeded and cleaned
                retirePartnerDance(a)
            end
            if danceActivity(a.offer) then a.sourceCallback=nil end
        end
        if recordedDance(a.offer)then
            local actionCleanup=not a.started or a.cleanupSucceeded==true
            a.cleanupSucceeded=stopOwnedPlayback(id,a,a.failureReason or "source-dance-stopped")and actionCleanup
        end
        finish(id,"interrupted",a.failureReason or "source-stopped")
    end
    action.forceCancel=function() if bound(id,a) then action:stop() end end
end
local function startRecordedPlayback(id,a)
    local body,current,w=a.body,a.offer,person(id).leisureMusicWork
        local accepted,err=pcall(function()
            local prior=NMDeviceState.peek(a.item)
            local function intent(action)
                if current.sourceContext=="vehicle" then
                    return a.env.NMClientIntentDispatch.performVehicleIntent(body,a.target.vehicle,a.target.part,action,{})
                end
                return a.env.NMClientIntentDispatch.performIntent(body,a.item,action,{})
            end
            if current.audioSourceKey and not prior.isPlaying and not nearPublicControl(body,a.target,current.sourceContext) then error("source-control-not-accessible")end
            if not prior.isOn and not intent("power_on") then error("source-power-intent-refused") end
            if not prior.isPlaying and not intent("play") then error("source-play-intent-refused") end
            local state=NMDeviceState.peek(a.item)
            if not state or state.deviceUUID~=current.deviceUUID or not state.isPlaying then error("source-playing-state-unavailable") end
            a.playback={deviceUUID=state.deviceUUID,revision=state.revision,playbackEpoch=state.playbackEpoch,
                sourceGeneration=state.sourceGeneration,trackIndex=state.trackIndex,mediaFullType=state.mediaFullType}
            w.playback=plain(a.playback);a.playbackStarted=true
            w.nativeProgress.sourcePlaybackIntent=plain(a.playback)
            if recordedDance(current)then w.phase="awaiting-source-personal-hearing"
            else a.started=true end
            if current.audioSourceKey then
                NMClientPlaybackTick.requestFullPass("sao-selected-acquired-source")
                w.rendererRevisionAuthority="audited executable functions/captured callable and scalar shapes; exact live environment/dependency bindings"
            end
        end)
        if not accepted then return false,"source-play-intent-failed:"..tostring(err)end
        return true
end
function M.begin(id,body,offer,purposeId)
    local rows,why=M.offers(id,body);local current
    for _,row in ipairs(rows) do if same(row,offer) then current=row;break end end
    if not current then return false,why or "stale-or-foreign-music-offer" end
    local rec=person(id)
    if SAO.LeisureMusicSupply then SAO.LeisureMusicSupply.retireSaved(id,"runtime-owner-lost")end
    if rec.leisureMusicWork and rec.leisureMusicWork.status=="active" then finish(id,"interrupted","runtime-owner-lost") end
    local ok,a=pcall(function()
        local env=danceActivity(current) and danceSourceEnv(id,body)
            or current.sourceId=="LifestyleHobbies" and lifestyleEnv(id,body) or recordedSourceEnv(id,body)
        local result={body=body,offer=current,env=env,item=resolveItem(body,current.itemKey),emitter=body:getEmitter()}
        if current.sourceId=="NewMusic" then
            if recordedDance(current)then
                chunk(env,"NewMusic","shared/helpers/NMAttachmentHelpers.lua")
                chunk(env,"NewMusic","client/sync/NMClientModeReconcile.lua")
            end
            chunk(env,"NewMusic","shared/audio/NMPlaybackRuntimeCommon.lua")
            chunk(env,"NewMusic","shared/audio/NMPlaybackRuntime.lua")
            if current.audioSourceKey then
                local target,device=audioTarget(id,body,current)
                if not target then error("public-audio-custody-lost")end
                result.target=target;result.item=device
                ensurePublicScheduling()
                env.NMPlaybackRuntime=NMPlaybackRuntime;env.NMPlaybackRuntimeCommon=NMPlaybackRuntimeCommon
            end
            if SAO.LeisureMusicSupply then SAO.LeisureMusicSupply.prepareEnvironment(env)end
            chunk(env,"NewMusic","client/intents/NMClientIntentDispatch.lua")
            result.nativeOwner=current.audioSourceKey and "NMClientIntentDispatch original intent; NMPlaybackRuntime shared physical UUID observer"
                or "NMClientIntentDispatch.performIntent/NMPlaybackRuntime.syncDevice"
            if recordedDance(current)then
                chunk(env,"LifestyleHobbies","shared/TimedActions/PlayerIsDancingToMusic.lua")
                result.class=env.PlayerIsDancingToMusic
                result.action=result.class:new(body,"Bob_PreDancingDefault")
                result.nativeOwner="NMClientIntentDispatch/NMPlaybackRuntime personal emitter; PlayerIsDancingToMusic actor-private original action"
            end
        else
            local name=current.activity=="practice-instrument" and "PlayInstrumentTraining"
                or current.activity=="dance" and "PlayerIsDancingToMusic"
                or current.instrumentType=="Vocal" and "PlayInstrumentVocal" or "PlayInstrumentActionNew"
            if current.duet then chunk(env,"LifestyleHobbies","client/LSIsListeningEffects.lua") end
            chunk(env,"LifestyleHobbies","shared/TimedActions/"..name..".lua")
            local class=env[name];result.class=class;result.nativeOwner=name.." (isolated original source)"
            if current.instrumentType=="Piano" then
                result.object=resolveObject(id,body,current.objectKey);result.pairObject=resolveObject(id,body,current.pairObjectKey)
                if not result.object or not result.pairObject then error("piano-object-custody-lost") end
                local prior=rec.leisureMusicPianoPosition
                if prior and prior.sourceOffsetApplied and prior.bodyToken==current.bodyToken
                    and prior.objectKey==current.objectKey and prior.x==body:getX() and prior.y==body:getY()
                    and prior.z==body:getZ() and body:isSittingOnFurniture() then env.LSUtil.pianoPos=true end
                if current.activity=="practice-instrument" then result.action=class:new(body,current.objectSpriteName,"Piano",result.object)
                else result.action=class:new(body,current.objectSpriteName,"Piano",current.sound,current.length*48,current.trackLevel,false,current.isDuet==true,result.object) end
            elseif current.instrumentType=="Vocal" then
                result.object=resolveObject(id,body,current.objectKey);if not result.object then error("microphone-custody-lost") end
                result.action=class:new(body,result.object,current.micType,current.sound,current.length*48,current.trackLevel,false,true)
            elseif current.activity=="practice-instrument" then result.action=class:new(body,result.item,current.instrumentType)
            elseif current.activity=="dance" then result.action=class:new(body,"Bob_PreDancingDefault")
            else result.action=class:new(body,result.item,current.instrumentType,current.sound,current.length*48,current.trackLevel,false,current.isDuet==true) end
        end
        if current.dance then
            chunk(env,"LifestyleHobbies","client/LSDanceEffects.lua")
            chunk(env,"LifestyleHobbies","client/JukeboxContextMenu.lua")
        end
        return result
    end)
    if not ok then return false,"source-construction-failed:"..tostring(a) end
    rec.leisureMusicSequence=(rec.leisureMusicSequence or 0)+1;a.sequence=rec.leisureMusicSequence
    local w={actorId=id,sequence=a.sequence,workId="music:"..id..":"..a.sequence,purposeId=purposeId,
        family="music",sourceId=current.sourceId,revision=current.revision,activity=current.activity,itemKey=current.itemKey,
        itemType=current.itemType,bodyToken=current.bodyToken,bodyGenerationKnown=current.bodyGenerationKnown,
        admittedAtHours=hours(),status="active",phase="prepared",nativeOwner=a.nativeOwner,
        nativeProgress={delta=0,observedUpdates=0},before=measure(body),evidence=plain(current.evidence),
        revisionAuthority=current.revisionAuthority,sourceOffer=plain(current)}
    if danceActivity(current)then
        w.participationUnit=current.participationUnit
        w.sourceAdaptations={kind="original-audio-tracing-and-action-owned-bindings",sites=plain(a.env.danceTraceSites),
            ownershipSites=plain(a.env.danceOwnershipSites),rawRevision=current.danceActionRevision or current.revision,
            derivedRevision=plain(a.env.danceDerivedRevision)}
        if not recordedDance(current)then
            w.nativeOwner="PlayerIsDancingToMusic (actor-private original callbacks; four traced original emitter calls; two action-owned reads)"
        end
    end
    if current.instrumentType=="Piano" then w.nativeProgress.sourcePositionBefore={x=body:getX(),y=body:getY(),z=body:getZ()} end
    rec.leisureMusicWork=w;runtime[id]=a
    if current.sourceId=="NewMusic" then w.beforePlaybackState=plain(NMDeviceState.export(NMDeviceState.peek(a.item))) end
    local planner=SAO.ProceduralPlanning
    if not planner or not planner.admitHobbyWork or not planner.admitHobbyWork(id,purposeId,w.sequence,OWNER) then
        finish(id,"interrupted","music-planner-admission-refused");return false,"music-planner-admission-refused"
    end
    if current.sourceId=="NewMusic" then
        if current.sourceSupplies then
            a.supplying=true;w.phase="preparing-source-supplies"
            local admitted,reason=SAO.LeisureMusicSupply.begin(id,body,w.sequence)
            if not admitted then M.interrupt(id,body,"source-supply-refused:"..tostring(reason));return false,"source-supply-refused"end
        else
            local accepted,reason=startRecordedPlayback(id,a)
            if not accepted then M.interrupt(id,body,reason);return false,reason end
        end
    else
        bindAction(id,a,a.class)
        local admitted=pcall(ISTimedActionQueue.add,a.action)
        if not admitted or not ISTimedActionQueue.hasAction(a.action) then finish(id,"interrupted","source-queue-refused");return false,"source-queue-refused" end
        if current.duet and not SAO.Organization.admitDuet(id,current.duet.processId,w.sequence) then
            M.interrupt(id,body,"duet-admission-refused");return false,"duet-admission-refused"
        end
        if current.dance and not SAO.Organization.admitDance(id,current.dance.processId,w.sequence)then
            M.interrupt(id,body,"dance-admission-refused");return false,"dance-admission-refused"
        end
    end
    return true,plain(w)
end
function M.work(id)
    local a=runtime[id];return a and bound(id,a) and plain(person(id).leisureMusicWork) or nil
end
local function advanceRecorded(id,a)
    local state=NMDeviceState.peek(a.item);local binding=a.playback;local w=person(id).leisureMusicWork
    if not state then error("source-device-state-lost") end
    for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"}) do
        if state[field]~=binding[field] then error("source-playback-identity-changed:"..field) end
    end
    local profile=NMDeviceProfiles.getForItem(a.item)
    local context=recordedContext(a.env,a.body,a.item,profile,state)
    if context~=a.offer.sourceContext or NMDeviceProfiles.resolveOutputMode(profile,state,context,false)~="personal" then error("source-device-location-or-output-changed") end
    a.env.NMPlaybackRuntime.syncDevice(a.body,profile,state,{mode=context,context=context},w.nativeProgress.observedUpdates)
    w.nativeProgress.observedUpdates=w.nativeProgress.observedUpdates+1
    w.lastMeasured=measure(a.body);w.lastBatteryCharge=state.batteryCharge
    w.lastPlaybackState=plain(NMDeviceState.export(state))
    local entry=a.env.NMPlaybackRuntime.Active[tostring(binding.deviceUUID)]
    if recordedDance(a.offer)then
        local fact=currentPersonalMusic(id,a.body)
        if fact then
            local heard=danceBinding(fact)
            if a.danceHeardMusic and not same(a.danceHeardMusic,heard)then error("source-personal-hearing-identity-changed")end
            a.danceHeardMusic=heard;a.heard=true
            a.recordedEmitter=entry.emitter;a.recordedSoundId=entry.soundId
            w.nativeProgress.soundObserved=true;w.nativeProgress.sound=fact.sound
            w.nativeProgress.sourcePersonalHearing=plain(fact)
            w.phase=a.danceQueued and "executing-native-dance"or"personal-hearing-observed"
        elseif a.danceHeardMusic then error("source-personal-hearing-lost")
        else w.phase="awaiting-source-personal-hearing"end
    elseif entry and entry.epoch==binding.playbackEpoch and entry.sourceGeneration==binding.sourceGeneration
        and entry.trackIndex==binding.trackIndex then
        local channel=entry.mode=="dual" and (entry.personal or entry.world) or entry
        if channel and channel.emitter and channel.soundId then
            if a.recordedEmitter~=channel.emitter or a.recordedSoundId~=channel.soundId then a.heard=false end
            a.recordedEmitter=channel.emitter;a.recordedSoundId=channel.soundId
        end
        if channel and channel.emitter and channel.soundId and channel.emitter:isPlaying(channel.soundId) then
            a.heard=true;w.nativeProgress.soundObserved=true;w.nativeProgress.sound=channel.sound;w.phase="executing"
        end
    end
    local token=a.env.NMPlaybackRuntime.consumeTrackEndedToken(binding.deviceUUID)
    if token then
        if recordedDance(a.offer)then error("source-track-ended-before-native-dance-cycle")end
        local await=a.env.NMPlaybackRuntime.TrackEndAwaitingAdvance[tostring(binding.deviceUUID)]
        local endingEvidence=await and await.playbackEpoch==binding.playbackEpoch and await.sourceGeneration==binding.sourceGeneration
            and await.trackIndex==binding.trackIndex and finite(token.falseCount) and finite(token.falseChecks)
            and token.falseCount>=token.falseChecks and finite(token.pendingElapsedMs) and finite(token.windowMs)
            and token.pendingElapsedMs>=token.windowMs and finite(token.confirmedAtMs)
            and token.confirmedAtMs<=a.env.NMPlaybackRuntimeCommon.getNowRealMs()
            and a.recordedEmitter and a.recordedSoundId and a.recordedEmitter:isPlaying(a.recordedSoundId)==false
        if not endingEvidence then error("source-debounced-audio-ending-unproven") end
        if not a.heard or token.uuid~=tostring(binding.deviceUUID) or token.playbackEpoch~=binding.playbackEpoch
            or token.sourceGeneration~=binding.sourceGeneration or token.trackIndex~=binding.trackIndex
            or token.context~=a.offer.sourceContext
            or not finite(token.observedDurationMs) or token.observedDurationMs<=0 then error("source-track-ending-unproven") end
        w.nativeProgress.trackEnded=plain(token);a.provenTerminal=true
        -- An exact source stop ends this bounded listening purpose; track
        -- progression for another purpose is never inferred from this token.
        a.cleanupSucceeded=a.env.NMClientIntentDispatch.performIntent(a.body,a.item,"stop",{})==true
        a.env.NMPlaybackRuntime.forceStop(a.body,binding.deviceUUID,"sao-listening-terminal")
        finish(id,a.cleanupSucceeded and "completed" or "interrupted",not a.cleanupSucceeded and "source-stop-refused" or nil)
        return
    end
    if not state.isPlaying or not state.batteryPresent or state.batteryCharge<=0 then error("source-playback-stopped-or-power-lost") end
end
local function advancePublicAudio(id,a)
    local target,device,profile=audioTarget(id,a.body,a.offer)
    if not target or device~=a.item then error("public-source-custody-lost")end
    local state=NMDeviceState.peek(device);local b=a.playback;local w=person(id).leisureMusicWork
    if not state then error("public-source-state-lost")end
    local source=publicSource(target,a.offer.sourceContext)
    local R=NMPlaybackRuntime
    if R~=a.env.NMPlaybackRuntime then error("public-renderer-replaced")end
    if not sourcePower(a.body,target,device,profile,state,a.offer.sourceContext)then error("public-source-power-lost")end
    local range=NMDeviceProfiles.computeWorldRange(profile,tonumber(state.volume)or 0)
    local acquired=plain(a.offer.audioObservation)
    acquired.x=source.x;acquired.y=source.y;acquired.z=source.z
    local heard=finite(range) and range>0 and SAO.Perception and SAO.Perception.canHearLeisureSource
        and SAO.Perception.canHearLeisureSource(id,a.body,acquired,range)==true
    if not SAO.LeisureMusicWorld or not SAO.LeisureMusicWorld.current()then error("public-source-executable-bindings-changed")end
    local endReceipt=a.publicEndingReceipt or R.TrackEndAwaitingAdvance and R.TrackEndAwaitingAdvance[tostring(b.deviceUUID)]
    local proven=endReceipt and endReceipt.playbackEpoch==b.playbackEpoch and endReceipt.trackIndex==b.trackIndex
        and endReceipt.sourceGeneration==b.sourceGeneration and endReceipt.context==a.offer.sourceContext
        and finite(endReceipt.falseCount) and finite(endReceipt.falseChecks) and endReceipt.falseCount>=endReceipt.falseChecks
        and finite(endReceipt.pendingElapsedMs) and finite(endReceipt.windowMs) and endReceipt.pendingElapsedMs>=endReceipt.windowMs
        and finite(endReceipt.setAtMs) and endReceipt.setAtMs<=NMPlaybackRuntimeCommon.getNowRealMs()
        and a.firstHeardAtMs and endReceipt.setAtMs>a.firstHeardAtMs
        and a.recordedEmitter and a.recordedSoundId and a.recordedEmitter:isPlaying(a.recordedSoundId)==false
    -- This source-owned confirmation can outlive its consumed TrackEnded token.
    -- It is copied, never removed; native progression remains with its owner.
    if a.heard and proven and (heard or a.publicEndingHeard) then
        w.nativeProgress.sourceTrackEndAwaitingAdvance=plain(endReceipt)
        a.provenTerminal=true;a.cleanupSucceeded=true
        finish(id,"completed");return
    end
    for _,field in ipairs({"deviceUUID","revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
        if state[field]~=b[field]then error("public-playback-identity-changed:"..field)end
    end
    if not state.isPlaying or not state.isOn or state.isMuted then error("public-source-stopped")end
    w.nativeProgress.observedUpdates=w.nativeProgress.observedUpdates+1
    w.lastMeasured=measure(a.body);w.lastPlaybackState=plain(NMDeviceState.export(state))
    local entry=R.Active and R.Active[tostring(b.deviceUUID)]
    local channel=entry and (entry.mode=="dual" and entry.world or entry)
    local audibility=R.computeLocalListenerAudibility(a.body,profile,state,source)
    local listenerVolume=audibility and audibility.worldVolume
    if a.offer.sourceContext=="vehicle" and audibility and audibility.originalOutputMode=="world"
        and audibility.localVehiclePersonalOverride then listenerVolume=audibility.personalVolume end
    if entry and entry.epoch==b.playbackEpoch and entry.sourceGeneration==b.sourceGeneration and entry.trackIndex==b.trackIndex
        and entry.context==a.offer.sourceContext and channel and channel.isWorldEmitter==true
        and channel.emitter and channel.soundId and channel.emitter:isPlaying(channel.soundId)
        and audibility and audibility.shouldPlay and finite(listenerVolume) and listenerVolume>.001
        and finite(range) and range>0 and heard then
        if a.recordedEmitter~=channel.emitter or a.recordedSoundId~=channel.soundId then a.firstHeardAtMs=nil end
        a.recordedEmitter=channel.emitter;a.recordedSoundId=channel.soundId
        a.firstHeardAtMs=a.firstHeardAtMs or NMPlaybackRuntimeCommon.getNowRealMs()
        a.heard=true;w.nativeProgress.soundObserved=true;w.nativeProgress.sound=channel.sound
        w.nativeProgress.hearingObservedUpdates=(w.nativeProgress.hearingObservedUpdates or 0)+1
        w.nativeProgress.sourceAudibility={listenerVolume=listenerVolume,worldVolume=audibility.worldVolume,
            personalVolume=audibility.personalVolume,vehicleOccupant=audibility.localVehiclePersonalOverride,range=range,nativeHeard=true}
        w.phase="executing"
    else w.phase="awaiting-source-world-hearing" end
end
function M.advance(id,body)
    local rec=person(id);local w=rec and rec.leisureMusicWork
    if not w or w.status~="active" then return false,"music-work-unavailable" end
    local a=runtime[id]
    if not a then finish(id,"interrupted","runtime-owner-lost");return false,"runtime-owner-lost" end
    if body~=a.body then return false,"foreign-body" end
    if not valid(id,a) then M.interrupt(id,body,"music-source-ownership-lost");return false,"music-source-ownership-lost" end
    if a.offer.sourceId=="NewMusic" then
        if a.supplying then
            local held,status,receipt=SAO.LeisureMusicSupply.advance(id,body,w.sequence)
            if not held then M.interrupt(id,body,"source-supply-lost:"..tostring(status));return false,"source-supply-lost"end
            if status=="preparing"then return true,M.work(id)end
            local fresh
            local queried,rows=pcall(candidates,id,body,false,a)
            for _,row in ipairs(queried and rows or {})do
                if row.sourceId==a.offer.sourceId and row.activity==a.offer.activity and row.itemKey==a.offer.itemKey
                    and row.deviceUUID==a.offer.deviceUUID and row.sourceContext==a.offer.sourceContext
                    and row.audioSourceKey==a.offer.audioSourceKey and row.bodyToken==a.offer.bodyToken
                    and row.revision==a.offer.revision and not row.sourceSupplies then fresh=row;break end
            end
            if not fresh then M.interrupt(id,body,"source-supply-fresh-offer-unavailable");return false,"source-supply-fresh-offer-unavailable"end
            if not SAO.LeisureMusicSupply.release(id,body,w.sequence)then M.interrupt(id,body,"source-supply-receipt-lost");return false,"source-supply-receipt-lost"end
            w.nativeProgress.sourceSupplyPreparation=plain(receipt);w.afterSupplyOffer=plain(fresh)
            a.offer=fresh;a.supplying=false
            local started,reason=startRecordedPlayback(id,a)
            if not started then M.interrupt(id,body,reason);return false,reason end
        end
        local ok,why=pcall(a.offer.audioSourceKey and advancePublicAudio or advanceRecorded,id,a)
        if not ok then M.interrupt(id,body,"source-playback-failed:"..tostring(why));return false,"source-playback-failed" end
        if recordedDance(a.offer) and a.danceHeardMusic and not a.danceQueued then
            bindAction(id,a,a.class)
            local admitted=pcall(ISTimedActionQueue.add,a.action)
            if not admitted or not ISTimedActionQueue.hasAction(a.action)then
                M.interrupt(id,body,"source-dance-queue-refused");return false,"source-dance-queue-refused"
            end
            a.danceQueued=true;w.nativeProgress.sourceDanceQueued=true
            w.phase="awaiting-native-dance-action"
        elseif recordedDance(a.offer) and a.danceQueued and not ISTimedActionQueue.hasAction(a.action)then
            M.interrupt(id,body,"source-dance-action-owner-lost");return false,"source-dance-action-owner-lost"
        end
    elseif not ISTimedActionQueue.hasAction(a.action) then
        M.interrupt(id,body,"source-action-owner-lost");return false,"source-action-owner-lost"
    end
    return true,M.work(id)
end
function M.outcome(id,sequence)
    local rec=person(id)
    for _,row in ipairs(rec and rec.leisureMusicOutcomes or {}) do if row.actorId==id and row.sequence==sequence then return plain(row) end end
end
function M.skillRequest(id,workSequence,sequence)
    local a=runtime[id]
    if not a or not bound(id,a) or a.sequence~=workSequence or not a.action or not a.started or not valid(id,a)
        or not ISTimedActionQueue.hasAction(a.action) then return nil end
    local row=a.skillRequests and a.skillRequests[sequence]
    if row and row.actorId==id and row.workSequence==workSequence and row.sequence==sequence
        and row.nativeProgress.sourceCallback==a.sourceCallback
        and row.nativeProgress.sourceInvocationSequence==a.sourceInvocationSequence then return plain(row) end
end
function M.interrupt(id,body,reason)
    local a=runtime[id]
    if a and a.body~=body then return false,"foreign-body" end
    if a then
        a.failureReason=reason or "person-interrupted"
        if a.offer.sourceId=="NewMusic" then
            if a.supplying and SAO.LeisureMusicSupply then SAO.LeisureMusicSupply.interrupt(id,body,a.failureReason)end
            if a.offer.audioSourceKey then
                -- Ending one person's listening never stops a shared device.
                a.cleanupSucceeded=true
            else a.cleanupSucceeded=stopOwnedPlayback(id,a,reason or "sao-interrupted")end
        end
        if a.action and (not recordedDance(a.offer) or a.actionBound)then
            local danceDeathRetired=false
            if danceActivity(a.offer) and a.started and a.body:getModData().SAOExternalToken==a.offer.bodyToken
                and a.body:getModData().SAOPersonId==id and a.body:isDead()then
                -- Original perform only restores own hands, clears dance flags
                -- and retires this action. It grants no stats/XP/injury/social effect.
                for _,field in ipairs({"handItemP","handItemS"})do
                    local value=a.action[field]
                    if value and value~=0 and resolveItem(a.body,itemKey(value))~=value then a.action[field]=0 end
                end
                local priorCleanup=a.cleanupSucceeded
                a.cleanupSucceeded=pcall(a.class.perform,a.action)
                if priorCleanup==false then a.cleanupSucceeded=false end
                local cleaned=pcall(function()for handle in pairs(a.danceSounds or {})do a.emitter:stopSound(handle)end end)
                a.cleanupSucceeded=a.cleanupSucceeded and cleaned
                danceDeathRetired=true
                retirePartnerDance(a)
            end
            local nativeAction=a.action.action
            if not bound(id,a) and a.action.gameSound and a.action.gameSound~=0 then
                a.cleanupSucceeded=pcall(function()a.emitter:stopSound(a.action.gameSound)end)
            end
            if not danceDeathRetired then a.action:stop()end
            if nativeAction then pcall(function() nativeAction:forceStop() end) end
        end
    end
    local finished=finish(id,"interrupted",reason or "person-interrupted")
    return a~=nil or finished
end
function M.reset(reason)
    local ids={};for id in pairs(runtime) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do M.interrupt(id,runtime[id].body,reason or "runtime-owner-lost") end
    if SAO.LeisureMusicWorld and SAO.LeisureMusicWorld.reset then SAO.LeisureMusicWorld.reset()end
end
-- Type-only preview; no actor record, inventory or perception query occurs.
function M.materialRequirementsForType(body,itemType)
    if type(itemType)~="string"or #itemType>160 then return {}end
    local result={};local short=itemType:match("%.([^%.]+)$")
    local kind=short and instrument({getType=function()return short end,getFullType=function()return itemType end})
    if kind and activeSource("LifestyleHobbies")then
        result[#result+1]={owner=OWNER,family="music",activity="practice-instrument",sourceId="LifestyleHobbies",
            revision=pin("LifestyleHobbies","shared/TimedActions/PlayInstrumentTraining.lua"),role="playable-item",
            requirementId="source-instrument:"..kind,itemType=itemType,instrumentType=kind}
        result[#result+1]={owner=OWNER,family="music",activity="perform-instrument",sourceId="LifestyleHobbies",
            revision=pin("LifestyleHobbies","shared/TimedActions/PlayInstrumentActionNew.lua"),role="playable-item",
            requirementId="source-instrument-performance:"..kind,itemType=itemType,instrumentType=kind}
    end
    if activeSource("NewMusic")then
        local profile=NMDeviceProfiles and NMDeviceProfiles.byType and NMDeviceProfiles.byType[itemType]
        if profile and profile.deviceType~="media_container"and profile.allowInventoryPlayback==true then
            result[#result+1]={owner=OWNER,family="music",activity="listen-recorded-music",sourceId="NewMusic",
                revision=pin("NewMusic","shared/audio/NMPlaybackRuntime.lua"),role="playable-item",
                requirementId="source-audio-device:"..itemType,itemType=itemType}
        end
        local carrier=NMMediaContract and NMMediaContract.resolveMediaCarrier and NMMediaContract.resolveMediaCarrier(itemType)
        if type(carrier)=="string"and carrier~=""then
            result[#result+1]={owner=OWNER,family="music",activity="listen-recorded-music",sourceId="NewMusic",
                revision=pin("NewMusic","shared/audio/NMPlaybackRuntime.lua"),role="material",
                requirementId="source-audio-media:"..carrier,itemType=itemType,carrier=carrier}
        elseif NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.isSupported and NMInsertedHeadphonePolicy.isSupported(itemType)then
            local supported=false
            for _,candidate in pairs(NMDeviceProfiles and NMDeviceProfiles.byType or{})do if candidate.supportsHeadphones then supported=true;break end end
            if supported then result[#result+1]={owner=OWNER,family="music",activity="listen-recorded-music",sourceId="NewMusic",
                revision=pin("NewMusic","shared/slot/NMInsertedHeadphonePolicy.lua"),role="material",
                requirementId="source-audio-headphones",itemType=itemType}end
        elseif itemType=="Base.Battery"then
            result[#result+1]={owner=OWNER,family="music",activity="listen-recorded-music",sourceId="NewMusic",
                revision=pin("NewMusic","shared/audio/NMPlaybackRuntime.lua"),role="material",
                requirementId="source-audio-battery",itemType=itemType}
        end
    end
    local contextual={}
    for _,row in ipairs(result)do
        if row.sourceId~="NewMusic"then contextual[#contextual+1]=row
        else
            local personal,world=false,false
            for fullType,candidate in pairs(NMDeviceProfiles and NMDeviceProfiles.byType or{})do
                local compatible=row.role=="playable-item"and fullType==row.itemType
                    or row.role=="material"and (row.carrier and candidate.supportedCarrier==row.carrier
                        or row.requirementId=="source-audio-battery"and candidate.supportsBattery
                        or row.requirementId=="source-audio-headphones"and candidate.supportsHeadphones)
                if compatible then
                    personal=personal or candidate.allowInventoryPlayback==true
                        or row.role=="material"and(candidate.attachedPlaybackMode=="personal"
                            or candidate.attachedPlaybackModeWithHeadphones=="personal")
                    world=world or row.role=="material"and candidate.allowPlacedWorldPlayback==true
                end
            end
            if personal then
                local own=plain(row);own.activity="listen-recorded-music";contextual[#contextual+1]=own
                if activeSource("LifestyleHobbies") and Perks.Dancing then
                    local dance=plain(row);dance.activity="dance-to-recorded-music"
                    dance.requirementId=row.requirementId..":dance";contextual[#contextual+1]=dance
                end
            end
            if world then local own=plain(row);own.activity="listen-source-world-music";contextual[#contextual+1]=own end
        end
    end
    return plain(contextual)
end
function M.playableRequirementAvailable(id,body,row)
    if type(row)~="table" or row.owner~=OWNER or row.role~="playable-item" then return false end
    if row.activity~="dance-to-recorded-music" then return true end
    if not personalRecordedDanceReady(id,body,true) then return false end
    for _,candidate in ipairs(M.materialRequirementsForType(nil,row.itemType))do
        if same(candidate,row) then return true end
    end
    return false
end
function M.materialRequirementAvailable(id,body,row)
    if not live(id,body)or not sp()or body:isDead()or body:isAsleep()or not activeSource("NewMusic")
        or type(row)~="table"or row.owner~=OWNER or row.role~="material"or not concept(id,"music")
        or row.activity=="dance-to-recorded-music"and not personalRecordedDanceReady(id,body,true)then return false end
    local canonical=false
    for _,candidate in ipairs(M.materialRequirementsForType(nil,row.itemType))do if same(candidate,row)then canonical=true;break end end
    if not canonical or not NMDeviceProfiles or not NMDeviceState then return false end
    local sourceRequirement=row
    if row.activity=="dance-to-recorded-music"then
        local original=row.requirementId:match("^(.-):dance$")
        if not original then return false end
        sourceRequirement=plain(row);sourceRequirement.requirementId=original
    end
    local function compatible(device,profile,context)
        local state=profile and NMDeviceState.peek(device)
        if not state or not state.deviceUUID then return false end
        local public=(context=="placed"or context=="vehicle")
        if public and row.activity~="listen-source-world-music"
            or not public and row.activity~="listen-recorded-music"and row.activity~="dance-to-recorded-music"then return false end
        if row.activity=="dance-to-recorded-music" and (profile.allowInventoryPlayback~=true
            or profile.requiresBattery~=true or profile.requiresExternalPower) then return false end
        return SAO.LeisureMusicSupply and
            SAO.LeisureMusicSupply.requirementUnmet(body,device,profile,state,sourceRequirement,context)==true
    end
    local env=recordedSourceEnv(id,body)
    for _,item in ipairs(carried(body))do
        local profile=NMDeviceProfiles.getForItem(item);local state=profile and NMDeviceState.peek(item)
        local context=state and recordedContext(env,body,item,profile,state)
        if context and compatible(item,profile,context)then return true end
    end
    for _,observed in ipairs(audioSources(id,body))do
        if observed.actorId==id and(observed.sourceKind=="placed"or observed.sourceKind=="vehicle")then
            local d={audioSourceKey=observed.key,sourceContext=observed.sourceKind,itemKey=observed.itemKey,
                itemType=observed.itemType,audioObservation=observed,vehicleId=observed.vehicleId and tostring(observed.vehicleId),
                vehicleSqlId=observed.vehicleSqlId and tostring(observed.vehicleSqlId),partId=observed.partId}
            local target,device,profile=audioTarget(id,body,d)
            local permitted=target and(observed.sourceKind=="vehicle"and body:getVehicle()==target.vehicle
                or observed.sourceKind=="placed"and SAO.Standing and SAO.Standing.mayEnterCurrent
                    and SAO.Standing.mayEnterCurrent(id,target.object:getSquare():getX(),target.object:getSquare():getY()))
            if permitted and compatible(device,profile,observed.sourceKind)then return true end
        end
    end
    return false
end

function M.compatibility(family)
    local gaps={piano="original-paired-object-actions-and-source-position-admitted; native-furniture-preparation-owner-required",
        vocal="original-source-vocal-duet-admitted-with-typed-delivered-agreement-and-private-standing-microphone",
        duet="typed-current-delivered-source-song-role-commitments-and-personal-social-choice; native-hearing-and-rendered-performance-qualification-separate",radio="native-radio-power-media-and-reception-owner-required",
        placedRecorded="actor-acquired-original-source-intents-and-shared-physical-UUID-observer; native-object-hearing-and-full-source-scheduler-qualification-separate",
        vehicleRecorded="native-occupant-source-control-or-already-running-public-listening; exact-vehicle-part-power-and-shared-world-renderer; native-qualification-separate",
        dance="original-continuous-solo-and-source-actor-voice-initialization; partner-and-broader-source-effects-joins-open"}
    return gaps[family] or "assessed-source-family-not-admitted"
end
