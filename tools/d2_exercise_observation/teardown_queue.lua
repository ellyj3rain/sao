table.wipe=table.wipe or function(t)for k in pairs(t)do t[k]=nil end end
MoodleType.UNHAPPY=__unhappyMoodle;MoodleType.DRUNK=__drunkMoodle
-- Real installed queue mutation methods and native LuaTimedActionNew. Queue
-- admission/animation callbacks are explicitly controlled in this headless host.
ISTimedActionQueue.addGetUpAndThen=function(body,action)
 local q=ISTimedActionQueue.getTimedActionQueue(body)
 table.insert(q.queue,action);q.current=q.queue[1];__action=action
 local ok,err=pcall(function()action:create()end);if not ok then print('CREATEFAIL '..tostring(err));error(err)end
end
