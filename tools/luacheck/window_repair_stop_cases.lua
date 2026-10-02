-- Installed stop/perform/cancel callbacks with controlled surrounding actors.
function __runWindowStopCustody()
    local W,A,fixture,check=SAO.WindowRepair,RepairableWindowsAddWindowAction,__windowFixture,__windowCheck
    W.reset('stop-custody');W.retryCancellations()
    if W.install()~=true then error('owned stop fixture requires installed adapter') end
    local function make(id,kind)
        local f=fixture(id)
        if kind=='player' then f.body.md.SAOPersonId=nil end
        local action=kind=='player' and A:new(f.body,f.window) or __windowAdmitted(f)
        if kind=='player' then ISTimedActionQueue.add(action) end
        return f,action,ISTimedActionQueue.getTimedActionQueue(f.body)
    end
    local function other(body)
        local action=ISBaseTimedAction:new(body)
        function action:isValid() return true end
        return action
    end
    local function retained(q,action,body)
        return q.current==action and #q.queue==1 and q.queue[1]==action and body.farming==true
    end
    local ordinary,ordinaryAction,ordinaryQueue=make('stop-ordinary-player','player')
    local pending=other(ordinary.body);ordinaryQueue.queue[2]=pending;ordinary.body.farming=true
    ordinaryAction:stop()
    check('stop_player_original_native_cleanup',ordinaryQueue.current==nil and #ordinaryQueue.queue==0
        and ordinary.body.farming==false and ordinaryAction._SAOWindowRepairBinding==false)

    local npc,npcAction,npcQueue=make('stop-ordinary-npc','npc');local runtimeBefore=W.runtimeCount()-1
    npc.body.farming=true;npcAction:stop()
    check('stop_npc_original_ack_and_cleanup',npcQueue.current==nil and #npcQueue.queue==0
        and npc.body.farming==false and W.runtimeCount()==runtimeBefore
        and npcAction._SAOWindowRepairBinding==false and W.outcome(npc.id,1).status=='interrupted')
    local nextOwner,stopping,q=make('stop-npc-next-owner','npc');local before=W.runtimeCount()-1
    local following=other(nextOwner.body);local nativeBegin=following.begin
    function following:begin() nativeBegin(self);self.character:setIsFarming(true) end
    q.queue[2]=following;nextOwner.body.farming=true;stopping:stop()
    check('stop_npc_original_ack_preserves_next_flags',q.current==following and #q.queue==1
        and q.queue[1]==following and nextOwner.body.farming==true and W.runtimeCount()==before
        and stopping._SAOWindowRepairBinding==false)

    for _,kind in ipairs({'player','npc'}) do
        for _,change in ipairs({'replaced','advanced'}) do
            local f,action,original=make('stop-'..kind..'-'..change,kind)
            local before=W.runtimeCount()
            if kind=='npc' then f.body.holdCancellation=true;W.forget(f.id) end
            local current
            if change=='replaced' then
                ISTimedActionQueue.queues[f.body]=nil;current=ISTimedActionQueue.getTimedActionQueue(f.body)
            else current=original end
            local successor=other(f.body);current.current=successor;current.queue={successor};f.body.farming=true
            action:stop()
            local oldRetired=original:indexOf(action)==-1 and original.current~=action
            local released=action._SAOWindowRepairBinding==false
            if kind=='npc' then
                check('stop_npc_'..change..'_queue_ack_preserves_successor',retained(current,successor,f.body)
                    and oldRetired and released and W.runtimeCount()==before-1
                    and W.outcome(f.id,1).status=='interrupted' and W.outcome(f.id,2)==nil)
            else
                check('stop_player_'..change..'_queue_preserves_successor',retained(current,successor,f.body)
                    and oldRetired and released)
            end
        end
    end

    for _,field in ipairs({'character','window'}) do
        local f,action,q=make('stop-shadow-'..field,'player');local foreign=fixture('stop-shadow-foreign-'..field)
        local foreignQ=ISTimedActionQueue.getTimedActionQueue(foreign.body);local successor=other(foreign.body)
        foreignQ.current=successor;foreignQ.queue={successor};foreign.body.farming=true;f.body.farming=true
        action[field]=field=='character' and foreign.body or foreign.window
        check('stop_player_'..field..'_shadow_refuses',action:stop()==false and q.current==action and q:indexOf(action)==1
            and f.body.farming==true and retained(foreignQ,successor,foreign.body))
        action[field]=field=='character' and f.body or f.window;action:stop()
    end

    local cancelled,cancelAction,oldQueue=make('cancel-replaced-player','player')
    ISTimedActionQueue.queues[cancelled.body]=nil
    local current=ISTimedActionQueue.getTimedActionQueue(cancelled.body);local successor=other(cancelled.body)
    current.current=successor;current.queue={successor};cancelled.body.farming=true
    oldQueue:resetQueue()
    -- Started actions get their native stop acknowledgement separately.
    cancelAction:forceCancel()
    check('cancel_player_replaced_queue_preserves_successor',retained(current,successor,cancelled.body)
        and cancelAction._SAOWindowRepairBinding==false)
    for _,field in ipairs({'character','window'}) do
        local shadow,shadowAction,shadowQ=make('cancel-shadow-player-'..field,'player')
        local foreign=fixture('cancel-shadow-foreign-'..field);local foreignQ=ISTimedActionQueue.getTimedActionQueue(foreign.body)
        local foreignAction=other(foreign.body);foreignQ.current=foreignAction;foreignQ.queue={foreignAction};foreign.body.farming=true
        shadowAction[field]=field=='character' and foreign.body or foreign.window
        check('cancel_player_'..field..'_shadow_refuses',shadowAction:forceCancel()==false
            and type(shadowAction._SAOWindowRepairBinding)=='function' and shadowQ.current==shadowAction
            and retained(foreignQ,foreignAction,foreign.body))
        shadowAction[field]=field=='character' and shadow.body or shadow.window;shadowAction:stop()
    end

    for _,kind in ipairs({'player','npc'}) do
        local f,action,q=make('perform-noncurrent-'..kind,kind)
        local completed=action:complete();local successor=other(f.body)
        q.current=successor;q.queue={successor,action};f.body.farming=true
        check('perform_'..kind..'_noncurrent_same_queue_refuses',completed and action:perform()==false
            and q.current==successor and #q.queue==2 and q.queue[1]==successor and q.queue[2]==action and f.body.farming==true)
        action:stop()
    end
    __windowResults=table.concat(__checks,'\n')
end
