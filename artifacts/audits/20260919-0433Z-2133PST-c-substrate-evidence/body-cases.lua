local function one(fail)
    local removed=false
    local rec={id='p',hibernation='OLD_SNAPSHOT',releasedAtHours=5}
    local body={getX=function() return 8 end,getY=function() return 9 end,getZ=function() return 0 end}
    SAO.Body.active.p=body
    SAOJavaBridge={hibernate=function() if fail == 'throw' then error('serialization failed') end; if fail == 'empty' then return '' end; return 'NEW_SNAPSHOT' end,isShell=function() return true end, removeShell=function() removed=true end}
    local ok=SAO.Body.release(rec)
    return tostring(ok)..','..tostring(removed)..','..tostring(SAO.Body.active.p)..','..rec.hibernation..','..rec.releasedAtHours
end
SUCCESS_CONTROL=one(false)
FAILED_SNAPSHOT=one('throw')

EMPTY_SNAPSHOT=one('empty'); RESULT=SUCCESS_CONTROL .. ' / ' .. FAILED_SNAPSHOT .. ' / ' .. EMPTY_SNAPSHOT

